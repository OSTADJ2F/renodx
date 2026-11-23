/*
 * Copyright (C) 2024 Carlos Lopez
 * SPDX-License-Identifier: MIT
 */

#define ImTextureID ImU64

#define DEBUG_LEVEL_0

#include <atomic>
#include <cmath>
#include <cstdint>
#include <shared_mutex>
#include <span>
#include <sstream>
#include <string>
#include <unordered_set>
#include <vector>

#include <deps/imgui/imgui.h>
#include <include/reshade.hpp>

#include <embed/shaders.h>

#include "../../mods/shader.hpp"
#include "../../utils/descriptor.hpp"
#include "../../utils/platform.hpp"
#include "../../utils/resource.hpp"
#include "../../utils/settings.hpp"
#include "../../utils/shader.hpp"
#include "../../utils/state.hpp"
#include "../../utils/swapchain.hpp"
#include "./shared.h"
#include "./ngx_hooks.hpp"
#include "./rr_guides.hpp"
#include "./rt_multiray.hpp"
#include "./rt_noise.hpp"
#include "./rt_trace.hpp"
#include "./ui.hpp"

namespace {

renodx::mods::shader::CustomShaders custom_shaders = {__ALL_CUSTOM_SHADERS};

ShaderInjectData shader_injection;

// Gates the six NRD replacements. Off runs the game's original denoiser shaders,
// except while Full-Res Tracing or Ray Reconstruction need the replacements' checkerboard/passthrough paths.
float nrd_override = 0.f;

// Presents since the last full-res trace dispatch. Frames are recorded on several threads, so the
// denoiser flag stays on for a few presents instead of following each present exactly.
uint32_t presents_since_full_res = 8u;

// Denoiser setting; OnPresent also forces passthrough while Ray Reconstruction is active.
float nrd_passthrough_setting = 0.f;

namespace ui = guardians_ui;
namespace settings_ui = renodx::utils::settings;

// Section titles, in panel order.
constexpr const char* STATUS_SECTION = "Status";
constexpr const char* TONE_MAPPING_SECTION = "Tone Mapping";
constexpr const char* COLOR_GRADING_SECTION = "Color Grading";
constexpr const char* EFFECTS_SECTION = "Effects";
constexpr const char* DLSS_SECTION = "DLSS";
constexpr const char* RAY_TRACING_SECTION = "Ray Tracing";
constexpr const char* DENOISER_SECTION = "Denoiser";
constexpr const char* ABOUT_SECTION = "About";

// The six NRD replacements run while the override is on or Full-Res Tracing forces them, and never under Ray Reconstruction.
bool NrdReplacementsActive() {
  return (nrd_override != 0.f || rt_trace::full_res_setting != 0.f) && !rr_guides::rr_active.load();
}

// NRD tuning sliders only take effect when the denoiser runs and passthrough is off.
bool NrdTuningActive() {
  return NrdReplacementsActive() && nrd_passthrough_setting == 0.f;
}

settings_ui::Settings settings = {
    // Status
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::CUSTOM,
        .label = "Status",
        .section = STATUS_SECTION,
        .tint = ui::TINT_VIOLET,
        .on_draw = []() {
          struct Item {
            const char* text;
            bool active;
          };
          const bool hdr_active = shader_injection.hdr_output != 0.f;
          const bool psychov_active = shader_injection.tone_map_type != 0.f;
          const bool full_res_active = shader_injection.rt_full_res != 0.f;
          const bool rr_on = rr_guides::rr_active.load();
          const Item items[] = {
              {hdr_active ? "HDR10" : "SDR", hdr_active},
              {psychov_active ? "PsychoV" : "Vanilla", psychov_active},
              {full_res_active ? "Full-Res RT" : "Checkerboard RT", full_res_active},
              {rr_on ? "Ray Reconstruction" : "RR Off", rr_on},
          };
          const float font_size = ImGui::GetFontSize();
          const float dot_radius = font_size * 0.2f;
          const float dot_gap = font_size * 0.4f;
          const float item_gap = font_size * 0.9f;
          const float line_height = ImGui::GetTextLineHeight();
          bool first = true;
          for (const auto& [text, active] : items) {
            if (!first) {
              ImGui::SameLine(0.f, item_gap);
            }
            first = false;
            const ImVec2 origin = ImGui::GetCursorScreenPos();
            ImGui::GetWindowDrawList()->AddCircleFilled(
                {origin.x + dot_radius, origin.y + (line_height * 0.5f)}, dot_radius,
                active ? ui::NEBULA_GLOW : ui::WithAlpha(ui::OFF_WHITE, 0.35f), 12);
            ImGui::Dummy({(dot_radius * 2.f) + dot_gap, line_height});
            ImGui::SameLine(0.f, 0.f);
            ImGui::PushStyleColor(ImGuiCol_Text, active ? ui::OFF_WHITE : ui::WithAlpha(ui::OFF_WHITE, 0.5f));
            ImGui::TextUnformatted(text);
            ImGui::PopStyleColor();
          }
          return false;
        },
        .is_sticky = true,
    },
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::BUTTON,
        .label = "Reset All",
        .section = STATUS_SECTION,
        .tooltip = "Restores every setting in this panel to its default value.",
        .tint = ui::TINT_VIOLET,
        .on_change = []() { settings_ui::ResetSettings(); },
    },
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::TEXT,
        .label = "RenoDX for Marvel's Guardians Of The Galaxy Made By Ostad Gaming",
        .section = STATUS_SECTION,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::CUSTOM,
        .label = "Ko-fi",
        .section = STATUS_SECTION,
        .on_draw = []() {
          constexpr ImU32 kofi_red = IM_COL32(255, 94, 91, 255);
          constexpr ImU32 kofi_red_hover = IM_COL32(255, 120, 117, 255);
          constexpr ImU32 kofi_white = IM_COL32_WHITE;
          constexpr const char* kofi_text = "Buy Ostad a coffee";

          const float height = ImGui::GetFrameHeight() * 1.4f;
          const bool clicked = ImGui::InvisibleButton("##kofi", ImVec2(ImGui::GetContentRegionAvail().x, height));
          const bool hovered = ImGui::IsItemHovered();
          if (hovered) {
            ImGui::SetTooltip("Opens ko-fi.com/ostadgaming");
          }

          const ImVec2 min = ImGui::GetItemRectMin();
          const ImVec2 max = ImGui::GetItemRectMax();
          ImDrawList* draw_list = ImGui::GetWindowDrawList();
          draw_list->AddRectFilled(min, max, hovered ? kofi_red_hover : kofi_red, height * 0.5f);

          // Logo: white cup with a ring handle on the right and a red heart inside the cup.
          const float logo_size = height * 0.5f;
          const float logo_gap = logo_size * 0.5f;
          const ImVec2 text_size = ImGui::CalcTextSize(kofi_text);
          const float content_width = logo_size + logo_gap + text_size.x;
          const float logo_x = min.x + ((max.x - min.x) - content_width) * 0.5f;
          const float center_y = (min.y + max.y) * 0.5f;

          const float cup_right = logo_x + logo_size * 0.75f;
          draw_list->AddRectFilled({logo_x, center_y - logo_size * 0.4f}, {cup_right, center_y + logo_size * 0.4f}, kofi_white,
                                   logo_size * 0.12f);
          draw_list->AddCircle({cup_right, center_y}, logo_size * 0.22f, kofi_white, 16, logo_size * 0.1f);
          const float heart_x = logo_x + logo_size * 0.375f;
          const float heart_y = center_y + logo_size * 0.02f;
          draw_list->AddCircleFilled({heart_x - logo_size * 0.09f, heart_y - logo_size * 0.05f}, logo_size * 0.1f, kofi_red, 12);
          draw_list->AddCircleFilled({heart_x + logo_size * 0.09f, heart_y - logo_size * 0.05f}, logo_size * 0.1f, kofi_red, 12);
          draw_list->AddTriangleFilled({heart_x - logo_size * 0.18f, heart_y - logo_size * 0.01f},
                                       {heart_x + logo_size * 0.18f, heart_y - logo_size * 0.01f}, {heart_x, heart_y + logo_size * 0.18f},
                                       kofi_red);

          const ImVec2 text_pos = {logo_x + logo_size + logo_gap, center_y - text_size.y * 0.5f};
          draw_list->AddText(text_pos, kofi_white, kofi_text);

          if (clicked) {
            renodx::utils::platform::LaunchURL("https://ko-fi.com/ostadgaming");
          }
          return false;
        },
    },

    // Tone Mapping
    new settings_ui::Setting{
        .key = "ToneMapType",
        .binding = &shader_injection.tone_map_type,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 1.f,
        .label = "Tone Mapper",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Vanilla keeps the game's own tone mapping. PsychoV renders HDR up to your peak brightness and unlocks "
                   "the options below. Default: PsychoV. No performance cost.",
        .labels = {"Vanilla", "PsychoV"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .key = "ToneMapPeakNits",
        .binding = &shader_injection.peak_white_nits,
        .default_value = 1000.f,
        .label = "Peak Brightness",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Peak white in nits. Defaults to the display peak reported by Windows.",
        .tint = ui::TINT_VIOLET,
        .min = 80.f,
        .max = 4000.f,
        .format = "%.0f nits",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
    },
    new settings_ui::Setting{
        .key = "ToneMapGameNits",
        .binding = &shader_injection.diffuse_white_nits,
        .default_value = 203.f,
        .label = "Game Brightness",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Scene reference white in nits. ~56 matches vanilla mid-gray. Default: 203.",
        .tint = ui::TINT_VIOLET,
        .min = 80.f,
        .max = 500.f,
        .format = "%.0f nits",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
    },
    new settings_ui::Setting{
        .key = "ToneMapUINits",
        .binding = &shader_injection.graphics_white_nits,
        .default_value = 203.f,
        .label = "UI Brightness",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "UI and HUD white level in nits. Default: 203.",
        .tint = ui::TINT_VIOLET,
        .min = 80.f,
        .max = 500.f,
        .format = "%.0f nits",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
    },
    new settings_ui::Setting{
        .key = "GammaCorrection",
        .binding = &shader_injection.gamma_correction,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 1.f,
        .label = "UI Gamma",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Decodes the UI as gamma 2.2 instead of sRGB. Default: 2.2.",
        .labels = {"sRGB", "2.2"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
    },
    new settings_ui::Setting{
        .key = "ToneMapSDRColor",
        .binding = &shader_injection.tone_map_sdr_color,
        .default_value = 0.f,
        .label = "Vanilla Color Match",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "100% keeps the game's ACES colors, 0% uses PsychoV's own. Default: 0%. Needs PsychoV.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "ToneMapHueClip",
        .binding = &shader_injection.tone_map_hue_clip,
        .default_value = 0.f,
        .label = "Vanilla Hue Match",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Bends PsychoV's colors toward the game's per-channel hue clipping. Default: 0%. Needs PsychoV.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
        .parse = [](float value) { return value * 0.01f; },
    },

    // Color Grading
    new settings_ui::Setting{
        .key = "ColorGradeExposure",
        .binding = &shader_injection.tone_map_exposure,
        .default_value = 0.f,
        .label = "Exposure",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Scales overall scene brightness before tone mapping. 0 EV is neutral (default).",
        .tint = ui::TINT_VIOLET,
        .min = -3.f,
        .max = 3.f,
        .format = "%+.1f EV",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
        .parse = [](float value) { return std::exp2(value); },
    },
    new settings_ui::Setting{
        .key = "ColorGradeHighlights",
        .binding = &shader_injection.tone_map_highlights,
        .default_value = 100.f,
        .label = "Highlights",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Adjusts the brightest tones. 100% is neutral (default).",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 200.f,
        .format = "%.0f%%",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "ColorGradeShadows",
        .binding = &shader_injection.tone_map_shadows,
        .default_value = 100.f,
        .label = "Shadows",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Adjusts the darkest tones. 100% is neutral (default).",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 200.f,
        .format = "%.0f%%",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "ColorGradeContrast",
        .binding = &shader_injection.tone_map_contrast,
        .default_value = 100.f,
        .label = "Contrast",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Scales the tone curve slope. 100% keeps the vanilla-matched slope (default).",
        .tint = ui::TINT_VIOLET,
        .min = 50.f,
        .max = 200.f,
        .format = "%.0f%%",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "ColorGradeSaturation",
        .binding = &shader_injection.tone_map_saturation,
        .default_value = 100.f,
        .label = "Saturation",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Adjusts color intensity. 100% is neutral (default).",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 200.f,
        .format = "%.0f%%",
        .is_enabled = []() { return shader_injection.tone_map_type != 0; },
        .parse = [](float value) { return value * 0.01f; },
    },

    // Effects
    new settings_ui::Setting{
        .key = "Sharpness",
        .binding = &shader_injection.sharpness,
        .default_value = 50.f,
        .label = "Sharpening",
        .section = EFFECTS_SECTION,
        .tooltip = "Lilium's HDR RCAS sharpening, which replaces the game's FSR sharpening. 0 disables it. Default: 50. "
                   "Negligible performance cost.",
        .tint = ui::TINT_VIOLET,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "BloomStrength",
        .binding = &shader_injection.bloom_strength,
        .default_value = 100.f,
        .label = "Bloom",
        .section = EFFECTS_SECTION,
        .tooltip = "Scales the game's bloom. 0 disables it. Game default: 100%.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 200.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "BloomThreshold",
        .binding = &shader_injection.bloom_threshold,
        .default_value = 100.f,
        .label = "Bloom Threshold",
        .section = EFFECTS_SECTION,
        .tooltip = "Scales the brightness above which bloom starts. Game default: 100%. Needs Bloom above 0%.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 300.f,
        .format = "%.0f%%",
        .is_enabled = []() { return shader_injection.bloom_strength != 0.f; },
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "BloomSaturation",
        .binding = &shader_injection.bloom_saturation,
        .default_value = 100.f,
        .label = "Bloom Saturation",
        .section = EFFECTS_SECTION,
        .tooltip = "Scales the color saturation of the game's bloom. Game default: 100%. Needs Bloom above 0%.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .is_enabled = []() { return shader_injection.bloom_strength != 0.f; },
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "DOFUpscale",
        .binding = &shader_injection.dof_upscale,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 1.f,
        .label = "DoF Upscaling",
        .section = EFFECTS_SECTION,
        .tooltip = "Smooth uses a cubic B-spline to upscale the half-resolution blur, removing 2x2 stair-step edges. Vanilla is "
                   "the game's. Default: Smooth. Small performance cost.",
        .labels = {"Vanilla", "Smooth"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .key = "DOFDither",
        .binding = &shader_injection.dof_dither,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 1.f,
        .label = "DoF Dither",
        .section = EFFECTS_SECTION,
        .tooltip = "Dithers the blurred result before the game's 11-bit buffer to remove banding. Default: On. Negligible "
                   "performance cost.",
        .labels = {"Off", "On"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .key = "BokehMaxSamples",
        .binding = &shader_injection.bokeh_max_samples,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 32.f,
        .label = "Bokeh Quality",
        .section = EFFECTS_SECTION,
        .tooltip = "Maximum taps per hex direction. 5 is the game's original; higher fills gaps in large blurs but costs more "
                   "GPU time when the blur is large. Default: 32.",
        .tint = ui::TINT_VIOLET,
        .min = 5.f,
        .max = 32.f,
        .format = "%d samples",
    },
    new settings_ui::Setting{
        .key = "FogBlackPreservation",
        .binding = &shader_injection.fog_black_preservation,
        .default_value = 10.f,
        .label = "Fog Black Preservation",
        .section = EFFECTS_SECTION,
        .tooltip = "Composites fog in a perceptual space so dark objects behind fog stay darker. Dense fog and fog colour are "
                   "unchanged. 0% = vanilla fog. Default: 10%.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
    },

    // DLSS
    new settings_ui::Setting{
        .key = "DLSSPreset",
        .binding = &ngx_hooks::dlss_preset_index,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 0.f,
        .label = "DLSS Preset",
        .section = DLSS_SECTION,
        .tooltip = "DLSS model preset. Default applies no override. Presets differ in image quality and GPU cost. Applies "
                   "immediately.",
        .labels = {"Default", "E", "F", "J", "K", "L", "M"},
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .key = "RREnable",
        .binding = &rr_guides::rr_enable,
        .value_type = settings_ui::SettingValueType::BOOLEAN,
        .default_value = 0.f,
        .label = "Ray Reconstruction (Experimental)",
        .section = DLSS_SECTION,
        .tooltip = "Replaces DLSS and NRD with DLSS Ray Reconstruction. Needs DLSS on and nvngx_dlssd.dll in the game folder. "
                   "Costs more GPU time than regular DLSS. Default: Off.",
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .key = "RRPreset",
        .binding = &ngx_hooks::rr_preset_index,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 0.f,
        .label = "Ray Reconstruction Preset",
        .section = DLSS_SECTION,
        .tooltip = "Ray Reconstruction model preset (D = transformer, E = newer transformer, F = newest, needs a recent nvngx_dlssd.dll). "
                   "Default applies no override. Needs Ray Reconstruction on.",
        .labels = {"Default", "D", "E", "F"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
        .is_enabled = []() { return rr_guides::rr_enable != 0.f; },
    },
    // Ray Tracing
    new settings_ui::Setting{
        .key = "RTFullRes",
        .binding = &rt_trace::full_res_setting,
        .value_type = settings_ui::SettingValueType::BOOLEAN,
        .default_value = 0.f,
        .label = "Full-Resolution Reflections",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Traces every pixel each frame instead of the game's checkerboard. About 2x the reflection ray cost. "
                   "Default: Off.",
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .key = "RTRaysPerPixel",
        .binding = &rt_multiray::rays_per_pixel_setting,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 1.f,
        .label = "Rays per Pixel",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Traces each reflection pixel this many times per frame with fresh noise and averages the rays before "
                   "denoising. Cuts noise; the GPU cost of RT reflections scales with the count. Default: 1.",
        .tint = ui::TINT_VIOLET,
        .min = 1.f,
        .max = 4.f,
        .format = "%d",
    },
    new settings_ui::Setting{
        .key = "RTWhiteNoise",
        .binding = &rt_noise::white_noise_setting,
        .value_type = settings_ui::SettingValueType::BOOLEAN,
        .default_value = 0.f,
        .label = "Fresh Noise Each Frame",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Replaces the game's repeating 64-frame blue-noise ray pattern with fresh white noise every frame. "
                   "Recommended with Ray Reconstruction; the game's denoiser prefers blue noise. Default: Off.",
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .key = "RTRoughnessCutoff",
        .binding = &rt_trace::roughness_cutoff_setting,
        .default_value = 100.f,
        .label = "Max Reflection Roughness",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Surfaces rougher than this % get no reflection trace. Lower = fewer rough reflections, faster but less "
                   "complete. Game default: 100%.",
        .tint = ui::TINT_VIOLET,
        .min = 10.f,
        .max = 100.f,
        .format = "%.0f%%",
    },
    new settings_ui::Setting{
        .key = "RTMetalSmoothing",
        .binding = &rt_trace::metal_smoothing_setting,
        .default_value = 60.f,
        .label = "Metal Reflection Sharpness",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Roughness reduction (%) the game applies before tracing metallic surfaces. Lower = blurrier, more accurate, "
                   "noisier. Default: 60%.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
    },
    new settings_ui::Setting{
        .key = "RTNonMetalSmoothing",
        .binding = &rt_trace::non_metal_smoothing_setting,
        .default_value = 12.5f,
        .label = "Non-Metal Reflection Sharpness",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Roughness reduction (%) the game applies before tracing non-metal surfaces. Lower = blurrier, more accurate, "
                   "noisier. Default: 12.5%.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.1f%%",
    },
    new settings_ui::Setting{
        .key = "RTHitRoughness",
        .binding = &rt_trace::hit_roughness_setting,
        .default_value = 20.f,
        .label = "Reflected Surface Blur",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Roughness the traced reflection takes on at the hit point. Higher = blurrier reflections of hit surfaces. "
                   "Game default: 20%.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
    },
    new settings_ui::Setting{
        .key = "RTTextureLod",
        .binding = &rt_trace::texture_lod_setting,
        .default_value = 1.f,
        .label = "Reflected Texture Blur",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Mip bias the reflection trace samples surface textures with. Higher = blurrier reflected textures, less "
                   "shimmer. Default: 1.0.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 4.f,
        .format = "%.1f",
    },
    new settings_ui::Setting{
        .key = "RTReflectivityBoost",
        .binding = &rt_trace::reflectivity_boost_setting,
        .default_value = 0.f,
        .label = "Reflectivity Boost",
        .section = RAY_TRACING_SECTION,
        .tooltip = "Adds reflectivity to traced reflections. 0% = game (default).",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
    },

    // Denoiser
    new settings_ui::Setting{
        .key = "NRDOverride",
        .binding = &nrd_override,
        .value_type = settings_ui::SettingValueType::BOOLEAN,
        .default_value = 0.f,
        .label = "Custom Denoiser",
        .section = DENOISER_SECTION,
        .tooltip = "On runs RenoDX's NRD replacements so the options below take effect. Off runs the game's original NRD "
                   "shaders. Ignored while Full-Res Tracing or Ray Reconstruction is on. Default: Off.",
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
        .is_enabled = []() { return rt_trace::full_res_setting == 0.f && !rr_guides::rr_active.load(); },
    },
    new settings_ui::Setting{
        .key = "NRDPassthrough",
        .binding = &nrd_passthrough_setting,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 0.f,
        .label = "Denoising",
        .section = DENOISER_SECTION,
        .tooltip = "Off skips NRD and shows the raw ray-traced reflections. Needs Custom Denoiser on. Default: On.",
        .labels = {"On", "Off (Raw RT)"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_VIOLET,
        .is_enabled = &NrdReplacementsActive,
    },
    new settings_ui::Setting{
        .key = "NRDAccumulation",
        .binding = &shader_injection.nrd_accumulation,
        .default_value = 100.f,
        .label = "History Length",
        .section = DENOISER_SECTION,
        .tooltip = "How many frames of history the denoiser keeps. Lower = less ghosting, more noise. Game default: 100%. "
                   "Needs Custom Denoiser on and Denoising On.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 200.f,
        .format = "%.0f%%",
        .is_enabled = &NrdTuningActive,
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "NRDBlurRadius",
        .binding = &shader_injection.nrd_blur_radius,
        .default_value = 100.f,
        .label = "Blur Radius",
        .section = DENOISER_SECTION,
        .tooltip = "Scales the denoiser's spatial blur radius. Game default: 100%. Needs Custom Denoiser on and Denoising On.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 300.f,
        .format = "%.0f%%",
        .is_enabled = &NrdTuningActive,
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "NRDPlaneSensitivity",
        .binding = &shader_injection.nrd_plane_sensitivity,
        .default_value = 100.f,
        .label = "Depth Edge Protection",
        .section = DENOISER_SECTION,
        .tooltip = "Scales how strictly depth differences stop the blur from spreading. Game default: 100%. Needs Custom Denoiser "
                   "on and Denoising On.",
        .tint = ui::TINT_VIOLET,
        .min = 10.f,
        .max = 400.f,
        .format = "%.0f%%",
        .is_enabled = &NrdTuningActive,
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "NRDNormalStrictness",
        .binding = &shader_injection.nrd_normal_strictness,
        .default_value = 100.f,
        .label = "Normal Edge Protection",
        .section = DENOISER_SECTION,
        .tooltip = "Scales how strictly normal differences stop the blur from spreading. Game default: 100%. Needs Custom Denoiser "
                   "on and Denoising On.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .is_enabled = &NrdTuningActive,
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "NRDFirefly",
        .binding = &shader_injection.nrd_firefly,
        .default_value = 100.f,
        .label = "Firefly Suppression",
        .section = DENOISER_SECTION,
        .tooltip = "Clamps single-pixel bright samples. Only applies with Denoising Off or Ray Reconstruction on. Default: 100%.",
        .tint = ui::TINT_VIOLET,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .is_enabled = []() { return (nrd_passthrough_setting != 0.f && NrdReplacementsActive()) || rr_guides::rr_active.load(); },
        .parse = [](float value) { return value * 0.01f; },
    },

    // About
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::TEXT,
        .label = "Unofficial community HDR mod built with RenoDX. Not affiliated with Marvel, Square Enix or Eidos-Montreal.",
        .section = ABOUT_SECTION,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::TEXT,
        .label = "RenoDX by Carlos Lopez (clshortfuse) and contributors.",
        .section = ABOUT_SECTION,
        .tint = ui::TINT_VIOLET,
    },
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::BUTTON,
        .label = "RenoDX Discord",
        .section = ABOUT_SECTION,
        .tint = ui::TINT_VIOLET,
        .on_change = []() { renodx::utils::platform::LaunchURL("https://discord.gg/", "t9v7wx9NTD"); },
    },
};

void OnPresetOff() {
  renodx::utils::settings::UpdateSetting("ToneMapType", 0.f);
  auto* peak_setting = renodx::utils::settings::FindSetting("ToneMapPeakNits");
  renodx::utils::settings::UpdateSetting("ToneMapPeakNits", peak_setting != nullptr ? peak_setting->default_value : 1000.f);
  renodx::utils::settings::UpdateSetting("ToneMapSDRColor", 100.f);
  renodx::utils::settings::UpdateSetting("ToneMapHueClip", 0.f);
  renodx::utils::settings::UpdateSetting("ToneMapGameNits", 203.f);
  renodx::utils::settings::UpdateSetting("ToneMapUINits", 203.f);
  renodx::utils::settings::UpdateSetting("GammaCorrection", 0.f);
  // Lilium at 50 measured about half of the game's RCAS, so vanilla uses 100.
  renodx::utils::settings::UpdateSetting("Sharpness", 100.f);
  renodx::utils::settings::UpdateSetting("ColorGradeExposure", 0.f);
  renodx::utils::settings::UpdateSetting("ColorGradeContrast", 100.f);
  renodx::utils::settings::UpdateSetting("ColorGradeSaturation", 100.f);
  renodx::utils::settings::UpdateSetting("ColorGradeHighlights", 100.f);
  renodx::utils::settings::UpdateSetting("ColorGradeShadows", 100.f);
  renodx::utils::settings::UpdateSetting("BloomStrength", 100.f);
  renodx::utils::settings::UpdateSetting("BloomThreshold", 100.f);
  renodx::utils::settings::UpdateSetting("BloomSaturation", 100.f);
  renodx::utils::settings::UpdateSetting("NRDOverride", 0.f);
  renodx::utils::settings::UpdateSetting("NRDPassthrough", 0.f);
  renodx::utils::settings::UpdateSetting("NRDAccumulation", 100.f);
  renodx::utils::settings::UpdateSetting("NRDBlurRadius", 100.f);
  renodx::utils::settings::UpdateSetting("NRDPlaneSensitivity", 100.f);
  renodx::utils::settings::UpdateSetting("NRDNormalStrictness", 100.f);
  renodx::utils::settings::UpdateSetting("NRDFirefly", 0.f);
  renodx::utils::settings::UpdateSetting("RTFullRes", 0.f);
  renodx::utils::settings::UpdateSetting("RTWhiteNoise", 0.f);
  renodx::utils::settings::UpdateSetting("RTRaysPerPixel", 1.f);
  renodx::utils::settings::UpdateSetting("RTMetalSmoothing", 60.f);
  renodx::utils::settings::UpdateSetting("RTNonMetalSmoothing", 12.5f);
  renodx::utils::settings::UpdateSetting("RTTextureLod", 1.f);
  renodx::utils::settings::UpdateSetting("RTReflectivityBoost", 0.f);
  renodx::utils::settings::UpdateSetting("RTHitRoughness", 20.f);
  renodx::utils::settings::UpdateSetting("RTRoughnessCutoff", 100.f);
  renodx::utils::settings::UpdateSetting("DOFUpscale", 1.f);
  renodx::utils::settings::UpdateSetting("DOFDither", 1.f);
  renodx::utils::settings::UpdateSetting("BokehMaxSamples", 32.f);
  renodx::utils::settings::UpdateSetting("FogBlackPreservation", 0.f);
  renodx::utils::settings::UpdateSetting("DLSSPreset", 0.f);
  renodx::utils::settings::UpdateSetting("RRPreset", 0.f);
  renodx::utils::settings::UpdateSetting("RREnable", 0.f);
}

bool fired_on_init_swapchain = false;

void OnInitSwapchain(reshade::api::swapchain* swapchain, bool resize) {
  if (fired_on_init_swapchain) return;
  if (!renodx::utils::swapchain::IsDXGI(swapchain)) return;
  fired_on_init_swapchain = true;

  const auto peak = renodx::utils::swapchain::GetPeakNits(swapchain);
  if (!peak.has_value()) return;

  auto* peak_setting = renodx::utils::settings::FindSetting("ToneMapPeakNits");
  if (peak_setting == nullptr) return;
  const float peak_nits = std::round(peak.value());
  peak_setting->default_value = peak_nits;
  peak_setting->can_reset = true;

  // Presets load before the swapchain exists, so a missing key means the default was never saved.
  if (renodx::utils::settings::preset_index == 0) return;
  float saved_peak_nits = 0.f;
  if (!reshade::get_config_value(nullptr, renodx::utils::settings::GetCurrentPresetName().c_str(), "ToneMapPeakNits", saved_peak_nits)) {
    renodx::utils::settings::UpdateSetting("ToneMapPeakNits", peak_nits);
  }
}

// Pre-fog copy of RT0. Buffers are sized to the current frame and superseded ones are retired rather than
// destroyed, because command lists recorded earlier may still reference them.
struct PreFogScene {
  std::shared_mutex mutex;
  reshade::api::device* device = nullptr;
  reshade::api::resource buffer = {0u};
  reshade::api::resource_view srv = {0u};
  uint64_t size_bytes = 0u;
  std::vector<rr_guides::RetiredResources> retired;
};
PreFogScene pre_fog_scene;

void OnPresent(
    reshade::api::command_queue* /*queue*/,
    reshade::api::swapchain* swapchain,
    const reshade::api::rect* /*source_rect*/,
    const reshade::api::rect* /*dest_rect*/,
    uint32_t /*dirty_rect_count*/,
    const reshade::api::rect* /*dirty_rects*/) {
  if (swapchain->get_color_space() == reshade::api::color_space::hdr10_st2084) {
    shader_injection.hdr_output = 1.f;
  } else {
    shader_injection.hdr_output = 0.f;
  }
  shader_injection.nrd_passthrough = ((nrd_passthrough_setting != 0.f || rr_guides::rr_active.load()) ? 1.f : 0.f);
  presents_since_full_res = (rt_trace::patched_last_frame.exchange(false) ? 0u : std::min(presents_since_full_res + 1u, 8u));
  shader_injection.rt_full_res = (presents_since_full_res < 3u ? 1.f : 0.f);
  rr_guides::full_res_active = shader_injection.rt_full_res;
  ngx_hooks::OnPresent();
  rr_guides::OnPresent();
  rt_multiray::OnPresent();

  std::unique_lock lock(pre_fog_scene.mutex);
  rr_guides::AgeRetired(pre_fog_scene.device, &pre_fog_scene.retired);
}

// Inject into compute root signatures with the game's sampler/SRV/UAV/CBV layout (final display mapping and bloom passes);
// cloning all layouts hangs the GPU in this game.
constexpr uint32_t FOG_SHADER_HASH = 0x31720375u;
// The fog shader reads the pre-fog scene as a raw buffer SRV at t0 space51.
constexpr uint32_t FOG_SCENE_SRV_SPACE = 51u;
constexpr uint32_t FOG_SCENE_SRV_REGISTER = 0u;
// Graphics layouts of the fog pass carry the game's SRV at t65 space1.
constexpr uint32_t FOG_LAYOUT_SRV_SPACE = 1u;
constexpr uint32_t FOG_LAYOUT_SRV_REGISTER = 65u;

// Accepted and rejected layouts that cover the fog SRV, logged once per distinct summary.
struct FogLayoutLog {
  std::shared_mutex mutex;
  std::unordered_set<std::string> logged;
};
FogLayoutLog fog_layout_log;

bool OnCreatePipelineLayout(reshade::api::device* /*device*/, std::span<reshade::api::pipeline_layout_param> params) {
  constexpr size_t PARAM_COUNT = 4;
  constexpr size_t TABLE_PARAM_COUNT = 3;
  constexpr uint32_t SAMPLER_TABLE_SIZE = 2048;
  constexpr reshade::api::descriptor_type expected_range_type[TABLE_PARAM_COUNT] = {
      reshade::api::descriptor_type::sampler,
      reshade::api::descriptor_type::shader_resource_view,
      reshade::api::descriptor_type::unordered_access_view,
  };

  // Compute layout (final display mapping and bloom passes).
  auto accepts_compute_layout = [&]() -> bool {
    if (params.size() != PARAM_COUNT) return false;
    for (size_t i = 0; i < TABLE_PARAM_COUNT; ++i) {
      const auto& param = params[i];
      if (param.type != reshade::api::pipeline_layout_param_type::descriptor_table_with_static_samplers ||
          param.descriptor_table_with_static_samplers.count != 1) {
        return false;
      }
      const auto& range = param.descriptor_table_with_static_samplers.ranges[0];
      if (range.type != expected_range_type[i]) return false;
      if (range.type == reshade::api::descriptor_type::sampler && range.count != SAMPLER_TABLE_SIZE) return false;
      if (range.count == 0) return false;
    }

    const auto& last = params[PARAM_COUNT - 1];
    if (last.type != reshade::api::pipeline_layout_param_type::push_descriptors_with_static_samplers ||
        last.descriptor_table_with_static_samplers.count != 1) {
      return false;
    }
    const auto& last_range = last.descriptor_table_with_static_samplers.ranges[0];
    if (last_range.type != reshade::api::descriptor_type::constant_buffer || last_range.count != 1) return false;

    return true;
  };

  // Graphics layout of the fog pass: accepted when it has a sampler table, no UAV ranges, and the t65 space1 SRV.
  // Type fields are reshade descriptor_type / pipeline_layout_param_type enum values.
  auto accepts_fog_layout = [&]() -> bool {
    bool has_sampler = false;
    bool has_unordered_access = false;
    bool covers_fog_srv = false;
    std::stringstream summary;
    for (size_t param_index = 0; param_index < params.size(); ++param_index) {
      const auto& param = params[param_index];
      summary << " p" << param_index << " type " << static_cast<uint32_t>(param.type) << ":";
      const auto visit_range = [&](const reshade::api::descriptor_range& range) {
        summary << " [type " << static_cast<uint32_t>(range.type) << " space " << range.dx_register_space
                << " index " << range.dx_register_index << " count " << range.count << "]";
        switch (range.type) {
          case reshade::api::descriptor_type::sampler:
            has_sampler = true;
            break;
          case reshade::api::descriptor_type::unordered_access_view:
            has_unordered_access = true;
            break;
          case reshade::api::descriptor_type::shader_resource_view:
            // 64-bit sum so an unbounded range (count == UINT32_MAX) still covers the register.
            if (range.dx_register_space == FOG_LAYOUT_SRV_SPACE && range.dx_register_index <= FOG_LAYOUT_SRV_REGISTER
                && static_cast<uint64_t>(range.dx_register_index) + range.count > FOG_LAYOUT_SRV_REGISTER) {
              covers_fog_srv = true;
            }
            break;
          default:
            break;
        }
      };
      switch (param.type) {
        case reshade::api::pipeline_layout_param_type::descriptor_table:
        case reshade::api::pipeline_layout_param_type::push_descriptors_with_ranges:
          for (uint32_t range_index = 0; range_index < param.descriptor_table.count; ++range_index) {
            visit_range(param.descriptor_table.ranges[range_index]);
          }
          break;
        case reshade::api::pipeline_layout_param_type::descriptor_table_with_static_samplers:
        case reshade::api::pipeline_layout_param_type::push_descriptors_with_static_samplers:
          for (uint32_t range_index = 0; range_index < param.descriptor_table_with_static_samplers.count; ++range_index) {
            visit_range(param.descriptor_table_with_static_samplers.ranges[range_index]);
          }
          break;
        case reshade::api::pipeline_layout_param_type::push_descriptors:
          visit_range(param.push_descriptors);
          break;
        default:
          break;
      }
    }
    if (!covers_fog_srv) return false;

    const bool accepted = has_sampler && !has_unordered_access;
    const auto key = summary.str();
    {
      std::unique_lock lock(fog_layout_log.mutex);
      if (fog_layout_log.logged.insert(key).second) {
        std::stringstream s;
        s << "GotG fog layout " << (accepted ? "accepted" : "rejected") << ":" << key;
        reshade::log::message(reshade::log::level::info, s.str().c_str());
      }
    }
    return accepted;
  };

  if (accepts_compute_layout()) return true;
  return accepts_fog_layout();
}

enum class FogSkip : uint32_t {
  DISABLED = 1u << 0,
  MISSING_INJECTION = 1u << 1,
  RENDER_PASS_ACTIVE = 1u << 2,
  MISSING_RT0 = 1u << 3,
  RT0_NOT_TEXTURE_2D = 1u << 4,
  RT0_MULTISAMPLED = 1u << 5,
  RT0_FORMAT = 1u << 6,
  BUFFER_CREATE_FAILED = 1u << 7,
};
std::atomic<uint32_t> logged_fog_skips = {0u};

// The six NRD denoiser passes of RT reflections, gated by the Denoiser Override toggle.
constexpr uint32_t NRD_SHADER_HASHES[] = {0x9634F8F6u, 0x949DC781u, 0x09E49AB4u, 0xBCDC16CEu, 0xABB2EC1Cu, 0x4AA90CAFu};

bool OnNRDReplace(reshade::api::command_list*) {
  return nrd_override != 0.f || rt_trace::full_res_setting != 0.f || rr_guides::rr_enable != 0.f;
}

// Copies the pre-fog RT0 into the scene buffer. Returns false (vanilla fog) when the copy cannot be recorded.
bool OnFogReplace(reshade::api::command_list* cmd_list) {
  const auto skip = [](FogSkip reason, const char* message) {
    const auto bit = static_cast<uint32_t>(reason);
    if ((logged_fog_skips.fetch_or(bit) & bit) == 0u) {
      reshade::log::message(reshade::log::level::info, message);
    }
    return false;
  };

  if (shader_injection.fog_black_preservation <= 0.f) {
    return skip(FogSkip::DISABLED, "GotG fog black preservation disabled: vanilla fog");
  }

  auto* device = cmd_list->get_device();
  const auto pixel_pipeline = renodx::utils::state::GetBoundShaderPipeline(cmd_list, reshade::api::pipeline_stage::pixel_shader);
  bool has_injection = false;
  bool has_scene_location = false;
  renodx::utils::shader::GetPipelineShaderDetails(pixel_pipeline, [&](const auto& details) {
    has_injection = details.injection_layout.handle != 0u && details.injection_index != -1;
    // Same lookup as mods::shader's view push, so the replacement never reaches its view assert path.
    const auto scene_location = details.descriptor_push_locations.find(
        {reshade::api::descriptor_type::buffer_shader_resource_view, FOG_SCENE_SRV_REGISTER, FOG_SCENE_SRV_SPACE});
    has_scene_location = scene_location != details.descriptor_push_locations.end();
  });
  if (!has_injection || !has_scene_location) {
    return skip(FogSkip::MISSING_INJECTION, "GotG fog black preservation: pipeline has no injection or scene SRV location, vanilla fog");
  }

  // The copy cannot be recorded inside a render pass; state tracking records the pass depth per command list.
  const auto* snapshot_data = renodx::utils::state::internal::GetTrackedSnapshotData(cmd_list);
  if (snapshot_data != nullptr && snapshot_data->render_pass_depth != 0u) {
    return skip(FogSkip::RENDER_PASS_ACTIVE, "GotG fog black preservation: render pass active, vanilla fog");
  }

  const auto rt_view = renodx::utils::state::GetRenderTarget(cmd_list, 0u);
  const auto rt = device->get_resource_from_view(rt_view);
  if (rt.handle == 0u) {
    return skip(FogSkip::MISSING_RT0, "GotG fog black preservation: RT0 missing, vanilla fog");
  }
  const auto rt_desc = renodx::utils::resource::GetResourceDesc(device, rt);
  if (rt_desc.type != reshade::api::resource_type::texture_2d) {
    return skip(FogSkip::RT0_NOT_TEXTURE_2D, "GotG fog black preservation: RT0 is not a 2D texture, vanilla fog");
  }
  if (rt_desc.texture.samples != 1u) {
    return skip(FogSkip::RT0_MULTISAMPLED, "GotG fog black preservation: RT0 is multisampled, vanilla fog");
  }
  if (rt_desc.texture.format != reshade::api::format::r16g16b16a16_float
      && rt_desc.texture.format != reshade::api::format::r16g16b16a16_typeless) {
    return skip(FogSkip::RT0_FORMAT, "GotG fog black preservation: RT0 is not RGBA16F, vanilla fog");
  }

  const uint32_t height = rt_desc.texture.height;
  // Row pitch is 256-byte aligned for copy_texture_to_buffer; row_pixels is in RGBA16F pixels (8 bytes).
  const uint32_t row_pixels = ((rt_desc.texture.width * 8u + 255u) & ~255u) / 8u;
  const uint64_t size_bytes = static_cast<uint64_t>(row_pixels) * 8u * height;

  reshade::api::resource buffer = {0u};
  {
    std::unique_lock lock(pre_fog_scene.mutex);
    if (pre_fog_scene.buffer.handle == 0u || pre_fog_scene.size_bytes < size_bytes) {
      const reshade::api::resource_desc buffer_desc(
          size_bytes,
          reshade::api::memory_heap::gpu_only,
          reshade::api::resource_usage::shader_resource | reshade::api::resource_usage::copy_dest);
      reshade::api::resource new_buffer = {0u};
      if (!device->create_resource(buffer_desc, nullptr, reshade::api::resource_usage::shader_resource, &new_buffer)) {
        return skip(FogSkip::BUFFER_CREATE_FAILED, "GotG fog black preservation: pre-fog buffer creation failed, vanilla fog");
      }
      reshade::api::resource_view new_srv = {0u};
      if (!device->create_resource_view(
              new_buffer,
              reshade::api::resource_usage::shader_resource,
              reshade::api::resource_view_desc(reshade::api::format::r32_typeless, 0u, size_bytes / sizeof(uint32_t)),
              &new_srv)) {
        device->destroy_resource(new_buffer);
        return skip(FogSkip::BUFFER_CREATE_FAILED, "GotG fog black preservation: pre-fog buffer view creation failed, vanilla fog");
      }
      if (pre_fog_scene.buffer.handle != 0u) {
        pre_fog_scene.retired.push_back({
            .resources = {pre_fog_scene.buffer},
            .views = {pre_fog_scene.srv},
            .presents_left = rr_guides::RETIRE_PRESENT_COUNT,
        });
      }
      pre_fog_scene.device = device;
      pre_fog_scene.buffer = new_buffer;
      pre_fog_scene.srv = new_srv;
      pre_fog_scene.size_bytes = size_bytes;
    }
    buffer = pre_fog_scene.buffer;
  }

  // Every use restores the states it changed, so command lists can record in parallel.
  cmd_list->barrier(rt, reshade::api::resource_usage::render_target, reshade::api::resource_usage::copy_source);
  cmd_list->barrier(buffer, reshade::api::resource_usage::shader_resource, reshade::api::resource_usage::copy_dest);
  cmd_list->copy_texture_to_buffer(rt, 0u, nullptr, buffer, 0u, row_pixels, height);
  cmd_list->barrier(rt, reshade::api::resource_usage::copy_source, reshade::api::resource_usage::render_target);
  cmd_list->barrier(buffer, reshade::api::resource_usage::copy_dest, reshade::api::resource_usage::shader_resource);

  shader_injection.fog_scene_row_pixels = static_cast<float>(row_pixels);
  return true;
}

reshade::api::resource_view GetPreFogSceneView(reshade::api::command_list* /*cmd_list*/) {
  std::shared_lock lock(pre_fog_scene.mutex);
  return pre_fog_scene.srv;
}

void OnDestroyDevice(reshade::api::device* device) {
  std::unique_lock lock(pre_fog_scene.mutex);
  if (pre_fog_scene.device != device) return;
  if (pre_fog_scene.srv.handle != 0u) {
    device->destroy_resource_view(pre_fog_scene.srv);
  }
  if (pre_fog_scene.buffer.handle != 0u) {
    device->destroy_resource(pre_fog_scene.buffer);
  }
  for (const auto& retired : pre_fog_scene.retired) {
    rr_guides::DestroyRetired(device, retired);
  }
  pre_fog_scene.retired.clear();
  pre_fog_scene.device = nullptr;
  pre_fog_scene.buffer = {0u};
  pre_fog_scene.srv = {0u};
  pre_fog_scene.size_bytes = 0u;
}

// Dispatch event for the NRD passes that read the full-res flag. Uses the flag of the command list that recorded the
// trace, which can differ from the list that records these passes. Always returns false so the game's dispatch runs.
bool OnNRDFullResDispatch(
    reshade::api::command_list* cmd_list,
    uint32_t /*group_count_x*/,
    uint32_t /*group_count_y*/,
    uint32_t /*group_count_z*/) {
  const auto shader_hash = renodx::utils::state::GetCurrentShaderHash(cmd_list, reshade::api::pipeline_stage::compute_shader);
  if (shader_hash != rr_guides::PRE_BLUR_HASH && shader_hash != rr_guides::TEMPORAL_ACCUMULATION_HASH) return false;

  const auto full_res = rt_trace::FullResForCommandList(cmd_list);
  if (full_res.has_value()) {
    shader_injection.rt_full_res = (full_res.value() ? 1.f : 0.f);
    rr_guides::full_res_active = shader_injection.rt_full_res;
    return false;
  }

  static std::atomic_bool logged_missing_trace{false};
  if (!logged_missing_trace.exchange(true)) {
    reshade::log::message(
        reshade::log::level::info,
        "GotG: NRD pass on a different command list than the trace, using present-based full-res flag");
  }
  return false;
}

}  // namespace

extern "C" __declspec(dllexport) constexpr const char* NAME = "RenoDX";
extern "C" __declspec(dllexport) constexpr const char* DESCRIPTION = "RenoDX for Marvel's Guardians of the Galaxy";

BOOL APIENTRY DllMain(HMODULE h_module, DWORD fdw_reason, LPVOID lpv_reserved) {
  switch (fdw_reason) {
    case DLL_PROCESS_ATTACH:
      if (!reshade::register_addon(h_module)) return FALSE;
      reshade::register_event<reshade::addon_event::init_swapchain>(OnInitSwapchain);
      reshade::register_event<reshade::addon_event::present>(OnPresent);

      renodx::mods::shader::on_create_pipeline_layout = OnCreatePipelineLayout;
      renodx::mods::shader::expected_constant_buffer_space = 50;
      renodx::mods::shader::expected_constant_buffer_index = 13;
      renodx::utils::shader::use_replace_on_create = false;

      reshade::register_event<reshade::addon_event::destroy_device>(OnDestroyDevice);
      reshade::register_event<reshade::addon_event::destroy_device>(rr_guides::OnDestroyDevice);
      reshade::register_event<reshade::addon_event::destroy_device>(rt_noise::OnDestroyDevice);
      reshade::register_event<reshade::addon_event::destroy_device>(rt_multiray::OnDestroyDevice);
      reshade::register_event<reshade::addon_event::dispatch>(OnNRDFullResDispatch);
      reshade::register_event<reshade::addon_event::dispatch>(rt_multiray::OnDispatch);
      reshade::register_event<reshade::addon_event::dispatch>(rr_guides::OnDispatch);
      reshade::register_event<reshade::addon_event::dispatch>(rt_trace::OnDispatch);
      reshade::register_event<reshade::addon_event::dispatch>(rt_noise::OnDispatch);
      reshade::register_event<reshade::addon_event::dispatch_rays>(rt_trace::OnDispatchRays);
      reshade::register_event<reshade::addon_event::push_descriptors>(rr_guides::OnPushDescriptors);
      reshade::register_event<reshade::addon_event::destroy_resource>(rr_guides::OnDestroyResource);
      reshade::register_event<reshade::addon_event::destroy_resource>(rt_noise::OnDestroyResource);
      reshade::register_event<reshade::addon_event::destroy_resource>(rt_multiray::OnDestroyResource);
      reshade::register_event<reshade::addon_event::reset_command_list>(rr_guides::OnForgetCommandList);
      reshade::register_event<reshade::addon_event::destroy_command_list>(rr_guides::OnForgetCommandList);
      reshade::register_event<reshade::addon_event::reset_command_list>(rt_trace::OnForgetCommandList);
      reshade::register_event<reshade::addon_event::destroy_command_list>(rt_trace::OnForgetCommandList);
      rt_trace::rt_full_res_flag = &shader_injection.rt_full_res;
      renodx::utils::state::use_render_target_tracking = true;
      for (const auto hash : NRD_SHADER_HASHES) {
        if (custom_shaders.contains(hash)) {
          custom_shaders.at(hash).on_replace = OnNRDReplace;
        }
      }
      if (custom_shaders.contains(FOG_SHADER_HASH)) {
        auto& fog_shader = custom_shaders.at(FOG_SHADER_HASH);
        fog_shader.on_replace = OnFogReplace;
        fog_shader.views = {{
            .type = reshade::api::descriptor_type::buffer_shader_resource_view,
            .slot = FOG_SCENE_SRV_REGISTER,
            .space = FOG_SCENE_SRV_SPACE,
            .get_view = GetPreFogSceneView,
        }};
      } else {
        reshade::log::message(reshade::log::level::error, "GotG: fog shader 0x31720375 is not in the embedded custom shader set");
      }
      break;
    case DLL_PROCESS_DETACH:
      reshade::unregister_event<reshade::addon_event::init_swapchain>(OnInitSwapchain);
      reshade::unregister_event<reshade::addon_event::present>(OnPresent);
      reshade::unregister_event<reshade::addon_event::destroy_device>(OnDestroyDevice);
      reshade::unregister_event<reshade::addon_event::destroy_device>(rr_guides::OnDestroyDevice);
      reshade::unregister_event<reshade::addon_event::destroy_device>(rt_noise::OnDestroyDevice);
      reshade::unregister_event<reshade::addon_event::destroy_device>(rt_multiray::OnDestroyDevice);
      reshade::unregister_event<reshade::addon_event::dispatch>(OnNRDFullResDispatch);
      reshade::unregister_event<reshade::addon_event::dispatch>(rt_multiray::OnDispatch);
      reshade::unregister_event<reshade::addon_event::dispatch>(rr_guides::OnDispatch);
      reshade::unregister_event<reshade::addon_event::dispatch>(rt_trace::OnDispatch);
      reshade::unregister_event<reshade::addon_event::dispatch>(rt_noise::OnDispatch);
      reshade::unregister_event<reshade::addon_event::dispatch_rays>(rt_trace::OnDispatchRays);
      reshade::unregister_event<reshade::addon_event::push_descriptors>(rr_guides::OnPushDescriptors);
      reshade::unregister_event<reshade::addon_event::destroy_resource>(rr_guides::OnDestroyResource);
      reshade::unregister_event<reshade::addon_event::destroy_resource>(rt_noise::OnDestroyResource);
      reshade::unregister_event<reshade::addon_event::destroy_resource>(rt_multiray::OnDestroyResource);
      reshade::unregister_event<reshade::addon_event::reset_command_list>(rr_guides::OnForgetCommandList);
      reshade::unregister_event<reshade::addon_event::destroy_command_list>(rr_guides::OnForgetCommandList);
      reshade::unregister_event<reshade::addon_event::reset_command_list>(rt_trace::OnForgetCommandList);
      reshade::unregister_event<reshade::addon_event::destroy_command_list>(rt_trace::OnForgetCommandList);
      reshade::unregister_addon(h_module);
      break;
  }

  // Always on: the RT and RR passes look up bound descriptors.
  renodx::utils::descriptor::trace_descriptor_tables = true;
  renodx::utils::descriptor::Use(fdw_reason);
  // RenderPass reads resource/view info from utils::resource tracking (null store without Use: crash).
  renodx::utils::resource::Use(fdw_reason);
  renodx::utils::settings::open_sections_by_default = false;
  renodx::utils::settings::default_open_sections = {STATUS_SECTION, TONE_MAPPING_SECTION, COLOR_GRADING_SECTION};
  renodx::utils::settings::Use(fdw_reason, &settings, &OnPresetOff);
  // Always on: the RT and RR passes look up bound descriptors.
  renodx::utils::state::use_snapshot = true;
  renodx::mods::shader::Use(fdw_reason, custom_shaders, &shader_injection);

  return TRUE;
}
