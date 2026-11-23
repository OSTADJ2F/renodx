#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <shared_mutex>
#include <tuple>
#include <vector>

#include <embed/shaders.h>
#include <include/reshade.hpp>

#include "../../utils/render.hpp"
#include "../../utils/resource.hpp"
#include "../../utils/state.hpp"
#include "./rr_guides.hpp"

// Multi-ray tracing: each extra ray is copied out of the trace output into a sample texture, then the PreBlur dispatch
// averages the samples with the last ray still in the output. The trace encodes radiance as rgb / (dot(rgb, 1/3) + 0.5),
// and the PreBlur shader (rt_multiray.cs_6_0.hlsl) averages these compressed values directly, without decoding them.
namespace rt_multiray {

constexpr uint32_t MAX_RAYS = 4u;

// Bound to the "Rays Per Pixel" setting. Rounded and clamped to [1, MAX_RAYS] by RaysPerPixel().
inline float rays_per_pixel_setting = 1.f;

inline uint32_t RaysPerPixel() {
  const float rounded = std::clamp(std::round(rays_per_pixel_setting), 1.f, static_cast<float>(MAX_RAYS));
  return static_cast<uint32_t>(rounded);
}

struct MultiRayState {
  std::shared_mutex mutex;
  reshade::api::device* device = nullptr;
  // Trace output recorded by FinishTrace, and the ray count it holds. Cleared when PreBlur consumes it.
  reshade::api::resource output = {0u};
  uint32_t sample_count = 0u;
  std::array<reshade::api::resource, MAX_RAYS - 1u> sample_textures = {};
  std::array<reshade::api::resource_view, MAX_RAYS - 1u> sample_srvs = {};
  uint32_t sample_width = 0u;
  uint32_t sample_height = 0u;
  reshade::api::format sample_format = reshade::api::format::unknown;
  // UAV on the output, cached while the output resource stays the same.
  reshade::api::resource uav_target = {0u};
  reshade::api::resource_view output_uav = {0u};
  renodx::utils::render::RenderPass pass;
  // x = ray count, y = width, z = height, w = unused.
  std::array<float, 4> params = {};
  std::vector<rr_guides::RetiredResources> retired;
};
inline MultiRayState multiray_state;

// Copies the trace output into sample[index]. Samples are only written for rays before the last one, which stays in output.
inline bool StoreSample(reshade::api::command_list* cmd_list, reshade::api::resource output, uint32_t index) {
  if (index >= MAX_RAYS - 1u) return false;

  auto* device = cmd_list->get_device();
  const auto output_desc = renodx::utils::resource::GetResourceDesc(device, output);
  const auto output_format = output_desc.texture.format;
  const bool is_rgba16f = output_format == reshade::api::format::r16g16b16a16_float
                          || output_format == reshade::api::format::r16g16b16a16_typeless;
  if (output_desc.type != reshade::api::resource_type::texture_2d || !is_rgba16f) {
    rr_guides::LogSkipOnce(1u << 21, "rt_multiray: output is not a 2D r16g16b16a16 texture, multi-ray samples skipped");
    return false;
  }

  std::unique_lock lock(multiray_state.mutex);
  const bool size_changed = multiray_state.sample_width != output_desc.texture.width
                            || multiray_state.sample_height != output_desc.texture.height
                            || multiray_state.sample_format != output_format;
  if (size_changed) {
    auto retire_samples = [] {
      rr_guides::RetiredResources retired;
      for (auto& view : multiray_state.sample_srvs) {
        if (view.handle != 0u) retired.views.push_back(view);
        view = {0u};
      }
      for (auto& texture : multiray_state.sample_textures) {
        if (texture.handle != 0u) retired.resources.push_back(texture);
        texture = {0u};
      }
      if (!retired.views.empty() || !retired.resources.empty()) multiray_state.retired.push_back(std::move(retired));
    };
    retire_samples();
    multiray_state.device = device;

    const reshade::api::resource_desc sample_desc(
        output_desc.texture.width,
        output_desc.texture.height,
        1u,
        1u,
        output_format,
        1u,
        reshade::api::memory_heap::gpu_only,
        reshade::api::resource_usage::shader_resource | reshade::api::resource_usage::copy_dest);
    for (size_t i = 0; i < multiray_state.sample_textures.size(); ++i) {
      const bool created = device->create_resource(sample_desc, nullptr, reshade::api::resource_usage::copy_dest, &multiray_state.sample_textures[i])
                           && device->create_resource_view(
                               multiray_state.sample_textures[i],
                               reshade::api::resource_usage::shader_resource,
                               reshade::api::resource_view_desc(reshade::api::resource_view_type::texture_2d,
                                                                reshade::api::format::r16g16b16a16_float, 0u, 1u, 0u, 1u),
                               &multiray_state.sample_srvs[i]);
      if (!created) {
        retire_samples();
        rr_guides::LogSkipOnce(1u << 23, "rt_multiray: sample texture creation failed, multi-ray samples skipped");
        return false;
      }
    }
    multiray_state.sample_width = output_desc.texture.width;
    multiray_state.sample_height = output_desc.texture.height;
    multiray_state.sample_format = output_format;
  }

  cmd_list->barrier(output, reshade::api::resource_usage::unordered_access, reshade::api::resource_usage::copy_source);
  cmd_list->copy_resource(output, multiray_state.sample_textures[index]);
  cmd_list->barrier(output, reshade::api::resource_usage::copy_source, reshade::api::resource_usage::unordered_access);
  return true;
}

// Called after the last trace ray. sample_count includes the last ray, which is still in output.
inline void FinishTrace(reshade::api::resource output, uint32_t sample_count) {
  std::unique_lock lock(multiray_state.mutex);
  multiray_state.output = output;
  multiray_state.sample_count = std::min(sample_count, MAX_RAYS);
}

// Dispatch event for PreBlur: averages the recorded rays into the output before PreBlur reads it. Always returns false so
// the game's PreBlur dispatch still runs.
inline bool OnDispatch(reshade::api::command_list* cmd_list, uint32_t /*group_count_x*/, uint32_t /*group_count_y*/, uint32_t /*group_count_z*/) {
  if (renodx::utils::state::GetCurrentShaderHash(cmd_list, reshade::api::pipeline_stage::compute_shader)
      != rr_guides::PRE_BLUR_HASH) {
    return false;
  }

  std::unique_lock lock(multiray_state.mutex);
  if (multiray_state.sample_count <= 1u) return false;
  if (rr_guides::IsComputeCommandList(cmd_list)) return false;
  const auto output = multiray_state.output;
  // Not consumed here: frames record on several threads, so the next trace can be recorded before this PreBlur.
  // Every valid trace calls FinishTrace, so a count of 1 turns the average off.
  const auto ray_count = multiray_state.sample_count;

  auto* device = cmd_list->get_device();
  const auto trace_view = rr_guides::LookupComputeView(cmd_list, false, 2u, 0u);
  if (trace_view.handle == 0u || device->get_resource_from_view(trace_view).handle != output.handle) {
    rr_guides::LogSkipOnce(1u << 22, "rt_multiray: PreBlur SRV t2 space0 is not the recorded trace output, multi-ray average skipped");
    return false;
  }

  const auto output_desc = renodx::utils::resource::GetResourceDesc(device, output);
  if (multiray_state.uav_target.handle != output.handle) {
    if (multiray_state.output_uav.handle != 0u) {
      multiray_state.retired.push_back({.views = {multiray_state.output_uav}});
    }
    multiray_state.output_uav = {0u};
    multiray_state.uav_target = output;
    if (!device->create_resource_view(
            output,
            reshade::api::resource_usage::unordered_access,
            reshade::api::resource_view_desc(reshade::api::resource_view_type::texture_2d,
                                             reshade::api::format::r16g16b16a16_float, 0u, 1u, 0u, 1u),
            &multiray_state.output_uav)) {
      multiray_state.uav_target = {0u};
      return false;
    }
  }

  const uint32_t used_sample_count = ray_count - 1u;
  cmd_list->barrier(output, reshade::api::resource_usage::shader_resource, reshade::api::resource_usage::unordered_access);
  for (uint32_t i = 0u; i < used_sample_count; ++i) {
    cmd_list->barrier(multiray_state.sample_textures[i], reshade::api::resource_usage::copy_dest, reshade::api::resource_usage::shader_resource);
  }

  // Unused SRV slots repeat sample 0, which is always transitioned, so every bound view is readable.
  const auto sample_srv = [&](uint32_t slot) {
    return multiray_state.sample_srvs[slot < used_sample_count ? slot : 0u];
  };
  multiray_state.pass.shader_resource_slots.views = {sample_srv(0u), sample_srv(1u), sample_srv(2u)};
  multiray_state.pass.unordered_access_slots.views = {multiray_state.output_uav};
  multiray_state.params = {static_cast<float>(ray_count),
                           static_cast<float>(output_desc.texture.width),
                           static_cast<float>(output_desc.texture.height),
                           0.f};
  multiray_state.pass.pipeline_subobjects.compute_shader = __rt_multiray;
  multiray_state.pass.push_constants[{.slot = 0u, .space = 0u}] = multiray_state.params;
  multiray_state.pass.dispatch_group_counts = std::make_tuple((output_desc.texture.width + 7u) / 8u,
                                                              (output_desc.texture.height + 7u) / 8u,
                                                              1u);
  multiray_state.pass.Render(cmd_list);

  for (uint32_t i = 0u; i < used_sample_count; ++i) {
    cmd_list->barrier(multiray_state.sample_textures[i], reshade::api::resource_usage::shader_resource, reshade::api::resource_usage::copy_dest);
  }
  cmd_list->barrier(output, reshade::api::resource_usage::unordered_access, reshade::api::resource_usage::shader_resource);
  return false;
}

// Present event: destroys retired resources once they have aged through RETIRE_PRESENT_COUNT presents.
inline void OnPresent() {
  std::unique_lock lock(multiray_state.mutex);
  rr_guides::AgeRetired(multiray_state.device, &multiray_state.retired);
}

inline void OnDestroyDevice(reshade::api::device* device) {
  std::unique_lock lock(multiray_state.mutex);
  if (multiray_state.device != device) return;
  multiray_state.pass.DestroyAll(device);
  for (const auto& retired : multiray_state.retired) {
    rr_guides::DestroyRetired(device, retired);
  }
  multiray_state.retired.clear();
  for (auto& view : multiray_state.sample_srvs) {
    if (view.handle != 0u) device->destroy_resource_view(view);
    view = {0u};
  }
  for (auto& texture : multiray_state.sample_textures) {
    if (texture.handle != 0u) device->destroy_resource(texture);
    texture = {0u};
  }
  if (multiray_state.output_uav.handle != 0u) device->destroy_resource_view(multiray_state.output_uav);
  multiray_state.output_uav = {0u};
  multiray_state.uav_target = {0u};
  multiray_state.output = {0u};
  multiray_state.sample_count = 0u;
  multiray_state.sample_width = 0u;
  multiray_state.sample_height = 0u;
  multiray_state.sample_format = reshade::api::format::unknown;
  multiray_state.device = nullptr;
}

// Destroy event: drops cached views that point at a resource about to be destroyed, so the next PreBlur does not reuse them.
inline void OnDestroyResource(reshade::api::device* /* device */, reshade::api::resource resource) {
  {
    std::shared_lock lock(multiray_state.mutex);
    if (resource.handle != multiray_state.uav_target.handle && resource.handle != multiray_state.output.handle) return;
  }

  std::unique_lock lock(multiray_state.mutex);
  if (resource.handle == multiray_state.uav_target.handle) {
    if (multiray_state.output_uav.handle != 0u) {
      multiray_state.retired.push_back({.views = {multiray_state.output_uav}});
    }
    multiray_state.output_uav = {0u};
    multiray_state.uav_target = {0u};
  }
  if (resource.handle == multiray_state.output.handle) {
    multiray_state.output = {0u};
    multiray_state.sample_count = 0u;
  }
}

}  // namespace rt_multiray
