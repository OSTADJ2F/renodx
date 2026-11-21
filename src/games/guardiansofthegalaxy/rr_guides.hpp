#pragma once

#include <embed/shaders.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <optional>
#include <shared_mutex>
#include <tuple>
#include <unordered_map>
#include <utility>
#include <vector>

#include <include/reshade.hpp>

#include <d3d12.h>

#include "../../utils/descriptor.hpp"
#include "../../utils/pipeline_layout.hpp"
#include "../../utils/render.hpp"
#include "../../utils/resource.hpp"
#include "../../utils/state.hpp"

// Builds DLSS Ray Reconstruction guide buffers from the SSR combine inputs. The game's combine dispatch still runs.
namespace rr_guides {

constexpr uint32_t GENERATE_NRD_BUFFERS_HASH = 0xF969FA1Eu;
constexpr uint32_t COMBINE_SSR_RT_HASH = 0x81145B70u;
constexpr uint32_t PRE_BLUR_HASH = 0x9634F8F6u;
constexpr uint32_t TEMPORAL_ACCUMULATION_HASH = 0x949DC781u;
// NRD TemporalAccumulation constant buffer (b0 space0), as word offsets: byte offsets / 4.
constexpr uint32_t TA_CB_WORLD_TO_VIEW_PREV = 52u;  // float4x4 gWorldToViewPrev, c013
constexpr uint32_t TA_CB_CAMERA_DELTA = 116u;       // float4 gCameraDelta, c029
constexpr uint32_t TA_CB_BYTES = 496u;
// NRD PreBlur constant buffer (b0 space0), as word offsets: byte offsets / 4.
constexpr uint32_t PRE_BLUR_CB_BYTES = 320u;
constexpr uint32_t PRE_BLUR_CB_VIEW_TO_CLIP = 0u;    // float4x4, bytes 0..63
constexpr uint32_t PRE_BLUR_CB_SPEC_HIT_DIST = 20u;  // float4 gSpecHitDistParams, byte 80
constexpr uint32_t PRE_BLUR_CB_INF = 44u;            // float gInf, byte 176
constexpr uint32_t PRE_BLUR_CB_WORLD_TO_VIEW = 52u;  // float4x4, bytes 208..271
constexpr uint32_t PRE_BLUR_CB_CHECKERBOARD = 76u;   // uint gSpecCheckerboard, byte 304
// gSpecCheckerboard value of a full-res (non-checkerboard) trace.
constexpr uint32_t CHECKERBOARD_MODE_FULL_RES = 2u;
// Presents a replaced resource stays alive, so GPU work recorded against it can finish before it is destroyed.
constexpr uint32_t RETIRE_PRESENT_COUNT = 3u;

// Non-zero runs the guide pass; the game's combine still runs.
inline float rr_enable = 0.f;
// Mirrors shader_injection.rt_full_res: the trace wrote full-width data although PreBlur's CB still says checkerboard.
inline float full_res_active = 0.f;
// Written only by ngx_hooks: true while the last DLSS evaluate ran Ray Reconstruction.
inline std::atomic_bool rr_active{false};

// Guide textures written by the most recent successful pass. Valid until they age out of the retire list.
struct LatestGuides {
  reshade::api::resource normal_roughness;
  reshade::api::resource diffuse_albedo;
  reshade::api::resource specular_albedo;
  uint32_t width;
  uint32_t height;
  uint64_t frame_index;
  // Null unless the hit distance was built at this guide size. The matrices are those the PreBlur pass read.
  reshade::api::resource specular_hit_distance;
  std::array<float, 16> world_to_view;
  std::array<float, 16> view_to_clip;
  bool has_matrices;
};

// Incremented on every present; frame_index in LatestGuides is taken from it.
static std::atomic<uint64_t> present_frame_index = 0u;
static std::optional<LatestGuides> latest_guides;

inline uint64_t CurrentFrameIndex() {
  return present_frame_index.load();
}

// One bit per failed lookup or skip reason, so each is logged once.
static std::atomic<uint64_t> logged_skip_reasons = 0u;

// Fractions the game lowers roughness by before tracing. Written by rt_trace; the game's own values are the defaults.
struct RoughnessSmoothing {
  std::shared_mutex mutex;
  float non_metal = 0.125f;
  float metal = 0.6f;
};
inline RoughnessSmoothing roughness_smoothing;

inline void SetRoughnessSmoothing(float non_metal, float metal) {
  std::unique_lock lock(roughness_smoothing.mutex);
  roughness_smoothing.non_metal = non_metal;
  roughness_smoothing.metal = metal;
}

struct RetiredResources {
  std::vector<reshade::api::resource> resources;
  std::vector<reshade::api::resource_view> views;
  uint32_t presents_left = RETIRE_PRESENT_COUNT;
};

struct DeviceState {
  renodx::utils::render::RenderPass pass;
  reshade::api::resource nrd_normals = {0u};
  reshade::api::resource_view nrd_normals_srv = {0u};
  std::array<reshade::api::resource, 3> guide_resources = {{{0u}, {0u}, {0u}}};
  std::array<reshade::api::resource_view, 3> guide_uavs = {{{0u}, {0u}, {0u}}};
  uint32_t guide_width = 0u;
  uint32_t guide_height = 0u;
  // x = width, y = height, z and w = unused, then the roughness smoothing pair (non-metal, metal), then the
  // view-space scale per NDC unit (x, y).
  std::array<float, 12> params = {};
  std::vector<RetiredResources> retired;

