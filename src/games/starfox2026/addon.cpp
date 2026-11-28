/*
 * Copyright (C) 2026 Carlos Lopez
 * SPDX-License-Identifier: MIT
 */

// Scaffold for RenoDX Star Fox (Switch 2) running on the Lichii emulator.

#define ImTextureID ImU64

#include <dxgi1_6.h>
#include <wrl/client.h>

#include <span>
#include <string>

#include <deps/imgui/imgui.h>
#include <embed/shaders.h>
#include <include/reshade.hpp>

#include "../../mods/shader.hpp"
#include "../../utils/settings.hpp"
#include "./shared.h"

#pragma comment(lib, "dxgi.lib")

namespace {

ShaderInjectData shader_injection = {};

renodx::mods::shader::CustomShaders custom_shaders = {
    CustomShaderEntry(0x0F04EB4E),  // AA/present: alpha 0 so UI blending leaves coverage in alpha
    CustomShaderEntry(0x5B009ED7),  // HDR output: scene+UI -> 64^3 display LUT -> PQ
    CustomShaderEntry(0x3E4948A6),  // Scene composite: clamp RT0 >= 0 (RGBA16F compositor IPS)
};

bool IsPsychoVEnabled() {
  return shader_injection.tone_map_type == RENODX_TONE_MAP_TYPE_PSYCHOV35;
}

bool IsReferenceEnabled() {
  return IsPsychoVEnabled() && shader_injection.color_reference != RENODX_COLOR_REFERENCE_PSYCHOV35;
}

renodx::utils::settings::Settings settings = {
    new renodx::utils::settings::Setting{
        .key = "ToneMapType",
        .binding = &shader_injection.tone_map_type,
        .value_type = renodx::utils::settings::SettingValueType::INTEGER,
        .default_value = 1.f,
        .label = "Tonemapper",
        .section = "Output",
        .labels = {"Vanilla", "PsychoV35"},
        .parse = [](float value) {
          if (value == 1.f) return RENODX_TONE_MAP_TYPE_PSYCHOV35;
          return RENODX_TONE_MAP_TYPE_VANILLA;
        },
    },
    new renodx::utils::settings::Setting{
        .key = "ToneMapPeakNits",
        .binding = &shader_injection.peak_white_nits,
        .default_value = 1000.f,
        .can_reset = true,
        .label = "Peak Brightness",
        .section = "Output",
        .min = 48.f,
        .max = 4000.f,
        .is_enabled = &IsPsychoVEnabled,
    },
    new renodx::utils::settings::Setting{
        .key = "ToneMapGameNits",
        .binding = &shader_injection.diffuse_white_nits,
        .default_value = 203.f,
        .label = "Game Brightness",
        .section = "Output",
        .min = 48.f,
        .max = 500.f,
        .is_enabled = &IsPsychoVEnabled,
    },
    new renodx::utils::settings::Setting{
        .key = "ToneMapUINits",
        .binding = &shader_injection.ui_nits,
        .default_value = 310.f,
        .label = "UI Brightness",
        .section = "Output",
        .min = 48.f,
        .max = 500.f,
        .is_enabled = &IsPsychoVEnabled,
    },
    new renodx::utils::settings::Setting{
        .key = "ColorReference",
        .binding = &shader_injection.color_reference,
        .value_type = renodx::utils::settings::SettingValueType::INTEGER,
        .default_value = RENODX_COLOR_REFERENCE_GAME_HDR,
        .label = "Colour Reference",
        .section = "Colour",
        .tooltip = "Source of hue and chroma. Brightness always comes from PsychoV35. Game SDR is the game's SDR colour, fading to Game HDR in highlights.",
        .labels = {"PsychoV35", "Game HDR", "Game SDR"},
        .is_enabled = &IsPsychoVEnabled,
    },
    new renodx::utils::settings::Setting{
        .key = "HueStrength",
        .binding = &shader_injection.hue_strength,
        .default_value = 100.f,
        .label = "Hue Strength",
        .section = "Colour",
        .tooltip = "How much of the reference's hue is used.",
        .min = 0.f,
        .max = 100.f,
        .is_enabled = &IsReferenceEnabled,
    },
    new renodx::utils::settings::Setting{
        .key = "ChromaStrength",
        .binding = &shader_injection.chroma_strength,
        .default_value = 100.f,
        .label = "Chroma Strength",
        .section = "Colour",
        .tooltip = "How much of the reference's saturation (relative to its lightness) is used.",
        .min = 0.f,
        .max = 100.f,
        .is_enabled = &IsReferenceEnabled,
    },
    new renodx::utils::settings::Setting{
        .value_type = renodx::utils::settings::SettingValueType::BUTTON,
        .label = "Reset All",
        .section = "Options",
        .on_change = []() { renodx::utils::settings::ResetSettings(); },
    },
};

bool addon_registered = false;
bool peak_detected = false;

// Windows-reported peak of the monitor under the swapchain window; the shared helper is DXGI-swapchain-only.
float DetectDisplayPeakNits(HWND hwnd) {
  constexpr float kFallback = 1000.f;
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  Microsoft::WRL::ComPtr<IDXGIFactory1> factory;
  if (monitor == nullptr || FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) return kFallback;

  Microsoft::WRL::ComPtr<IDXGIAdapter> adapter;
  for (UINT a = 0; factory->EnumAdapters(a, &adapter) != DXGI_ERROR_NOT_FOUND; ++a) {
    Microsoft::WRL::ComPtr<IDXGIOutput> output;
    for (UINT o = 0; adapter->EnumOutputs(o, &output) != DXGI_ERROR_NOT_FOUND; ++o) {
      DXGI_OUTPUT_DESC desc = {};
      Microsoft::WRL::ComPtr<IDXGIOutput6> output6;
      if (SUCCEEDED(output->GetDesc(&desc)) && desc.Monitor == monitor && SUCCEEDED(output.As(&output6))) {
        DXGI_OUTPUT_DESC1 desc1 = {};
        if (SUCCEEDED(output6->GetDesc1(&desc1)) && desc1.MaxLuminance > 0.f) return desc1.MaxLuminance;
      }
    }
  }
  return kFallback;
}

void OnInitSwapchain(reshade::api::swapchain* swapchain, bool resize) {
  if (peak_detected) return;
  float peak = DetectDisplayPeakNits(static_cast<HWND>(swapchain->get_hwnd()));
  settings[1]->default_value = peak;
  peak_detected = true;
  reshade::log::message(reshade::log::level::info, ("Star Fox: detected display peak " + std::to_string(peak) + " nits").c_str());
}

// Tell ReShade effects the Vulkan HDR output is HDR10 (PQ) so BUFFER_COLOR_SPACE matches the swapchain.
void OnInitEffectRuntime(reshade::api::effect_runtime* runtime) {
  auto* device = runtime->get_device();
  if (device->get_api() != reshade::api::device_api::vulkan) return;

  const auto back_buffer_format = device->get_resource_desc(runtime->get_current_back_buffer()).texture.format;
  if (back_buffer_format != reshade::api::format::r10g10b10a2_unorm
      && back_buffer_format != reshade::api::format::r10g10b10a2_typeless) {
    return;
  }

  runtime->set_color_space(reshade::api::color_space::hdr10_st2084);
  reshade::log::message(reshade::log::level::info, "Star Fox: effect runtime colour space set to HDR10");
}

}  // namespace

