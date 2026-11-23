#pragma once

#include <array>
#include <bit>
#include <cstdint>
#include <shared_mutex>
#include <tuple>

#include <embed/shaders.h>
#include <include/reshade.hpp>

#include "../../utils/render.hpp"
#include "../../utils/resource.hpp"
#include "../../utils/state.hpp"
#include "./rr_guides.hpp"
#include "./rt_multiray.hpp"

// Replaces the game's repeating 64-frame blue-noise ray pattern with fresh white noise every frame. The RT trace reads
// the noise texture (t9 space2). After the trace, CombineSSRandRT backs up the game's original texture once, refills an
// owned copy, and copies it over the game's texture, so the next trace uses new samples. When white noise turns off, the
// backup is copied back over the game's texture. The copies need a direct list, so compute lists skip them. Ray
// Reconstruction's denoiser needs uncorrelated sampling. Multi-ray use (rt_multiray) keeps one owned volume per ray, and
// CopyVolume copies a chosen volume into the game's texture before that ray's trace.
namespace rt_noise {

constexpr uint32_t NOISE_SIZE = 64u;
// Thread group size of __rt_noise; NOISE_SIZE must be a multiple of it.
constexpr uint32_t NOISE_THREADS = 4u;

// Bound to the "White Noise Sampling" setting: 0 keeps the game's blue noise.
inline float white_noise_setting = 0.f;

struct NoiseState {
  std::shared_mutex mutex;
  reshade::api::device* device = nullptr;
  // Game's noise texture from the latest RT trace. Consumed by the next CombineSSRandRT dispatch.
  reshade::api::resource game_texture = {0u};
  // Owned copy of the game's original noise contents, restored over the game texture when white noise turns off.
  reshade::api::resource backup_texture = {0u};
  // Game texture that backup_texture was copied from and that has been overwritten with white noise.
  reshade::api::resource backed_up_game_texture = {0u};
  std::array<reshade::api::resource, rt_multiray::MAX_RAYS> owned_texture = {};
  std::array<reshade::api::resource_view, rt_multiray::MAX_RAYS> owned_uav = {};
  std::array<renodx::utils::render::RenderPass, rt_multiray::MAX_RAYS> pass;
  // Written to push constant b0 space0 each refill; the shader reads it as the bit pattern of a uint.
  std::array<float, 4> seed_params = {};
  uint32_t seed = 0u;
};
inline NoiseState noise_state;

// Called from the RT trace dispatch. Does no GPU work there: a compute pass would unbind the ray-tracing pipeline.
inline void RecordNoiseTexture(reshade::api::command_list* cmd_list) {
  const auto view = rr_guides::LookupComputeView(cmd_list, false, 9u, 2u);
  if (view.handle == 0u) {
    rr_guides::LogSkipOnce(1ull << 32, "rt_noise: SRV t9 space2 not found, white noise refill skipped");
    return;
  }

  auto* device = cmd_list->get_device();
  const auto resource = device->get_resource_from_view(view);
  const auto desc = renodx::utils::resource::GetResourceDesc(device, resource);
  const bool is_noise_texture = desc.type == reshade::api::resource_type::texture_3d
                                && desc.texture.width == NOISE_SIZE
                                && desc.texture.height == NOISE_SIZE
                                && desc.texture.depth_or_layers == NOISE_SIZE
                                && desc.texture.format == reshade::api::format::r16g16_unorm;
  if (!is_noise_texture) {
    rr_guides::LogSkipOnce(1ull << 33, "rt_noise: SRV t9 space2 is not a 64x64x64 r16g16_unorm texture, white noise refill skipped");
    return;
  }

  std::unique_lock lock(noise_state.mutex);
  noise_state.game_texture = resource;
}

// Copies an owned noise volume over the game's texture and returns both to their steady states. Caller holds the lock.
inline void CopyOwnedToGame(reshade::api::command_list* cmd_list, reshade::api::resource owned, reshade::api::resource game) {
  cmd_list->barrier(owned, reshade::api::resource_usage::unordered_access, reshade::api::resource_usage::copy_source);
  cmd_list->barrier(game, reshade::api::resource_usage::shader_resource, reshade::api::resource_usage::copy_dest);
  cmd_list->copy_resource(owned, game);
  cmd_list->barrier(game, reshade::api::resource_usage::copy_dest, reshade::api::resource_usage::shader_resource);
  cmd_list->barrier(owned, reshade::api::resource_usage::copy_source, reshade::api::resource_usage::unordered_access);
}

// Dispatch event for CombineSSRandRT, which runs after the trace. Refills the owned noise volumes and copies volume 0 over
// the game's texture before the game's dispatch. Never skips the game's dispatch.
inline bool OnDispatch(reshade::api::command_list* cmd_list, uint32_t /*group_count_x*/, uint32_t /*group_count_y*/, uint32_t /*group_count_z*/) {
  if (renodx::utils::state::GetCurrentShaderHash(cmd_list, reshade::api::pipeline_stage::compute_shader)
      != rr_guides::COMBINE_SSR_RT_HASH) {
    return false;
  }

  const uint32_t volume_count = rt_multiray::RaysPerPixel();
  if (white_noise_setting == 0.f && volume_count <= 1u) {
    std::unique_lock lock(noise_state.mutex);
    if (noise_state.backed_up_game_texture.handle != 0u && !rr_guides::IsComputeCommandList(cmd_list)) {
      cmd_list->barrier(noise_state.backed_up_game_texture, reshade::api::resource_usage::shader_resource, reshade::api::resource_usage::copy_dest);
      cmd_list->copy_resource(noise_state.backup_texture, noise_state.backed_up_game_texture);
      cmd_list->barrier(noise_state.backed_up_game_texture, reshade::api::resource_usage::copy_dest, reshade::api::resource_usage::shader_resource);
      noise_state.backed_up_game_texture = {0u};
    }
    return false;
  }

  auto* device = cmd_list->get_device();
  std::unique_lock lock(noise_state.mutex);
  if (noise_state.game_texture.handle == 0u) return false;
  const auto game_texture = noise_state.game_texture;
  noise_state.game_texture = {0u};

  // The shader_resource and copy transitions below are not legal on compute lists. The recorded texture stays cleared.
  if (rr_guides::IsComputeCommandList(cmd_list)) {
    rr_guides::LogSkipOnce(1ull << 34, "rt_noise: combine on a compute list, white noise refill skipped");
    return false;
  }

  const auto make_noise_desc = [](reshade::api::resource_usage usage) {
    return reshade::api::resource_desc(
        reshade::api::resource_type::texture_3d,
        NOISE_SIZE,
        NOISE_SIZE,
        NOISE_SIZE,
        1u,
        reshade::api::format::r16g16_unorm,
        1u,
        reshade::api::memory_heap::gpu_only,
        usage);
  };

  for (uint32_t i = 0u; i < volume_count; ++i) {
    if (noise_state.owned_texture[i].handle != 0u) continue;
    const bool texture_created = device->create_resource(
        make_noise_desc(reshade::api::resource_usage::unordered_access | reshade::api::resource_usage::copy_source | reshade::api::resource_usage::shader_resource),
        nullptr,
        reshade::api::resource_usage::unordered_access,
        &noise_state.owned_texture[i]);
    const bool uav_created = texture_created && device->create_resource_view(
        noise_state.owned_texture[i],
        reshade::api::resource_usage::unordered_access,
        // The format-only resource_view_desc constructor means texture_2d; a 2D UAV on this 3D texture is an invalid
        // call that removes the D3D12 device (DXGI_ERROR_INVALID_CALL). The last argument is the layer (depth slice)
        // count, and UINT32_MAX covers all slices.
        reshade::api::resource_view_desc(reshade::api::resource_view_type::texture_3d, reshade::api::format::r16g16_unorm, 0u, 1u, 0u, UINT32_MAX),
        &noise_state.owned_uav[i]);
    if (!uav_created) {
      if (texture_created) device->destroy_resource(noise_state.owned_texture[i]);
      noise_state.owned_texture[i] = {0u};
      return false;
    }
    noise_state.device = device;
  }

  for (uint32_t i = 0u; i < volume_count; ++i) {
    ++noise_state.seed;
    noise_state.seed_params[0] = std::bit_cast<float>(noise_state.seed);
    auto& pass = noise_state.pass[i];
    pass.pipeline_subobjects.compute_shader = __rt_noise;
    pass.unordered_access_slots.views = {noise_state.owned_uav[i]};
    pass.push_constants[{.slot = 0u, .space = 0u}] = noise_state.seed_params;
    pass.dispatch_group_counts = std::make_tuple(
        NOISE_SIZE / NOISE_THREADS,
        NOISE_SIZE / NOISE_THREADS,
        NOISE_SIZE / NOISE_THREADS);
    if (!pass.Render(cmd_list)) return false;
  }

  if (noise_state.backed_up_game_texture.handle != game_texture.handle) {
    if (noise_state.backup_texture.handle == 0u) {
      const bool backup_created = device->create_resource(
          make_noise_desc(reshade::api::resource_usage::copy_dest | reshade::api::resource_usage::copy_source),
          nullptr,
          reshade::api::resource_usage::copy_source,
          &noise_state.backup_texture);
      if (!backup_created) {
        rr_guides::LogSkipOnce(1u << 28, "rt_noise: backup texture creation failed, white noise refill skipped");
        return false;
      }
    }
    cmd_list->barrier(game_texture, reshade::api::resource_usage::shader_resource, reshade::api::resource_usage::copy_source);
    cmd_list->barrier(noise_state.backup_texture, reshade::api::resource_usage::copy_source, reshade::api::resource_usage::copy_dest);
    cmd_list->copy_resource(game_texture, noise_state.backup_texture);
    cmd_list->barrier(noise_state.backup_texture, reshade::api::resource_usage::copy_dest, reshade::api::resource_usage::copy_source);
    cmd_list->barrier(game_texture, reshade::api::resource_usage::copy_source, reshade::api::resource_usage::shader_resource);
    noise_state.backed_up_game_texture = game_texture;
  }

  CopyOwnedToGame(cmd_list, noise_state.owned_texture[0], game_texture);
  return false;
}

// Copies owned volume `index` over the game's recorded noise texture on a direct list. The volume must have been refilled
// by OnDispatch. Does not clear game_texture.
inline bool CopyVolume(reshade::api::command_list* cmd_list, uint32_t index) {
  std::unique_lock lock(noise_state.mutex);
  if (noise_state.game_texture.handle == 0u) return false;
  if (noise_state.game_texture.handle != noise_state.backed_up_game_texture.handle) return false;
  if (index >= rt_multiray::MAX_RAYS) return false;
  if (noise_state.owned_texture[index].handle == 0u) return false;
  if (rr_guides::IsComputeCommandList(cmd_list)) return false;

  CopyOwnedToGame(cmd_list, noise_state.owned_texture[index], noise_state.game_texture);
  return true;
}

// Drops the recorded game texture or its backed-up copy when the game destroys it, so no stale handle is used later.
inline void OnDestroyResource(reshade::api::device* /*device*/, reshade::api::resource resource) {
  {
    std::shared_lock lock(noise_state.mutex);
    if (resource.handle != noise_state.game_texture.handle && resource.handle != noise_state.backed_up_game_texture.handle) {
      return;
    }
  }
  std::unique_lock lock(noise_state.mutex);
  if (resource.handle == noise_state.game_texture.handle) noise_state.game_texture = {0u};
  if (resource.handle == noise_state.backed_up_game_texture.handle) noise_state.backed_up_game_texture = {0u};
}

inline void OnDestroyDevice(reshade::api::device* device) {
  std::unique_lock lock(noise_state.mutex);
  if (noise_state.device != device) return;
  for (uint32_t i = 0u; i < rt_multiray::MAX_RAYS; ++i) {
    noise_state.pass[i].DestroyAll(device);
    if (noise_state.owned_uav[i].handle != 0u) device->destroy_resource_view(noise_state.owned_uav[i]);
    if (noise_state.owned_texture[i].handle != 0u) device->destroy_resource(noise_state.owned_texture[i]);
    noise_state.owned_uav[i] = {0u};
    noise_state.owned_texture[i] = {0u};
  }
  if (noise_state.backup_texture.handle != 0u) device->destroy_resource(noise_state.backup_texture);
  noise_state.backup_texture = {0u};
  noise_state.game_texture = {0u};
  noise_state.backed_up_game_texture = {0u};
  noise_state.device = nullptr;
}

}  // namespace rt_noise