  // Written by the PreBlur pass. The matrices are copied into LatestGuides with the guide textures.
  renodx::utils::render::RenderPass hit_pass;
  reshade::api::resource hit_distance = {0u};
  reshade::api::resource_view hit_distance_uav = {0u};
  uint32_t hit_distance_width = 0u;
  uint32_t hit_distance_height = 0u;
  // x..w = gSpecHitDistParams, then width, height, checkerboard, gInf.
  std::array<float, 8> hit_params = {};
  std::array<float, 16> world_to_view = {};
  std::array<float, 16> view_to_clip = {};
  bool has_matrices = false;
  // Accumulated camera translation, from the TemporalAccumulation pass, used to re-express world_to_view.
  std::array<double, 3> camera_position = {};
};

static std::shared_mutex state_mutex;
static std::unordered_map<reshade::api::device*, DeviceState> device_states;
// Latest guides per native command list. Guarded by state_mutex.
static std::unordered_map<uint64_t, LatestGuides> guides_by_cmd_list;

inline void LogSkipOnce(uint64_t reason_bit, const char* message) {
  if ((logged_skip_reasons.fetch_or(reason_bit) & reason_bit) == 0u) {
    reshade::log::message(reshade::log::level::warning, message);
  }
}

// Native D3D12 list type, or nullopt on other APIs.
inline std::optional<D3D12_COMMAND_LIST_TYPE> NativeListType(reshade::api::command_list* cmd_list) {
  if (cmd_list->get_device()->get_api() != reshade::api::device_api::d3d12) return std::nullopt;
  return reinterpret_cast<ID3D12GraphicsCommandList*>(cmd_list->get_native())->GetType();
}

inline bool IsComputeCommandList(reshade::api::command_list* cmd_list) {
  return NativeListType(cmd_list) == D3D12_COMMAND_LIST_TYPE_COMPUTE;
}

enum class ComputeBindKind { SRV, UAV, CBV };

// Root CBVs (push descriptors) have no descriptor table, so they are recorded per command list. Each binding keeps the
// layout it was pushed with, so a stale push from another root signature never matches.
struct RootCBVBinding {
  reshade::api::pipeline_layout layout = {0u};
  reshade::api::buffer_range buffer_range = {};
};
struct RootCBVState {
  std::shared_mutex mutex;
  std::unordered_map<reshade::api::command_list*, std::unordered_map<uint64_t, RootCBVBinding>> by_cmd_list;
};
inline RootCBVState root_cbvs;

inline uint64_t RegisterKey(uint32_t slot, uint32_t space) {
  return (static_cast<uint64_t>(space) << 32u) | slot;
}

// push_descriptors event: records constant buffer pushes visible to compute.
inline void OnPushDescriptors(
    reshade::api::command_list* cmd_list,
    reshade::api::shader_stage stages,
    reshade::api::pipeline_layout layout,
    uint32_t layout_param,
    const reshade::api::descriptor_table_update& update) {
  if (update.type != reshade::api::descriptor_type::constant_buffer) return;
  if (update.descriptors == nullptr) return;
  if (!renodx::utils::bitwise::HasFlag(stages, reshade::api::shader_stage::compute)) return;

  renodx::utils::pipeline_layout::GetPipelineLayoutData(layout, [&](const auto* layout_data) {
    if (layout_param >= layout_data->params.size()) return;
    const auto& param = layout_data->params[layout_param];
    const auto* buffer_ranges = static_cast<const reshade::api::buffer_range*>(update.descriptors);
    const auto store = [&](const reshade::api::descriptor_range& range) {
      if (range.type != update.type) return;
      if (update.binding < range.binding || update.binding - range.binding >= range.count) return;
      std::unique_lock lock(root_cbvs.mutex);
      auto& bindings = root_cbvs.by_cmd_list[cmd_list];
      for (uint32_t i = 0u; i < update.count; ++i) {
        const uint32_t slot = range.dx_register_index + (update.binding - range.binding) + i;
        bindings[RegisterKey(slot, range.dx_register_space)] = {.layout = layout, .buffer_range = buffer_ranges[i]};
      }
    };
    if (param.type == reshade::api::pipeline_layout_param_type::push_descriptors) {
      store(param.push_descriptors);
    } else if (param.type == reshade::api::pipeline_layout_param_type::push_descriptors_with_ranges) {
      for (uint32_t i = 0u; i < param.descriptor_table.count; ++i) store(param.descriptor_table.ranges[i]);
    } else if (param.type == reshade::api::pipeline_layout_param_type::push_descriptors_with_static_samplers) {
      // GotG's root CBVs (GenerateNRDBuffers and PreBlur b0) use this param type.
      for (uint32_t i = 0u; i < param.descriptor_table_with_static_samplers.count; ++i) store(param.descriptor_table_with_static_samplers.ranges[i]);
    }
  });
}

// reset_command_list and destroy_command_list events: drops the command list's root CBVs so a recycled handle cannot
// match stale pushes.
inline void OnForgetCommandList(reshade::api::command_list* cmd_list) {
  {
    std::unique_lock lock(root_cbvs.mutex);
    root_cbvs.by_cmd_list.erase(cmd_list);
  }
  std::unique_lock lock(state_mutex);
  guides_by_cmd_list.erase(reinterpret_cast<uint64_t>(cmd_list->get_native()));
}

// Finds the heap slot a compute register resolves to through the bound descriptor tables (D3D12 descriptor-table binds,
// which state::GetBoundResourceView does not cover). Returns nullopt when no table covers the register with that kind.
inline std::optional<renodx::utils::descriptor::DescriptorHeapSlot> FindComputeDescriptor(
    reshade::api::command_list* cmd_list,
    ComputeBindKind kind,
    uint32_t slot,
    uint32_t space) {
  auto* device = cmd_list->get_device();
  std::optional<renodx::utils::descriptor::DescriptorHeapSlot> result;

  const auto bound = renodx::utils::state::CopyBoundDescriptorTables(cmd_list, renodx::utils::state::PipelineBindPoint::COMPUTE);
  auto* descriptor_data = renodx::utils::data::Get<renodx::utils::descriptor::DeviceData>(device);
  const auto find_root_cbv = [&]() -> std::optional<renodx::utils::descriptor::DescriptorHeapSlot> {
    if (kind != ComputeBindKind::CBV || !bound.has_value() || bound->layout.handle == 0u) return std::nullopt;
    std::shared_lock lock(root_cbvs.mutex);
    const auto by_list = root_cbvs.by_cmd_list.find(cmd_list);
    if (by_list == root_cbvs.by_cmd_list.end()) return std::nullopt;
    const auto binding = by_list->second.find(RegisterKey(slot, space));
    if (binding == by_list->second.end() || binding->second.layout.handle != bound->layout.handle) return std::nullopt;
    renodx::utils::descriptor::DescriptorHeapSlot root_slot;
    root_slot.type = reshade::api::descriptor_type::constant_buffer;
    root_slot.buffer_range = binding->second.buffer_range;
    return root_slot;
  };
  if (!bound.has_value() || bound->layout.handle == 0u || descriptor_data == nullptr) return find_root_cbv();

  renodx::utils::pipeline_layout::GetPipelineLayoutData(bound->layout, [&](const auto* layout_data) {
    for (size_t param_index = 0; param_index < layout_data->params.size(); ++param_index) {
      if (param_index >= bound->tables.size()) break;
      const auto& param = layout_data->params[param_index];
      const auto& table = bound->tables[param_index];
      if (table.handle == 0u) continue;

      // Static-sampler ranges derive from descriptor_range, so one checker serves both param types.
      const auto try_range = [&](const reshade::api::descriptor_range& range) {
        if (range.count == 0u || range.dx_register_space != space) return false;
        if (!renodx::utils::bitwise::HasFlag(range.visibility, reshade::api::shader_stage::compute)) return false;

        const auto range_type = range.type;
        const bool is_uav_range = range_type == reshade::api::descriptor_type::unordered_access_view
                                  || range_type == reshade::api::descriptor_type::texture_unordered_access_view
                                  || range_type == reshade::api::descriptor_type::buffer_unordered_access_view;
        const bool is_srv_range = range_type == reshade::api::descriptor_type::shader_resource_view
                                  || range_type == reshade::api::descriptor_type::texture_shader_resource_view
                                  || range_type == reshade::api::descriptor_type::buffer_shader_resource_view;
        const bool is_cbv_range = range_type == reshade::api::descriptor_type::constant_buffer;
        bool range_matches = false;
        switch (kind) {
          case ComputeBindKind::SRV:
            range_matches = is_srv_range;
            break;
          case ComputeBindKind::UAV:
            range_matches = is_uav_range;
            break;
          case ComputeBindKind::CBV:
            range_matches = is_cbv_range;
            break;
        }
        if (!range_matches) return false;

        if (slot < range.dx_register_index) return false;
        const uint32_t range_offset = slot - range.dx_register_index;
        if (range.count != UINT32_MAX && range_offset >= range.count) return false;

        uint32_t base_offset = 0u;
        reshade::api::descriptor_heap heap = {0u};
        device->get_descriptor_heap_offset(table, range.binding, 0u, &heap, &base_offset);
        const std::shared_lock descriptor_lock(descriptor_data->mutex);
        const auto heap_pair = descriptor_data->heaps.find(heap.handle);
        if (heap_pair == descriptor_data->heaps.end()) return false;
        const auto& heap_data = heap_pair->second;
        const size_t heap_index = static_cast<size_t>(base_offset) + range_offset;
        if (heap_index >= heap_data.size()) return false;
        const bool slot_matches = kind == ComputeBindKind::CBV
                                      ? heap_data[heap_index].type == reshade::api::descriptor_type::constant_buffer
                                      : heap_data[heap_index].HasResourceView();
        if (!slot_matches) return false;
        result = heap_data[heap_index];
        return true;
      };

      if (param.type == reshade::api::pipeline_layout_param_type::descriptor_table) {
        for (uint32_t range_index = 0u; range_index < param.descriptor_table.count; ++range_index) {
          if (try_range(param.descriptor_table.ranges[range_index])) return;
        }
      } else if (param.type == reshade::api::pipeline_layout_param_type::descriptor_table_with_static_samplers) {
        for (uint32_t range_index = 0u; range_index < param.descriptor_table_with_static_samplers.count; ++range_index) {
          if (try_range(param.descriptor_table_with_static_samplers.ranges[range_index])) return;
        }
      }
    }
  });
  if (result.has_value()) return result;
  return find_root_cbv();
}

// Resolves a compute SRV/UAV register through the bound descriptor tables. Falls back to GetBoundResourceView when no
// table covers the register.
inline reshade::api::resource_view LookupComputeView(reshade::api::command_list* cmd_list, bool uav, uint32_t slot, uint32_t space) {
  const auto found = FindComputeDescriptor(cmd_list, uav ? ComputeBindKind::UAV : ComputeBindKind::SRV, slot, space);
  if (found.has_value()) return found->resource_view;

  return renodx::utils::state::GetBoundResourceView(
      cmd_list,
      reshade::api::shader_stage::compute,
      uav ? reshade::api::descriptor_type::texture_unordered_access_view : reshade::api::descriptor_type::texture_shader_resource_view,
      slot,
      space);
}

inline void DestroyRetired(reshade::api::device* device, const RetiredResources& retired) {
  for (const auto& view : retired.views) {
    if (view.handle != 0u) device->destroy_resource_view(view);
  }
  for (const auto& resource : retired.resources) {
    if (resource.handle != 0u) device->destroy_resource(resource);
  }
}

// Advances each retired entry by one present and destroys the ones that have aged out.
inline void AgeRetired(reshade::api::device* device, std::vector<RetiredResources>* retired) {
  std::erase_if(*retired, [device](RetiredResources& entry) {
    if (--entry.presents_left > 0u) return false;
    DestroyRetired(device, entry);
    return true;
  });
}

// Moves the live guide targets to the retired list; they are destroyed a few presents later.
inline void RetireGuideTextures(DeviceState& state) {
  RetiredResources retired;
  for (auto& view : state.guide_uavs) {
    if (view.handle != 0u) retired.views.push_back(view);
    view = {0u};
  }
  for (auto& resource : state.guide_resources) {
    if (resource.handle != 0u) retired.resources.push_back(resource);
    resource = {0u};
  }
  if (!retired.views.empty() || !retired.resources.empty()) state.retired.push_back(std::move(retired));
  state.guide_width = 0u;
  state.guide_height = 0u;
}

// Creates the three RGBA16F guide targets. Views are UAV-only because the pass writes them and the DLSS inputs are copied out later.
inline bool CreateGuideTextures(reshade::api::device* device, DeviceState& state, uint32_t width, uint32_t height) {
  RetireGuideTextures(state);
  const reshade::api::resource_desc guide_desc(
      width,
      height,
      1u,
      1u,
      reshade::api::format::r16g16b16a16_float,
      1u,
      reshade::api::memory_heap::gpu_only,
      reshade::api::resource_usage::shader_resource | reshade::api::resource_usage::unordered_access);
  for (size_t i = 0; i < state.guide_resources.size(); ++i) {
    if (!device->create_resource(guide_desc, nullptr, reshade::api::resource_usage::shader_resource, &state.guide_resources[i])) {
      RetireGuideTextures(state);
      return false;
    }
    if (!device->create_resource_view(
            state.guide_resources[i],
            reshade::api::resource_usage::unordered_access,
            reshade::api::resource_view_desc(reshade::api::format::r16g16b16a16_float),
            &state.guide_uavs[i])) {
      RetireGuideTextures(state);
      return false;
    }
  }
  state.guide_width = width;
  state.guide_height = height;
  return true;
}

// Caches an SRV on the NRD world-normal texture; it is rebuilt only when the bound resource changes.
inline void RecordNRDNormals(reshade::api::command_list* cmd_list) {
  auto* device = cmd_list->get_device();
  const auto normals_view = LookupComputeView(cmd_list, true, 1u, 0u);
  if (normals_view.handle == 0u) {
    LogSkipOnce(1u << 0, "rr_guides: UAV u1 space0 (NRD normals) not found, guide pass not recorded");
    return;
  }
  const auto normals = device->get_resource_from_view(normals_view);
  if (normals.handle == 0u) return;

  std::unique_lock lock(state_mutex);
  auto& state = device_states[device];
  if (state.nrd_normals.handle == normals.handle && state.nrd_normals_srv.handle != 0u) return;

  if (state.nrd_normals_srv.handle != 0u) state.retired.push_back({.views = {state.nrd_normals_srv}});
  state.nrd_normals = {0u};
  state.nrd_normals_srv = {0u};
  reshade::api::resource_view srv = {0u};
  if (!device->create_resource_view(
          normals,
          reshade::api::resource_usage::shader_resource,
          reshade::api::resource_view_desc(reshade::api::format::r8g8b8a8_unorm),
          &srv)) {
    return;
  }
  state.nrd_normals = normals;
  state.nrd_normals_srv = srv;
}

// Runs the guide pass alongside the game's combine dispatch. Skips the pass when any input is missing.
inline void RunGuidePass(reshade::api::command_list* cmd_list) {
  if (IsComputeCommandList(cmd_list)) {
    LogSkipOnce(1u << 29, "rr_guides: compute command list, pass skipped");
    return;
  }
  auto* device = cmd_list->get_device();
  const auto normal_view = LookupComputeView(cmd_list, false, 12u, 1u);
  const auto base_color_view = LookupComputeView(cmd_list, false, 13u, 1u);
  const auto material_view = LookupComputeView(cmd_list, false, 14u, 1u);
  const auto combine_output_view = LookupComputeView(cmd_list, true, 0u, 0u);

  if (normal_view.handle == 0u) {
    LogSkipOnce(1u << 1, "rr_guides: SRV t12 space1 not found, game combine runs");
    return;
  }
  if (base_color_view.handle == 0u) {
    LogSkipOnce(1u << 2, "rr_guides: SRV t13 space1 not found, game combine runs");
    return;
  }
  if (material_view.handle == 0u) {
    LogSkipOnce(1u << 3, "rr_guides: SRV t14 space1 not found, game combine runs");
    return;
  }
  if (combine_output_view.handle == 0u) {
    LogSkipOnce(1u << 4, "rr_guides: UAV u0 space0 (combine output) not found, game combine runs");
    return;
  }

  std::unique_lock lock(state_mutex);
  auto& state = device_states[device];
  if (state.nrd_normals_srv.handle == 0u) {
    LogSkipOnce(1u << 5, "rr_guides: NRD normals not recorded, game combine runs");
    return;
  }

  const auto base_color_desc = renodx::utils::resource::GetResourceDesc(device, device->get_resource_from_view(base_color_view));
  if (base_color_desc.type != reshade::api::resource_type::texture_2d) {
    LogSkipOnce(1u << 6, "rr_guides: base colour resource is not a 2D texture, game combine runs");
    return;
  }
  const auto width = base_color_desc.texture.width;
  const auto height = base_color_desc.texture.height;
  if (state.guide_width != width || state.guide_height != height) {
    if (!CreateGuideTextures(device, state, width, height)) {
      LogSkipOnce(1u << 7, "rr_guides: guide texture creation failed, game combine runs");
      return;
    }
  }

  state.pass.pipeline_subobjects.compute_shader = __rr_guides;
  state.pass.shader_resource_slots.views = {state.nrd_normals_srv, normal_view, base_color_view, material_view};
  state.pass.unordered_access_slots.views = {
      state.guide_uavs[0],
      state.guide_uavs[1],
      state.guide_uavs[2],
  };
  float projection_scale_x = 0.f;
  float projection_scale_y = 0.f;
  if (state.has_matrices) {
    projection_scale_x = state.view_to_clip[11] / state.view_to_clip[0];
    projection_scale_y = state.view_to_clip[11] / state.view_to_clip[5];
  }
  {
    const std::shared_lock smoothing_lock(roughness_smoothing.mutex);
    state.params = {
        static_cast<float>(width),
        static_cast<float>(height),
        0.f,
        0.f,
        roughness_smoothing.non_metal,
        roughness_smoothing.metal,
        0.f,
        0.f,
        projection_scale_x,
        projection_scale_y,
        0.f,
        0.f,
    };
  }
  state.pass.push_constants[{.slot = 0u, .space = 0u}] = state.params;
  state.pass.dispatch_group_counts = std::make_tuple((width + 7u) / 8u, (height + 7u) / 8u, 1u);

  // Guides are written in UAV state; return them to SRV state after the pass for consumers, even if Render fails.
  for (const auto& resource : state.guide_resources) {
    cmd_list->barrier(resource, reshade::api::resource_usage::shader_resource, reshade::api::resource_usage::unordered_access);
  }
  const bool rendered = state.pass.Render(cmd_list);
  for (const auto& resource : state.guide_resources) {
    cmd_list->barrier(resource, reshade::api::resource_usage::unordered_access, reshade::api::resource_usage::shader_resource);
  }
  if (!rendered) return;
  // Re-express the translation against the accumulated camera position, so the world origin stays consistent between frames.
  std::array<float, 16> world_to_view = state.world_to_view;
  for (uint32_t j = 0u; j < 3u; ++j) {
    double offset = 0.0;
    for (uint32_t k = 0u; k < 3u; ++k) {
      offset += state.camera_position[k] * state.world_to_view[k * 4u + j];
    }
    world_to_view[12u + j] = static_cast<float>(state.world_to_view[12u + j] - offset);
  }
  // DLSS requires unjittered matrices. The sub-pixel jitter terms (view_to_clip[8] and [9]) are zeroed only when both
  // are below 0.01 in magnitude.
  std::array<float, 16> view_to_clip = state.view_to_clip;
  if (std::abs(view_to_clip[8]) < 0.01f && std::abs(view_to_clip[9]) < 0.01f) {
    view_to_clip[8] = 0.f;
    view_to_clip[9] = 0.f;
  }
  const bool hit_distance_at_guide_size = state.hit_distance_width == width && state.hit_distance_height == height;
  const auto native_cmd_list = reinterpret_cast<uint64_t>(cmd_list->get_native());
  const auto guides = LatestGuides{
      .normal_roughness = state.guide_resources[0],
      .diffuse_albedo = state.guide_resources[1],
      .specular_albedo = state.guide_resources[2],
      .width = width,
      .height = height,
      .frame_index = CurrentFrameIndex(),
      .specular_hit_distance = (hit_distance_at_guide_size ? state.hit_distance : reshade::api::resource{0u}),
      .world_to_view = world_to_view,
      .view_to_clip = view_to_clip,
      .has_matrices = state.has_matrices,
  };
  latest_guides = guides;
  guides_by_cmd_list[native_cmd_list] = guides;
}

// Runs before the game's PreBlur dispatch. Its inputs are already written at this point, so the pass reads them directly.
inline void RunHitDistancePass(reshade::api::command_list* cmd_list) {
  if (IsComputeCommandList(cmd_list)) {
    LogSkipOnce(1u << 29, "rr_guides: compute command list, pass skipped");
    return;
  }
  auto* device = cmd_list->get_device();
  const auto cb_slot = FindComputeDescriptor(cmd_list, ComputeBindKind::CBV, 0u, 0u);
  if (!cb_slot.has_value()) {
    LogSkipOnce(1u << 13, "rr_guides: CBV b0 space0 not found, hit distance not recorded");
    return;
  }
  const auto trace_view = LookupComputeView(cmd_list, false, 2u, 0u);
  const auto view_z_view = LookupComputeView(cmd_list, false, 1u, 0u);
  const auto normal_roughness_view = LookupComputeView(cmd_list, false, 0u, 0u);
  if (trace_view.handle == 0u || view_z_view.handle == 0u || normal_roughness_view.handle == 0u) {
    LogSkipOnce(1u << 14, "rr_guides: PreBlur SRV t0-t2 space0 not found, hit distance not recorded");
    return;
  }
  const auto view_z_desc = renodx::utils::resource::GetResourceDesc(device, device->get_resource_from_view(view_z_view));
  if (view_z_desc.type != reshade::api::resource_type::texture_2d) {
    LogSkipOnce(1u << 15, "rr_guides: PreBlur view Z is not a 2D texture, hit distance not recorded");
    return;
  }
  const auto width = view_z_desc.texture.width;
  const auto height = view_z_desc.texture.height;

  std::unique_lock lock(state_mutex);
  auto& state = device_states[device];
  if (state.hit_distance_width != width || state.hit_distance_height != height) {
    RetiredResources retired;
    if (state.hit_distance_uav.handle != 0u) retired.views.push_back(state.hit_distance_uav);
    if (state.hit_distance.handle != 0u) retired.resources.push_back(state.hit_distance);
    if (!retired.views.empty() || !retired.resources.empty()) state.retired.push_back(std::move(retired));
    state.hit_distance = {0u};
    state.hit_distance_uav = {0u};
    const reshade::api::resource_desc hit_desc(
        width,
        height,
        1u,
        1u,
        reshade::api::format::r16_float,
        1u,
        reshade::api::memory_heap::gpu_only,
        reshade::api::resource_usage::shader_resource | reshade::api::resource_usage::unordered_access);
    if (!device->create_resource(hit_desc, nullptr, reshade::api::resource_usage::shader_resource, &state.hit_distance)
        || !device->create_resource_view(
            state.hit_distance,
            reshade::api::resource_usage::unordered_access,
            reshade::api::resource_view_desc(reshade::api::format::r16_float),
            &state.hit_distance_uav)) {
      LogSkipOnce(1u << 16, "rr_guides: hit distance texture creation failed");
      return;
    }
    state.hit_distance_width = width;
    state.hit_distance_height = height;
  }

  const auto cb = cb_slot->buffer_range;
  void* mapped = nullptr;
  if (!device->map_buffer_region(cb.buffer, cb.offset, PRE_BLUR_CB_BYTES, reshade::api::map_access::read_only, &mapped)) {
    LogSkipOnce(1u << 17, "rr_guides: map of CBV b0 space0 failed, hit distance not recorded");
    return;
  }
  const auto* floats = static_cast<const float*>(mapped);
  const auto* words = static_cast<const uint32_t*>(mapped);
  std::copy_n(floats + PRE_BLUR_CB_VIEW_TO_CLIP, 16, state.view_to_clip.begin());
  std::copy_n(floats + PRE_BLUR_CB_WORLD_TO_VIEW, 16, state.world_to_view.begin());
  std::copy_n(floats + PRE_BLUR_CB_SPEC_HIT_DIST, 4, state.hit_params.begin());
  state.hit_params[4] = static_cast<float>(width);
  state.hit_params[5] = static_cast<float>(height);
  state.hit_params[6] = (words[PRE_BLUR_CB_CHECKERBOARD] != CHECKERBOARD_MODE_FULL_RES && full_res_active == 0.f ? 1.f : 0.f);
  state.hit_params[7] = floats[PRE_BLUR_CB_INF];
  state.has_matrices = true;
  device->unmap_buffer_region(cb.buffer);

  state.hit_pass.pipeline_subobjects.compute_shader = __rr_hitdist;
  state.hit_pass.shader_resource_slots.views = {trace_view, view_z_view, normal_roughness_view};
  state.hit_pass.unordered_access_slots.views = {state.hit_distance_uav};
  state.hit_pass.push_constants[{.slot = 0u, .space = 0u}] = state.hit_params;
  state.hit_pass.dispatch_group_counts = std::make_tuple((width + 7u) / 8u, (height + 7u) / 8u, 1u);
  cmd_list->barrier(state.hit_distance, reshade::api::resource_usage::shader_resource, reshade::api::resource_usage::unordered_access);
  state.hit_pass.Render(cmd_list);
  cmd_list->barrier(state.hit_distance, reshade::api::resource_usage::unordered_access, reshade::api::resource_usage::shader_resource);
}

// Dispatch event: records the NRD normals, builds the hit distance at PreBlur, and runs the guide pass when rr_enable is on.
inline bool OnDispatch(reshade::api::command_list* cmd_list, uint32_t /*group_count_x*/, uint32_t /*group_count_y*/, uint32_t /*group_count_z*/) {
  if (cmd_list->get_device()->get_api() != reshade::api::device_api::d3d12) return false;

  const auto hash = renodx::utils::state::GetCurrentShaderHash(cmd_list, reshade::api::pipeline_stage::compute_shader);
  if (hash == GENERATE_NRD_BUFFERS_HASH) {
    RecordNRDNormals(cmd_list);
    return false;
  }
  if (hash == PRE_BLUR_HASH) {
    if (rr_enable != 0.f) {
      RunHitDistancePass(cmd_list);
    }
    return false;
  }
  if (hash == TEMPORAL_ACCUMULATION_HASH && rr_enable != 0.f) {
    auto* device = cmd_list->get_device();
    const auto cb_slot = FindComputeDescriptor(cmd_list, ComputeBindKind::CBV, 0u, 0u);
    if (!cb_slot.has_value()) {
      LogSkipOnce(1u << 24, "rr_guides: CBV b0 space0 not found, camera position not tracked");
      return false;
    }
    const auto cb = cb_slot->buffer_range;
    void* mapped = nullptr;
    if (!device->map_buffer_region(cb.buffer, cb.offset, TA_CB_BYTES, reshade::api::map_access::read_only, &mapped)) {
      LogSkipOnce(1u << 27, "rr_guides: map of TA CBV b0 space0 failed, camera position not tracked");
      return false;
    }
    const auto* floats = static_cast<const float*>(mapped);
    const float* prev_world_to_view = floats + TA_CB_WORLD_TO_VIEW_PREV;
    // Translation row of the previous world_to_view, times the transpose of its rotation.
    std::array<double, 3> translation = {};
    for (uint32_t j = 0u; j < 3u; ++j) {
      for (uint32_t k = 0u; k < 3u; ++k) {
        translation[j] += static_cast<double>(prev_world_to_view[12u + k]) * prev_world_to_view[j * 4u + k];
      }
    }

    std::unique_lock lock(state_mutex);
    auto& state = device_states[device];
    for (uint32_t j = 0u; j < 3u; ++j) {
      state.camera_position[j] += translation[j];
    }
    device->unmap_buffer_region(cb.buffer);
    return false;
  }
  if (hash != COMBINE_SSR_RT_HASH) return false;
  if (rr_enable != 0.f) {
    RunGuidePass(cmd_list);
  }
  return false;
}

inline std::optional<LatestGuides> GetLatestGuides() {
  std::shared_lock lock(state_mutex);
  return latest_guides;
}

inline std::optional<LatestGuides> GetGuidesForCommandList(uint64_t native_cmd_list) {
  std::shared_lock lock(state_mutex);
  const auto found = guides_by_cmd_list.find(native_cmd_list);
  if (found == guides_by_cmd_list.end()) return std::nullopt;
  return found->second;
}

// Present event: advances the frame index and destroys retired resources once they have aged through RETIRE_PRESENT_COUNT presents.
inline void OnPresent() {
  present_frame_index.fetch_add(1u);
  std::unique_lock lock(state_mutex);
  for (auto& [device, state] : device_states) {
    AgeRetired(device, &state.retired);
  }
}

// Drops the cached NRD normals SRV when its texture is destroyed, so a reused handle cannot match a stale view.
inline void OnDestroyResource(reshade::api::device* device, reshade::api::resource resource) {
  {
    std::shared_lock lock(state_mutex);
    const auto found = device_states.find(device);
    if (found == device_states.end()) return;
    if (found->second.nrd_normals.handle != resource.handle) return;
  }
  std::unique_lock lock(state_mutex);
  const auto found = device_states.find(device);
  if (found == device_states.end()) return;
  auto& state = found->second;
  if (state.nrd_normals.handle != resource.handle) return;
  if (state.nrd_normals_srv.handle != 0u) state.retired.push_back({.views = {state.nrd_normals_srv}});
  state.nrd_normals = {0u};
  state.nrd_normals_srv = {0u};
}

inline void OnDestroyDevice(reshade::api::device* device) {
  std::unique_lock lock(state_mutex);
  guides_by_cmd_list.clear();
  const auto found = device_states.find(device);
  if (found == device_states.end()) return;
  auto& state = found->second;
  state.pass.DestroyAll(device);
  state.hit_pass.DestroyAll(device);
  RetireGuideTextures(state);
  state.retired.push_back({.resources = {state.hit_distance}, .views = {state.hit_distance_uav}});
  if (state.nrd_normals_srv.handle != 0u) state.retired.push_back({.views = {state.nrd_normals_srv}});
  for (const auto& retired : state.retired) {
    DestroyRetired(device, retired);
  }
  device_states.erase(found);
}

}  // namespace rr_guides