extern "C" __declspec(dllexport) constexpr const char* NAME = "RenoDX";
extern "C" __declspec(dllexport) constexpr const char* DESCRIPTION = "RenoDX for Star Fox (Switch 2) on Lichii";

BOOL APIENTRY DllMain(HMODULE h_module, DWORD reason, [[maybe_unused]] LPVOID reserved) {
  switch (reason) {
    case DLL_PROCESS_ATTACH: {
      if (!reshade::register_addon(h_module)) return FALSE;
      addon_registered = true;

      // Vulkan only. Target: Star Fox title 0400E88025B1A000, v2.0.0,
      // main build ID A7730D0F74D168D90422354C8317F76FF78AD938.
      // Default scheduling queues compile-time replacements plus a runtime fallback, so the
      // shaders also apply under the DevKit, which turns compile-time replacement off.
      // Injected constants at space 1 / slot 4; the native shader only uses set 0.
      custom_shaders.at(0x5B009ED7u).views.push_back({
          .type = reshade::api::descriptor_type::constant_buffer,
          .slot = 4u,
          .space = 1u,
          .get_constants = []() -> std::span<const float> {
            return {reinterpret_cast<const float*>(&shader_injection), sizeof(shader_injection) / sizeof(float)};
          },
      });
      renodx::utils::settings::Use(reason, &settings);
      renodx::mods::shader::Use(reason, custom_shaders);
      reshade::register_event<reshade::addon_event::init_swapchain>(OnInitSwapchain);
      reshade::register_event<reshade::addon_event::init_effect_runtime>(OnInitEffectRuntime);
      break;
    }
    case DLL_PROCESS_DETACH:
      if (addon_registered) {
        renodx::mods::shader::Use(reason, custom_shaders);
        renodx::utils::settings::Use(reason, &settings);
        reshade::unregister_event<reshade::addon_event::init_swapchain>(OnInitSwapchain);
        reshade::unregister_event<reshade::addon_event::init_effect_runtime>(OnInitEffectRuntime);
        reshade::unregister_addon(h_module);
      }
      break;
  }
  return TRUE;
}
