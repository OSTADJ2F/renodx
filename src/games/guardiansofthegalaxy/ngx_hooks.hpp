#pragma once

#include <Windows.h>
#include <d3d12.h>
#include <nvsdk_ngx.h>
#include <nvsdk_ngx_defs_dlssd.h>

#include <array>
#include <atomic>
#include <cstdint>
#include <exception>
#include <cstring>
#include <optional>
#include <shared_mutex>
#include <sstream>
#include <string>
#include <vector>

#include <include/reshade.hpp>

#include "../../utils/detour.hpp"
#include "./rr_guides.hpp"

// DLSS (NGX) feature hooks. They route the driver's DLSS preset and Ray Reconstruction calls: the addon's preset settings
// are applied at create time, and an EvaluateFeature call can be replaced by our own Ray Reconstruction evaluate.
namespace ngx_hooks {

// Index into DLSS_RENDER_PRESETS, bound to the addon's DLSS Preset setting. 0 leaves the driver's choice.
inline float dlss_preset_index = 0.f;

constexpr unsigned int DLSS_RENDER_PRESETS[] = {
    NVSDK_NGX_DLSS_Hint_Render_Preset_Default,
    NVSDK_NGX_DLSS_Hint_Render_Preset_E,
    NVSDK_NGX_DLSS_Hint_Render_Preset_F,
    NVSDK_NGX_DLSS_Hint_Render_Preset_J,
    NVSDK_NGX_DLSS_Hint_Render_Preset_K,
    NVSDK_NGX_DLSS_Hint_Render_Preset_L,
    NVSDK_NGX_DLSS_Hint_Render_Preset_M,
};

constexpr const char* DLSS_RENDER_PRESET_HINTS[] = {
    NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_DLAA,
    NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Quality,
    NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Balanced,
    NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Performance,
    NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_UltraPerformance,
    NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_UltraQuality,
};

// Index into RR_RENDER_PRESETS, bound to the addon's Ray Reconstruction Preset setting. 0 leaves the driver's choice.
inline float rr_preset_index = 0.f;

constexpr unsigned int RR_RENDER_PRESETS[] = {
    NVSDK_NGX_RayReconstruction_Hint_Render_Preset_Default,
    NVSDK_NGX_RayReconstruction_Hint_Render_Preset_D,
    NVSDK_NGX_RayReconstruction_Hint_Render_Preset_E,
    NVSDK_NGX_RayReconstruction_Hint_Render_Preset_F,
};

constexpr const char* RR_RENDER_PRESET_HINTS[] = {
    NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_DLAA,
    NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_Quality,
    NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_Balanced,
    NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_Performance,
    NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_UltraPerformance,
    NVSDK_NGX_Parameter_RayReconstruction_Hint_Render_Preset_UltraQuality,
};

using CreateFeatureFn = NVSDK_NGX_Result(NVSDK_CONV*)(ID3D12GraphicsCommandList*, NVSDK_NGX_Feature, const NVSDK_NGX_Parameter*, NVSDK_NGX_Handle**);
using EvaluateFeatureFn = NVSDK_NGX_Result(NVSDK_CONV*)(ID3D12GraphicsCommandList*, const NVSDK_NGX_Handle*, const NVSDK_NGX_Parameter*, PFN_NVSDK_NGX_ProgressCallback);
using EvaluateFeatureCFn = NVSDK_NGX_Result(NVSDK_CONV*)(ID3D12GraphicsCommandList*, const NVSDK_NGX_Handle*, const NVSDK_NGX_Parameter*, PFN_NVSDK_NGX_ProgressCallback_C);
using ReleaseFeatureFn = NVSDK_NGX_Result(NVSDK_CONV*)(NVSDK_NGX_Handle*);

static CreateFeatureFn real_create_feature = nullptr;
static EvaluateFeatureFn real_evaluate_feature = nullptr;
static EvaluateFeatureCFn real_evaluate_feature_c = nullptr;
static ReleaseFeatureFn real_release_feature = nullptr;

// NVSDK_NGX_Handle is only a forward declaration in the SDK headers; the driver's struct begins with the feature Id.
inline unsigned int HandleId(const NVSDK_NGX_Handle* handle) {
  if (handle == nullptr) return 0u;
  return *reinterpret_cast<const unsigned int*>(handle);
}

// Maps a settings index to the driver preset value. 0 when the index is out of range.
template <size_t N>
inline unsigned int MappedPreset(float index, const unsigned int (&presets)[N]) {
  const int preset_index = static_cast<int>(index);
  const bool has_preset_index = preset_index >= 0 && preset_index < static_cast<int>(N);
  return has_preset_index ? presets[preset_index] : 0u;
}

// Writes the preset to every hint name. A preset of 0 leaves the parameters untouched.
template <size_t N>
inline void SetPresetHints(NVSDK_NGX_Parameter* params, const char* const (&hints)[N], unsigned int preset) {
  if (preset == 0u) return;
  for (const char* hint : hints) {
    params->Set(hint, preset);
  }
}

// Sets the RR render preset hints for the selected model.
inline void ApplyRayReconstructionPreset(NVSDK_NGX_Parameter* params) {
  SetPresetHints(params, RR_RENDER_PRESET_HINTS, MappedPreset(rr_preset_index, RR_RENDER_PRESETS));
}

// Preset selected in the addon settings, as the value the driver takes. 0 when the index is out of range.
inline unsigned int MappedSuperSamplingPreset() {
  return MappedPreset(dlss_preset_index, DLSS_RENDER_PRESETS);
}

inline void ApplySuperSamplingPreset(NVSDK_NGX_Parameter* params, unsigned int preset) {
  SetPresetHints(params, DLSS_RENDER_PRESET_HINTS, preset);
}

// Reads an unsigned or signed integer parameter as unsigned. Returns false when the name is absent.
inline bool ReadUInt(const NVSDK_NGX_Parameter* params, const char* name, unsigned int* value) {
  if (params == nullptr) {
    return false;
  }
  if (params->Get(name, value) == NVSDK_NGX_Result_Success) {
    return true;
  }
  int as_int = 0;
  if (params->Get(name, &as_int) != NVSDK_NGX_Result_Success) {
    return false;
  }
  *value = static_cast<unsigned int>(as_int);
  return true;
}

struct CreateValue {
  const char* name;
  unsigned int value;
};

// Creation parameters copied from the game's SuperSampling feature, so our replacement is created the same way.
constexpr const char* SAVED_CREATE_NAMES[] = {
    NVSDK_NGX_Parameter_Width,
    NVSDK_NGX_Parameter_Height,
    NVSDK_NGX_Parameter_OutWidth,
    NVSDK_NGX_Parameter_OutHeight,
    NVSDK_NGX_Parameter_PerfQualityValue,
    NVSDK_NGX_Parameter_DLSS_Feature_Create_Flags,
    NVSDK_NGX_Parameter_DLSS_Enable_Output_Subrects,
};

using AllocateParametersFn = NVSDK_NGX_Result(NVSDK_CONV*)(NVSDK_NGX_Parameter**);
using DestroyParametersFn = NVSDK_NGX_Result(NVSDK_CONV*)(NVSDK_NGX_Parameter*);
static AllocateParametersFn allocate_parameters = nullptr;
static DestroyParametersFn destroy_parameters = nullptr;

// All fields are guarded by mutex.
struct SuperSamplingSwitch {
  std::shared_mutex mutex;
  NVSDK_NGX_Handle* game_handle = nullptr;
  unsigned int game_preset = 0u;
  std::vector<CreateValue> game_values;
  NVSDK_NGX_Handle* our_handle = nullptr;
  unsigned int our_preset = 0u;
  bool our_attempted = false;
  bool reset_pending = false;
  NVSDK_NGX_Handle* rr_handle = nullptr;
  NVSDK_NGX_Parameter* rr_eval_params = nullptr;
  bool rr_failed = false;
  bool rr_first_eval_logged = false;
  bool rr_failure_logged = false;
  // Owned here so the matrix pointers stay valid through the evaluate call.
  std::array<float, 16> rr_world_to_view = {};
  std::array<float, 16> rr_view_to_clip = {};
  struct PendingRelease {
    NVSDK_NGX_Handle* handle;
    uint32_t presents_left;
  };
  std::vector<PendingRelease> pending_releases;
};
static SuperSamplingSwitch ss_switch;

// Queues a feature for release after a few presents, since the GPU may still be using it. Caller holds ss_switch.mutex.
inline void DeferRelease(NVSDK_NGX_Handle* handle) {
  ss_switch.pending_releases.push_back({.handle = handle, .presents_left = rr_guides::RETIRE_PRESENT_COUNT});
}

// Releases our SuperSampling feature, if any. Caller holds ss_switch.mutex.
inline void ReleaseOwnFeature() {
  if (ss_switch.our_handle != nullptr) {
    DeferRelease(ss_switch.our_handle);
  }
  ss_switch.our_handle = nullptr;
  ss_switch.our_attempted = false;
  ss_switch.reset_pending = false;
}

// Releases our Ray Reconstruction feature and eval block. Caller holds ss_switch.mutex.
inline void ReleaseRayReconstruction(const char* reason, const std::string& detail = {}) {
  if (ss_switch.rr_handle != nullptr) {
    std::ostringstream text;
    text << "GotG NGX: RR release reason=" << reason << detail;
    reshade::log::message(reshade::log::level::info, text.str().c_str());
    DeferRelease(ss_switch.rr_handle);
  }
  if (ss_switch.rr_eval_params != nullptr && destroy_parameters != nullptr) {
    destroy_parameters(ss_switch.rr_eval_params);
  }
  ss_switch.rr_handle = nullptr;
  ss_switch.rr_eval_params = nullptr;
}

// Creates a feature from the game's saved create values plus the settings for that model: the RR settings for Ray
// Reconstruction, or ss_preset for SuperSampling. Caller holds ss_switch.mutex.
inline NVSDK_NGX_Result CreateOwnFeature(ID3D12GraphicsCommandList* cmd_list, NVSDK_NGX_Feature feature,
                                         unsigned int ss_preset, NVSDK_NGX_Handle** created) {
  if (allocate_parameters == nullptr || real_create_feature == nullptr) {
    return NVSDK_NGX_Result_Fail;
  }
  NVSDK_NGX_Parameter* params = nullptr;
  auto result = allocate_parameters(&params);
  if (result != NVSDK_NGX_Result_Success) {
    return result;
  }
  for (const auto& value : ss_switch.game_values) {
    params->Set(value.name, value.value);
  }
  if (feature == NVSDK_NGX_Feature_RayReconstruction) {
    params->Set(NVSDK_NGX_Parameter_DLSS_Denoise_Mode, static_cast<int>(NVSDK_NGX_DLSS_Denoise_Mode_DLUnified));
    params->Set(NVSDK_NGX_Parameter_DLSS_Roughness_Mode, static_cast<unsigned int>(NVSDK_NGX_DLSS_Roughness_Mode_Packed));
    params->Set(NVSDK_NGX_Parameter_Use_HW_Depth, 1u);
    ApplyRayReconstructionPreset(params);
  } else {
    ApplySuperSamplingPreset(params, ss_preset);
  }
  result = real_create_feature(cmd_list, feature, params, created);
  if (destroy_parameters != nullptr) {
    destroy_parameters(params);
  }
  return result;
}

// Counts RR evaluate attempts since the last OnPresent. Zero at present means no RR evaluate ran this frame.
static std::atomic<uint32_t> evaluates_since_present = 0u;

struct EvaluateRoute {
  const NVSDK_NGX_Handle* handle = nullptr;
  bool reset_pulse = false;
  unsigned int previous_reset = 0u;
};

// Picks the handle an EvaluateFeature call runs with. When the setting differs from the game's preset, creates our own
// feature with that preset and evaluates with it instead.
inline EvaluateRoute RouteEvaluate(ID3D12GraphicsCommandList* cmd_list, const NVSDK_NGX_Handle* handle,
                                   const NVSDK_NGX_Parameter* params) {
  EvaluateRoute route = {.handle = handle};
  std::unique_lock lock(ss_switch.mutex);
  if (handle == nullptr || handle != ss_switch.game_handle) {
    return route;
  }

  const unsigned int desired = MappedSuperSamplingPreset();
  if (desired == ss_switch.game_preset) {
    ReleaseOwnFeature();
    return route;
  }

  if (!ss_switch.our_attempted || ss_switch.our_preset != desired) {
    ReleaseOwnFeature();
    ss_switch.our_attempted = true;
    ss_switch.our_preset = desired;
    NVSDK_NGX_Handle* created = nullptr;
    const auto result = CreateOwnFeature(cmd_list, NVSDK_NGX_Feature_SuperSampling, desired, &created);
    if (result == NVSDK_NGX_Result_Success && created != nullptr) {
      ss_switch.our_handle = created;
      ss_switch.reset_pending = true;
    }
    std::ostringstream text;
    text << "GotG NGX: preset switch preset=" << desired << " result=" << result << " handle=" << HandleId(created);
    reshade::log::message(reshade::log::level::info, text.str().c_str());
  }

  if (ss_switch.our_handle == nullptr) {
    return route;
  }
  route.handle = ss_switch.our_handle;
  if (ss_switch.reset_pending && params != nullptr) {
    ss_switch.reset_pending = false;
    route.reset_pulse = true;
    ReadUInt(params, NVSDK_NGX_Parameter_Reset, &route.previous_reset);
    const_cast<NVSDK_NGX_Parameter*>(params)->Set(NVSDK_NGX_Parameter_Reset, 1u);
  }
  return route;
}

// Restores the Reset value that RouteEvaluate pulsed. Runs after the evaluate call returns.
inline void FinishEvaluate(const EvaluateRoute& route, const NVSDK_NGX_Parameter* params) {
  if (route.reset_pulse) {
    const_cast<NVSDK_NGX_Parameter*>(params)->Set(NVSDK_NGX_Parameter_Reset, route.previous_reset);
  }
}

// Returns the saved creation value for name, or 0 when the game did not set it. Caller holds ss_switch.mutex.
inline unsigned int SavedCreateValue(const char* name) {
  for (const auto& value : ss_switch.game_values) {
    if (std::strcmp(value.name, name) == 0) {
      return value.value;
    }
  }
  return 0u;
}

inline void CopyFloat(const NVSDK_NGX_Parameter* from, NVSDK_NGX_Parameter* to, const char* name) {
  float value = 0.f;
  if (from->Get(name, &value) == NVSDK_NGX_Result_Success) {
    to->Set(name, value);
  }
}

inline void CopyUInt(const NVSDK_NGX_Parameter* from, NVSDK_NGX_Parameter* to, const char* name) {
  unsigned int value = 0u;
  if (ReadUInt(from, name, &value)) {
    to->Set(name, value);
  }
}

inline void CopyResource(const NVSDK_NGX_Parameter* from, NVSDK_NGX_Parameter* to, const char* name) {
  ID3D12Resource* resource = nullptr;
  if (from->Get(name, &resource) == NVSDK_NGX_Result_Success && resource != nullptr) {
    to->Set(name, resource);
  }
}

// Runs DLSS Ray Reconstruction in place of the game's SR evaluate. Returns false when the SR path should run this frame.
inline bool TryEvaluateRayReconstruction(ID3D12GraphicsCommandList* cmd_list, const NVSDK_NGX_Handle* handle,
                                         const NVSDK_NGX_Parameter* params) {
  evaluates_since_present.fetch_add(1u, std::memory_order_relaxed);
  std::unique_lock lock(ss_switch.mutex);
  if (handle == nullptr || handle != ss_switch.game_handle || params == nullptr) {
    rr_guides::rr_active.store(false);
    return false;
  }
  if (rr_guides::rr_enable == 0.f) {
    ReleaseRayReconstruction("ray reconstruction disabled");
    ss_switch.rr_failed = false;
    rr_guides::rr_active.store(false);
    return false;
  }

  std::optional<rr_guides::LatestGuides> guides = rr_guides::GetGuidesForCommandList(reinterpret_cast<uint64_t>(cmd_list));
  if (!guides.has_value()) {
    guides = rr_guides::GetLatestGuides();
    if (!guides.has_value() || guides->frame_index + 1u < rr_guides::CurrentFrameIndex()) {
      rr_guides::rr_active.store(false);
      return false;
    }
  }
  if (guides->width != SavedCreateValue(NVSDK_NGX_Parameter_Width)
      || guides->height != SavedCreateValue(NVSDK_NGX_Parameter_Height)) {
    std::ostringstream detail;
    detail << " guide=" << guides->width << "x" << guides->height
           << " dlss=" << SavedCreateValue(NVSDK_NGX_Parameter_Width) << "x" << SavedCreateValue(NVSDK_NGX_Parameter_Height);
    ReleaseRayReconstruction("guide size mismatch", detail.str());
    rr_guides::rr_active.store(false);
    return false;
  }

  if (ss_switch.rr_handle == nullptr && !ss_switch.rr_failed) {
    NVSDK_NGX_Handle* created = nullptr;
    const auto result = CreateOwnFeature(cmd_list, NVSDK_NGX_Feature_RayReconstruction, 0u, &created);
    if (result == NVSDK_NGX_Result_Success && created != nullptr) {
      ss_switch.rr_handle = created;
    } else {
      ss_switch.rr_failed = true;
    }
    std::ostringstream text;
    text << "GotG NGX: RR create result=" << result << " handle=" << HandleId(created);
    reshade::log::message(reshade::log::level::info, text.str().c_str());
  }
  if (ss_switch.rr_handle == nullptr) {
    rr_guides::rr_active.store(false);
    return false;
  }

  if (ss_switch.rr_eval_params == nullptr && allocate_parameters != nullptr) {
    allocate_parameters(&ss_switch.rr_eval_params);
  }
  if (ss_switch.rr_eval_params == nullptr) {
    rr_guides::rr_active.store(false);
    return false;
  }
  auto* eval = ss_switch.rr_eval_params;
  CopyResource(params, eval, NVSDK_NGX_Parameter_Color);
  CopyResource(params, eval, NVSDK_NGX_Parameter_Output);
  CopyResource(params, eval, NVSDK_NGX_Parameter_Depth);
  CopyResource(params, eval, NVSDK_NGX_Parameter_MotionVectors);
  CopyFloat(params, eval, NVSDK_NGX_Parameter_Jitter_Offset_X);
  CopyFloat(params, eval, NVSDK_NGX_Parameter_Jitter_Offset_Y);
  CopyFloat(params, eval, NVSDK_NGX_Parameter_MV_Scale_X);
  CopyFloat(params, eval, NVSDK_NGX_Parameter_MV_Scale_Y);
  CopyUInt(params, eval, NVSDK_NGX_Parameter_Reset);
  CopyUInt(params, eval, NVSDK_NGX_Parameter_DLSS_Render_Subrect_Dimensions_Width);
  CopyUInt(params, eval, NVSDK_NGX_Parameter_DLSS_Render_Subrect_Dimensions_Height);
  CopyFloat(params, eval, NVSDK_NGX_Parameter_DLSS_Pre_Exposure);
  CopyFloat(params, eval, NVSDK_NGX_Parameter_DLSS_Exposure_Scale);
  eval->Set(NVSDK_NGX_Parameter_DiffuseAlbedo, reinterpret_cast<ID3D12Resource*>(guides->diffuse_albedo.handle));
  eval->Set(NVSDK_NGX_Parameter_SpecularAlbedo, reinterpret_cast<ID3D12Resource*>(guides->specular_albedo.handle));
  eval->Set(NVSDK_NGX_Parameter_GBuffer_Normals, reinterpret_cast<ID3D12Resource*>(guides->normal_roughness.handle));
  if (guides->specular_hit_distance.handle != 0u && guides->has_matrices) {
    ss_switch.rr_world_to_view = guides->world_to_view;
    ss_switch.rr_view_to_clip = guides->view_to_clip;
    eval->Set(NVSDK_NGX_Parameter_DLSSD_SpecularHitDistance, reinterpret_cast<ID3D12Resource*>(guides->specular_hit_distance.handle));
    eval->Set(NVSDK_NGX_Parameter_DLSS_WORLD_TO_VIEW_MATRIX, static_cast<void*>(ss_switch.rr_world_to_view.data()));
    eval->Set(NVSDK_NGX_Parameter_DLSS_VIEW_TO_CLIP_MATRIX, static_cast<void*>(ss_switch.rr_view_to_clip.data()));
  } else {
    eval->Set(NVSDK_NGX_Parameter_DLSSD_SpecularHitDistance, static_cast<ID3D12Resource*>(nullptr));
    eval->Set(NVSDK_NGX_Parameter_DLSS_WORLD_TO_VIEW_MATRIX, static_cast<void*>(nullptr));
    eval->Set(NVSDK_NGX_Parameter_DLSS_VIEW_TO_CLIP_MATRIX, static_cast<void*>(nullptr));
  }

  if (real_evaluate_feature == nullptr) {
    rr_guides::rr_active.store(false);
    return false;
  }
  const auto eval_result = real_evaluate_feature(cmd_list, ss_switch.rr_handle, eval, nullptr);
  rr_guides::rr_active.store(eval_result == NVSDK_NGX_Result_Success);
  if (!ss_switch.rr_first_eval_logged) {
    ss_switch.rr_first_eval_logged = true;
    std::ostringstream text;
    text << "GotG NGX: RR first evaluate result=" << eval_result;
    reshade::log::message(reshade::log::level::info, text.str().c_str());
  }
  if (eval_result != NVSDK_NGX_Result_Success && !ss_switch.rr_failure_logged) {
    ss_switch.rr_failure_logged = true;
    std::ostringstream text;
    text << "GotG NGX: RR evaluate failed result=" << eval_result << ", using SR for this frame";
    reshade::log::message(reshade::log::level::info, text.str().c_str());
  }
  return eval_result == NVSDK_NGX_Result_Success;
}

inline NVSDK_NGX_Result NVSDK_CONV HookedCreateFeature(ID3D12GraphicsCommandList* cmd_list, NVSDK_NGX_Feature feature_id,
                                                       const NVSDK_NGX_Parameter* params, NVSDK_NGX_Handle** out_handle) {
  unsigned int applied_preset = 0u;
  if (feature_id == NVSDK_NGX_Feature_SuperSampling && params != nullptr) {
    applied_preset = MappedSuperSamplingPreset();
    ApplySuperSamplingPreset(const_cast<NVSDK_NGX_Parameter*>(params), applied_preset);
  }
  if (feature_id == NVSDK_NGX_Feature_RayReconstruction && params != nullptr) {
    ApplyRayReconstructionPreset(const_cast<NVSDK_NGX_Parameter*>(params));
  }

  const auto result = real_create_feature(cmd_list, feature_id, params, out_handle);
  if (feature_id == NVSDK_NGX_Feature_SuperSampling && result == NVSDK_NGX_Result_Success && out_handle != nullptr
      && *out_handle != nullptr) {
    std::vector<CreateValue> values;
    for (const char* name : SAVED_CREATE_NAMES) {
      unsigned int value = 0u;
      if (ReadUInt(params, name, &value)) {
        values.push_back({name, value});
      }
    }
    std::unique_lock lock(ss_switch.mutex);
    ReleaseOwnFeature();
    ReleaseRayReconstruction("game created a new DLSS feature");
    ss_switch.rr_failed = false;
    ss_switch.game_handle = *out_handle;
    ss_switch.game_preset = applied_preset;
    ss_switch.game_values = std::move(values);
  }
  return result;
}

inline NVSDK_NGX_Result NVSDK_CONV HookedEvaluateFeature(ID3D12GraphicsCommandList* cmd_list, const NVSDK_NGX_Handle* handle,
                                                         const NVSDK_NGX_Parameter* params, PFN_NVSDK_NGX_ProgressCallback callback) {
  if (TryEvaluateRayReconstruction(cmd_list, handle, params)) {
    return NVSDK_NGX_Result_Success;
  }
  const auto route = RouteEvaluate(cmd_list, handle, params);
  const auto result = real_evaluate_feature(cmd_list, route.handle, params, callback);
  FinishEvaluate(route, params);
  return result;
}

inline NVSDK_NGX_Result NVSDK_CONV HookedEvaluateFeatureC(ID3D12GraphicsCommandList* cmd_list, const NVSDK_NGX_Handle* handle,
                                                          const NVSDK_NGX_Parameter* params, PFN_NVSDK_NGX_ProgressCallback_C callback) {
  if (TryEvaluateRayReconstruction(cmd_list, handle, params)) {
    return NVSDK_NGX_Result_Success;
  }
  const auto route = RouteEvaluate(cmd_list, handle, params);
  const auto result = real_evaluate_feature_c(cmd_list, route.handle, params, callback);
  FinishEvaluate(route, params);
  return result;
}

inline NVSDK_NGX_Result NVSDK_CONV HookedReleaseFeature(NVSDK_NGX_Handle* handle) {
  {
    std::unique_lock lock(ss_switch.mutex);
    if (handle != nullptr && handle == ss_switch.game_handle) {
      ReleaseOwnFeature();
      ReleaseRayReconstruction("game released its DLSS feature");
      ss_switch.game_handle = nullptr;
      ss_switch.game_preset = 0u;
      ss_switch.game_values.clear();
    }
  }
  const auto result = real_release_feature(handle);
  std::ostringstream text;
  text << "GotG NGX: ReleaseFeature handle=" << HandleId(handle) << " result=" << result;
  reshade::log::message(reshade::log::level::info, text.str().c_str());
  return result;
}

static const renodx::utils::detour::Export EXPORTS[] = {
    {"NVSDK_NGX_D3D12_CreateFeature", &real_create_feature, &HookedCreateFeature},
    {"NVSDK_NGX_D3D12_EvaluateFeature", &real_evaluate_feature, &HookedEvaluateFeature},
    {"NVSDK_NGX_D3D12_EvaluateFeature_C", &real_evaluate_feature_c, &HookedEvaluateFeatureC},
    {"NVSDK_NGX_D3D12_ReleaseFeature", &real_release_feature, &HookedReleaseFeature},
};

// Call from the addon's present callback. Ages deferred releases every present, and installs the detours once the driver
// module is loaded.
inline void OnPresent() {
  if (evaluates_since_present.exchange(0u) == 0u) {
    rr_guides::rr_active.store(false);
  }
  {
    std::unique_lock lock(ss_switch.mutex);
    for (auto it = ss_switch.pending_releases.begin(); it != ss_switch.pending_releases.end();) {
      --it->presents_left;
      if (it->presents_left == 0u) {
        if (real_release_feature != nullptr) {
          real_release_feature(it->handle);
        }
        it = ss_switch.pending_releases.erase(it);
      } else {
        ++it;
      }
    }
  }

  static bool installed = false;
  if (installed) return;
  const HMODULE driver = GetModuleHandleW(L"_nvngx.dll");
  if (driver == nullptr) return;
  installed = true;
  allocate_parameters = reinterpret_cast<AllocateParametersFn>(GetProcAddress(driver, "NVSDK_NGX_D3D12_AllocateParameters"));
  destroy_parameters = reinterpret_cast<DestroyParametersFn>(GetProcAddress(driver, "NVSDK_NGX_D3D12_DestroyParameters"));
  try {
    const auto install = renodx::utils::detour::Install(driver, EXPORTS);
    std::ostringstream text;
    text << "GotG NGX: detour install requested=" << install.requested << " installed=" << install.installed
         << " already=" << install.already_installed << " missing=" << install.missing << " failed=" << install.failed
         << " error=" << install.error.value();
    reshade::log::message(reshade::log::level::info, text.str().c_str());
  } catch (const std::exception& error) {
    reshade::log::message(reshade::log::level::error,
                          (std::string("GotG NGX: detour install threw: ") + error.what()).c_str());
  }
}

}  // namespace ngx_hooks
