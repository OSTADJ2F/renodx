#pragma once

#include <atomic>
#include <bit>
#include <cmath>
#include <cstdint>
#include <optional>
#include <shared_mutex>
#include <unordered_map>

#include <include/reshade.hpp>

#include "../../utils/resource.hpp"
#include "../../utils/state.hpp"
#include "./rr_guides.hpp"
#include "./rt_multiray.hpp"
#include "./rt_noise.hpp"

// RT reflection overrides. The game's ReflSpec constant buffer (b10 space2) is patched at DispatchRays: smoothing
// is written into it, full-res tracing re-dispatches the trace at the full render width, and multi-ray tracing
// re-dispatches it RaysPerPixel() times with a fresh noise volume each time (rt_multiray averages the results in
// PreBlur). The NRD constant buffer (b0 space0) is patched at the NRD buffer generation dispatch when a smoothing
// slider is off its default.
namespace rt_trace {

constexpr float METAL_SMOOTHING_DEFAULT = 60.f;
constexpr float NON_METAL_SMOOTHING_DEFAULT = 12.5f;
constexpr float TEXTURE_LOD_DEFAULT = 1.f;
constexpr float HIT_ROUGHNESS_DEFAULT = 20.f;
constexpr float ROUGHNESS_CUTOFF_DEFAULT = 100.f;
// Game values of g_roughnessBlendParams (x, y), which the combine shader uses as saturate(rough * x + y).
constexpr float GAME_ROUGHNESS_BLEND_X = -999.95f;
constexpr float GAME_ROUGHNESS_BLEND_Y = 999.95f;
constexpr float GAME_ROUGHNESS_BLEND_TOLERANCE = 1.f;
// Written to g_roughnessBlendParams.x when the roughness cutoff is overridden; y takes the cutoff setting * 0.1.
constexpr float ROUGHNESS_BLEND_X_OVERRIDE = -10.f;

// Settings values. Smoothing, reflectivity boost, hit roughness and roughness cutoff are in percent.
inline float full_res_setting = 0.f;
inline float metal_smoothing_setting = METAL_SMOOTHING_DEFAULT;
inline float non_metal_smoothing_setting = NON_METAL_SMOOTHING_DEFAULT;
inline float texture_lod_setting = TEXTURE_LOD_DEFAULT;
inline float reflectivity_boost_setting = 0.f;
inline float hit_roughness_setting = HIT_ROUGHNESS_DEFAULT;
inline float roughness_cutoff_setting = ROUGHNESS_CUTOFF_DEFAULT;

// Set by a full-res dispatch; OnPresent consumes it for the frame's rt_full_res value.
inline std::atomic_bool patched_last_frame{false};

// Full-res flag of the last trace recorded on each command list. The denoiser passes can record on another list,
// so they look up the flag by the list that recorded the trace.
struct FullResByCommandList {
  std::shared_mutex mutex;
  std::unordered_map<reshade::api::command_list*, bool> full_res;
};
inline FullResByCommandList full_res_cache;
// Points at shader_injection.rt_full_res so the flag reaches the same frame's denoiser. Set in DllMain.
inline float* rt_full_res_flag = nullptr;

// Constant buffer layouts as 32-bit word indices (byte offset / 4).
constexpr uint32_t REFL_CB_BYTES = 128u;
constexpr uint32_t REFL_CB_SCALE_OFFSET = 12u;  // uint4 sampleScaleOffset, byte 48
constexpr uint32_t REFL_CB_SAMPLE_MODE = 20u;   // uint sampleMode, byte 80
constexpr uint32_t REFL_CB_METAL = 24u;         // float metalSmoothing, byte 96
constexpr uint32_t REFL_CB_NON_METAL = 25u;     // float nonMetalSmoothing, byte 100
constexpr uint32_t REFL_CB_REFLECTIVITY = 26u;  // float, byte 104
constexpr uint32_t REFL_CB_HIT_ROUGHNESS = 27u; // float, byte 108
constexpr uint32_t REFL_CB_TEXTURE_LOD = 28u;   // float, byte 112
constexpr uint32_t REFL_CB_ROUGHNESS_BLEND = 0u; // float4 roughness cutoff, x and y at byte 0
constexpr uint32_t COMBINE_CB_BYTES = 64u;
constexpr uint32_t COMBINE_CB_ROUGHNESS_BLEND = 4u;  // float4 g_roughnessBlendParams, byte 16
constexpr uint32_t NRD_CB_BYTES = 64u;
constexpr uint32_t NRD_CB_SCALE_X = 4u;   // uint scaleOffset.x, byte 16
constexpr uint32_t NRD_CB_NON_METAL = 12u;  // float, byte 48
constexpr uint32_t NRD_CB_METAL = 13u;      // float, byte 52

// Writes the roughness cutoff into the float4 g_roughnessBlendParams whose x is at word index `index`.
inline void WriteRoughnessBlend(uint32_t* words, uint32_t index) {
  words[index] = std::bit_cast<uint32_t>(ROUGHNESS_BLEND_X_OVERRIDE);
  words[index + 1u] = std::bit_cast<uint32_t>(roughness_cutoff_setting * 0.1f);
}

inline bool OnDispatchRays(
    reshade::api::command_list* cmd_list,
    reshade::api::resource raygen,
    uint64_t raygen_offset,
    uint64_t raygen_size,
    reshade::api::resource miss,
    uint64_t miss_offset,
    uint64_t miss_size,
    uint64_t miss_stride,
    reshade::api::resource hit_group,
    uint64_t hit_group_offset,
    uint64_t hit_group_size,
    uint64_t hit_group_stride,
    reshade::api::resource callable,
    uint64_t callable_offset,
    uint64_t callable_size,
    uint64_t callable_stride,
    uint32_t width,
    uint32_t height,
    uint32_t depth) {
  // The full-res and multi-ray re-dispatches below reenter this event; they must run as the game's original dispatch.
  thread_local bool redispatching = false;
  if (redispatching) return false;
  const uint32_t rays = rt_multiray::RaysPerPixel();

  auto* device = cmd_list->get_device();
  const auto cb_slot = rr_guides::FindComputeDescriptor(cmd_list, rr_guides::ComputeBindKind::CBV, 10u, 2u);
  if (!cb_slot.has_value()) {
    rr_guides::LogSkipOnce(1u << 8, "rt_trace: CBV b10 space2 not found, RT trace left unchanged");
    rt_multiray::FinishTrace({0u}, 1u);
    return false;
  }
  const auto cb = cb_slot->buffer_range;

  void* mapped = nullptr;
  if (!device->map_buffer_region(cb.buffer, cb.offset, REFL_CB_BYTES, reshade::api::map_access::read_write, &mapped)) {
    rr_guides::LogSkipOnce(1u << 9, "rt_trace: map of CBV b10 space2 failed, RT trace left unchanged");
    rt_multiray::FinishTrace({0u}, 1u);
    return false;
  }
  auto* words = static_cast<uint32_t*>(mapped);
  const uint32_t sample_mode = words[REFL_CB_SAMPLE_MODE];
  const uint32_t scale_x = words[REFL_CB_SCALE_OFFSET];
  const uint32_t scale_y = words[REFL_CB_SCALE_OFFSET + 1u];
  const bool valid_refl_cb = (sample_mode == 1u || sample_mode == 2u) && scale_x == 2u && scale_y == 1u;

  bool full_res_dispatch = false;
  uint32_t render_width = 0u;
  reshade::api::resource output = {0u};
  if (valid_refl_cb) {
    if (rt_noise::white_noise_setting != 0.f || rays > 1u) {
      rt_noise::RecordNoiseTexture(cmd_list);
    }
    if (metal_smoothing_setting != METAL_SMOOTHING_DEFAULT) {
      words[REFL_CB_METAL] = std::bit_cast<uint32_t>(metal_smoothing_setting * 0.01f);
    }
    if (non_metal_smoothing_setting != NON_METAL_SMOOTHING_DEFAULT) {
      words[REFL_CB_NON_METAL] = std::bit_cast<uint32_t>(non_metal_smoothing_setting * 0.01f);
    }
    if (texture_lod_setting != TEXTURE_LOD_DEFAULT) {
      words[REFL_CB_TEXTURE_LOD] = std::bit_cast<uint32_t>(texture_lod_setting);
    }
    if (reflectivity_boost_setting != 0.f) {
      words[REFL_CB_REFLECTIVITY] = std::bit_cast<uint32_t>(reflectivity_boost_setting * 0.01f);
    }
    if (hit_roughness_setting != HIT_ROUGHNESS_DEFAULT) {
      words[REFL_CB_HIT_ROUGHNESS] = std::bit_cast<uint32_t>(hit_roughness_setting * 0.01f);
    }
    if (roughness_cutoff_setting != ROUGHNESS_CUTOFF_DEFAULT) {
      WriteRoughnessBlend(words, REFL_CB_ROUGHNESS_BLEND);
    }
    rr_guides::SetRoughnessSmoothing(
        std::bit_cast<float>(words[REFL_CB_NON_METAL]),
        std::bit_cast<float>(words[REFL_CB_METAL]));

    if (full_res_setting != 0.f || rays > 1u) {
      const auto target_view = rr_guides::LookupComputeView(cmd_list, true, 11u, 1u);
      if (target_view.handle == 0u) {
        rr_guides::LogSkipOnce(1u << 10, "rt_trace: UAV u11 space1 not found, full-res and multi-ray tracing skipped");
      } else {
        output = device->get_resource_from_view(target_view);
        const auto target_desc = renodx::utils::resource::GetResourceDesc(device, output);
        // The checkerboard dispatch is floor(render_width / 2) wide, so 2 * width is within one pixel of render_width.
        render_width = target_desc.texture.width;
        const int64_t width_error = 2ll * width - static_cast<int64_t>(render_width);
        full_res_dispatch = full_res_setting != 0.f && target_desc.type == reshade::api::resource_type::texture_2d
                            && width_error >= -1 && width_error <= 1;
      }
    }

    if (full_res_dispatch) {
      words[REFL_CB_SAMPLE_MODE] = 0u;
      words[REFL_CB_SCALE_OFFSET] = 1u;
      words[REFL_CB_SCALE_OFFSET + 1u] = 1u;
      words[REFL_CB_SCALE_OFFSET + 2u] = 0u;
      words[REFL_CB_SCALE_OFFSET + 3u] = 0u;
    }

    std::unique_lock lock(full_res_cache.mutex);
    full_res_cache.full_res[cmd_list] = full_res_dispatch;
  }
  device->unmap_buffer_region(cb.buffer);

  const auto dispatch = [&](uint32_t dispatch_width) {
    redispatching = true;
    cmd_list->dispatch_rays(
        raygen,
        raygen_offset,
        raygen_size,
        miss,
        miss_offset,
        miss_size,
        miss_stride,
        hit_group,
        hit_group_offset,
        hit_group_size,
        hit_group_stride,
        callable,
        callable_offset,
        callable_size,
        callable_stride,
        dispatch_width,
        height,
        depth);
    redispatching = false;
  };

  if (valid_refl_cb && rays > 1u && output.handle != 0u) {
    const uint32_t trace_width = full_res_dispatch ? render_width : width;
    uint32_t traced = 0u;
    for (uint32_t k = 0u; k < rays; ++k) {
      if (k > 0u && !rt_noise::CopyVolume(cmd_list, k)) break;
      dispatch(trace_width);
      ++traced;
      if (k < rays - 1u && !rt_multiray::StoreSample(cmd_list, output, k)) break;
    }
    rt_multiray::FinishTrace(output, traced);
    if (full_res_dispatch) {
      *rt_full_res_flag = 1.f;
      patched_last_frame.store(true);
    }
    return true;
  }

  if (valid_refl_cb) {
    rt_multiray::FinishTrace({0u}, 1u);
  }
  if (!full_res_dispatch) return false;

  dispatch(render_width);
  *rt_full_res_flag = 1.f;
  patched_last_frame.store(true);
  return true;
}

inline std::optional<bool> FullResForCommandList(reshade::api::command_list* cmd_list) {
  std::shared_lock lock(full_res_cache.mutex);
  const auto found = full_res_cache.full_res.find(cmd_list);
  if (found == full_res_cache.full_res.end()) return std::nullopt;
  return found->second;
}

// reset_command_list and destroy_command_list events: drops the command list's entry so a recycled pointer cannot match.
inline void OnForgetCommandList(reshade::api::command_list* cmd_list) {
  std::unique_lock lock(full_res_cache.mutex);
  full_res_cache.full_res.erase(cmd_list);
}

// Compute dispatch event: applies the smoothing sliders to the NRD buffer generation constant buffer, and the roughness
// cutoff to the CombineSSRandRT constant buffer (b0 space0, g_roughnessBlendParams).
inline bool OnDispatch(
    reshade::api::command_list* cmd_list,
    uint32_t /*group_count_x*/,
    uint32_t /*group_count_y*/,
    uint32_t /*group_count_z*/) {
  const auto hash = renodx::utils::state::GetCurrentShaderHash(cmd_list, reshade::api::pipeline_stage::compute_shader);
  if (hash == rr_guides::COMBINE_SSR_RT_HASH) {
    if (roughness_cutoff_setting == ROUGHNESS_CUTOFF_DEFAULT) return false;

    auto* device = cmd_list->get_device();
    const auto cb_slot = rr_guides::FindComputeDescriptor(cmd_list, rr_guides::ComputeBindKind::CBV, 0u, 0u);
    if (!cb_slot.has_value()) {
      rr_guides::LogSkipOnce(1u << 18, "rt_trace: CBV b0 space0 not found, roughness cutoff left unchanged in CombineSSRandRT");
      return false;
    }
    const auto cb = cb_slot->buffer_range;

    void* mapped = nullptr;
    if (!device->map_buffer_region(cb.buffer, cb.offset, COMBINE_CB_BYTES, reshade::api::map_access::read_write, &mapped)) {
      rr_guides::LogSkipOnce(1u << 19, "rt_trace: map of CBV b0 space0 failed, roughness cutoff left unchanged in CombineSSRandRT");
      return false;
    }
    auto* words = static_cast<uint32_t*>(mapped);
    const float live_x = std::bit_cast<float>(words[COMBINE_CB_ROUGHNESS_BLEND]);
    const float live_y = std::bit_cast<float>(words[COMBINE_CB_ROUGHNESS_BLEND + 1u]);
    const bool game_values = std::abs(live_x - GAME_ROUGHNESS_BLEND_X) <= GAME_ROUGHNESS_BLEND_TOLERANCE
                             && std::abs(live_y - GAME_ROUGHNESS_BLEND_Y) <= GAME_ROUGHNESS_BLEND_TOLERANCE;
    if (game_values) {
      WriteRoughnessBlend(words, COMBINE_CB_ROUGHNESS_BLEND);
    } else {
      rr_guides::LogSkipOnce(1u << 20, "rt_trace: CombineSSRandRT roughBlend not at game values, roughness cutoff skipped");
    }
    device->unmap_buffer_region(cb.buffer);
    return false;
  }

  if (hash != rr_guides::GENERATE_NRD_BUFFERS_HASH) return false;
  if (metal_smoothing_setting == METAL_SMOOTHING_DEFAULT && non_metal_smoothing_setting == NON_METAL_SMOOTHING_DEFAULT) {
    return false;
  }

  auto* device = cmd_list->get_device();
  const auto cb_slot = rr_guides::FindComputeDescriptor(cmd_list, rr_guides::ComputeBindKind::CBV, 0u, 0u);
  if (!cb_slot.has_value()) {
    rr_guides::LogSkipOnce(1u << 11, "rt_trace: CBV b0 space0 not found, NRD smoothing left unchanged");
    return false;
  }
  const auto cb = cb_slot->buffer_range;

  void* mapped = nullptr;
  if (!device->map_buffer_region(cb.buffer, cb.offset, NRD_CB_BYTES, reshade::api::map_access::read_write, &mapped)) {
    rr_guides::LogSkipOnce(1u << 12, "rt_trace: map of CBV b0 space0 failed, NRD smoothing left unchanged");
    return false;
  }
  auto* words = static_cast<uint32_t*>(mapped);
  const uint32_t scale_x = words[NRD_CB_SCALE_X];
  const float game_non_metal = std::bit_cast<float>(words[NRD_CB_NON_METAL]);
  const float game_metal = std::bit_cast<float>(words[NRD_CB_METAL]);
  // Layout check: the game's values are fractions, and scale_x is 1 or 2 when this is the NRD constant buffer.
  const bool valid_nrd_cb = (scale_x == 1u || scale_x == 2u)
                            && game_non_metal >= 0.f && game_non_metal <= 1.f
                            && game_metal >= 0.f && game_metal <= 1.f;
  if (valid_nrd_cb) {
    const float non_metal = non_metal_smoothing_setting * 0.01f;
    const float metal = metal_smoothing_setting * 0.01f;
    words[NRD_CB_NON_METAL] = std::bit_cast<uint32_t>(non_metal);
    words[NRD_CB_METAL] = std::bit_cast<uint32_t>(metal);
    rr_guides::SetRoughnessSmoothing(non_metal, metal);
  }
  device->unmap_buffer_region(cb.buffer);
  return false;
}

}  // namespace rt_trace
