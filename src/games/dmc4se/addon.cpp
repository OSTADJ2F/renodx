/*
 * Copyright (C) 2024 Carlos Lopez
 * SPDX-License-Identifier: MIT
 */

#define ImTextureID ImU64

#define DEBUG_LEVEL_0

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <future>
#include <sstream>
#include <string>
#include <thread>

#include <d3d10_1.h>
#include <dxgi.h>

#include <deps/imgui/imgui.h>
#include <include/reshade.hpp>

#include <embed/shaders.h>

#include "../../mods/shader.hpp"
#include "../../mods/swapchain.hpp"
#include "../../utils/device_proxy.hpp"
#include "../../utils/platform.hpp"
#include "../../utils/settings.hpp"
#include "../../utils/vtable.hpp"
#include "./shared.h"
#include "./ui.hpp"

namespace {

renodx::mods::shader::CustomShaders custom_shaders = {
    // CustomShaderEntry(0x00000000),
    // CustomSwapchainShader(0x00000000),
    // BypassShaderEntry(0x00000000),
    __ALL_CUSTOM_SHADERS
};

ShaderInjectData shader_injection;

float current_settings_mode = 0;

// 0 = the game owns the cursor over the overlay, 1 = hidden. Read on the overlay thread.
float cursor_mode = 0;

// Read in DllMain: the device proxy is set up before presets load.
renodx::utils::settings::Setting* output_mode_setting = nullptr;

// Set in DllMain from the game's config.ini.
bool csaa_enabled = false;

namespace ui = dmc4_ui;
namespace settings_ui = renodx::utils::settings;

// Section titles, in panel order.
constexpr const char* STATUS_SECTION = "Status";
constexpr const char* TONE_MAPPING_SECTION = "Tone Mapping";
constexpr const char* COLOR_GRADING_SECTION = "Color Grading";
constexpr const char* BLOOM_SECTION = "Bloom";
constexpr const char* EFFECTS_SECTION = "Effects";
constexpr const char* DISPLAY_OUTPUT_SECTION = "Display Output";
constexpr const char* ABOUT_SECTION = "About";

// Custom tone mapping (anything but Vanilla) gates the grading, bloom shaping and effects HDR shader paths.
bool CustomToneMapActive() { return shader_injection.tone_map_type >= 1.f; }

settings_ui::Settings settings = {
    // Status
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::CUSTOM,
        .label = "Status",
        .section = STATUS_SECTION,
        .tint = ui::TINT_CRIMSON,
        .on_draw = []() {
          struct Item {
            const char* text;
            bool active;
          };
          const bool hdr_active = output_mode_setting->GetValue() == 1.f;
          const bool tone_map_active = shader_injection.tone_map_type != 0.f;
          const Item items[] = {
              {hdr_active ? "HDR10" : "SDR", hdr_active},
              {tone_map_active ? "Custom Tone Map" : "Vanilla", tone_map_active},
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
                active ? ui::CRIMSON_GLOW : ui::WithAlpha(ui::GUNMETAL, 0.6f), 12);
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
        .tint = ui::TINT_CRIMSON,
        .on_change = []() { settings_ui::ResetSettings(); },
    },
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::TEXT,
        .label = "RenoDX for Devil May Cry 4 Special Edition Made By Ostad Gaming",
        .section = STATUS_SECTION,
        .tint = ui::TINT_CRIMSON,
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
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::TEXT,
        .label = "Warning: CSAA is untested with HDR render targets; use NONE or MSAA.",
        .section = STATUS_SECTION,
        .tint = ui::TINT_CRIMSON,
        .is_visible = []() { return csaa_enabled; },
    },
    new settings_ui::Setting{
        .key = "SettingsMode",
        .binding = &current_settings_mode,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 0.f,
        .can_reset = false,
        .label = "Settings Mode",
        .section = STATUS_SECTION,
        .tooltip = "Simple shows the essentials. Intermediate and Advanced reveal more tone mapping, grading and output options.",
        .labels = {"Simple", "Intermediate", "Advanced"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_CRIMSON,
        .is_global = true,
    },

    // Tone Mapping
    new settings_ui::Setting{
        .key = "ToneMapType",
        .binding = &shader_injection.tone_map_type,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 3.f,
        .can_reset = true,
        .label = "Tone Mapper",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Vanilla keeps the game's SDR look. None, ACES and RenoDRT extend it to HDR. Default: RenoDRT.",
        .labels = {"Vanilla", "None", "ACES", "RenoDRT"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_CRIMSON,
        .is_visible = []() { return current_settings_mode >= 1; },
    },
    new settings_ui::Setting{
        .key = "ToneMapPeakNits",
        .binding = &shader_injection.peak_white_nits,
        .default_value = 1000.f,
        .can_reset = false,
        .label = "Peak Brightness",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Brightest level your display can show, in nits. Default: 1000.",
        .tint = ui::TINT_CRIMSON,
        .min = 48.f,
        .max = 4000.f,
        .format = "%.0f nits",
    },
    new settings_ui::Setting{
        .key = "ToneMapGameNits",
        .binding = &shader_injection.diffuse_white_nits,
        .default_value = 203.f,
        .label = "Game Brightness",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Brightness of 100% white in the scene, in nits. Default: 203.",
        .tint = ui::TINT_CRIMSON,
        .min = 48.f,
        .max = 500.f,
        .format = "%.0f nits",
    },
    new settings_ui::Setting{
        .key = "ToneMapUINits",
        .binding = &shader_injection.graphics_white_nits,
        .default_value = 203.f,
        .label = "UI Brightness",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Brightness of the HUD and menus, in nits. Default: 203.",
        .tint = ui::TINT_CRIMSON,
        .min = 48.f,
        .max = 500.f,
        .format = "%.0f nits",
    },
    new settings_ui::Setting{
        .key = "GammaCorrection",
        .binding = &shader_injection.gamma_correction,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 1.f,
        .label = "Gamma Correction",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Display gamma the image is mastered for. Default: 2.2.",
        .labels = {"Off", "2.2", "BT.1886"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_CRIMSON,
        // The intermediate encoding and the swapchain decoding always follow this setting.
        .parse = [](float value) {
          shader_injection.intermediate_encoding = value + 1.f;
          shader_injection.swap_chain_decoding = value + 1.f;
          return value;
        },
        .is_visible = []() { return current_settings_mode >= 1; },
    },
    new settings_ui::Setting{
        .key = "ToneMapScaling",
        .binding = &shader_injection.tone_map_per_channel,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 0.f,
        .label = "Scaling",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Luminance keeps colors consistent. Per Channel saturates and blows out highlights sooner. Default: Luminance.",
        .labels = {"Luminance", "Per Channel"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_CRIMSON,
        .is_visible = []() { return current_settings_mode >= 2 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ToneMapHueProcessor",
        .binding = &shader_injection.tone_map_hue_processor,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 0.f,
        .label = "Hue Processor",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Color space used for hue correction and hue shift. Default: OKLab.",
        .labels = {"OKLab", "ICtCp", "darkTable UCS"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_CRIMSON,
        .is_visible = []() { return current_settings_mode >= 2 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ToneMapHueCorrection",
        .binding = &shader_injection.tone_map_hue_correction,
        .default_value = 100.f,
        .label = "Hue Correction",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "How much tone mapping keeps the original hue. Default: 100%.",
        .tint = ui::TINT_CRIMSON,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return current_settings_mode >= 2 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ToneMapHueShift",
        .binding = &shader_injection.tone_map_hue_shift,
        .default_value = 0.f,
        .label = "Hue Shift",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "Shifts hues in bright areas the way the original SDR tone mapping did. Default: 0%.",
        .tint = ui::TINT_CRIMSON,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return current_settings_mode >= 1 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ToneMapHighlightHue",
        .binding = &shader_injection.highlight_hue,
        .default_value = 100.f,
        .label = "Highlight Hue",
        .section = TONE_MAPPING_SECTION,
        .tooltip = "100% matches the original game, where warm highlights clipped toward white. 0% keeps the scene's own color. Default: 100%.",
        .tint = ui::TINT_CRIMSON,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return CustomToneMapActive(); },
    },

    // Color Grading
    new settings_ui::Setting{
        .key = "ColorGradeExposure",
        .binding = &shader_injection.tone_map_exposure,
        .default_value = 1.f,
        .label = "Exposure",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Overall scene brightness multiplier. Default: 1.00.",
        .tint = ui::TINT_CRIMSON,
        .max = 2.f,
        .format = "%.2f",
        .is_visible = []() { return current_settings_mode >= 1 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ColorGradeHighlights",
        .binding = &shader_injection.tone_map_highlights,
        .default_value = 50.f,
        .label = "Highlights",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Brightens or darkens bright areas. Default: 50.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .parse = [](float value) { return value * 0.02f; },
        .is_visible = []() { return current_settings_mode >= 1 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ColorGradeShadows",
        .binding = &shader_injection.tone_map_shadows,
        .default_value = 50.f,
        .label = "Shadows",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Brightens or darkens dark areas. Default: 50.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .parse = [](float value) { return value * 0.02f; },
        .is_visible = []() { return current_settings_mode >= 1 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ColorGradeContrast",
        .binding = &shader_injection.tone_map_contrast,
        .default_value = 50.f,
        .label = "Contrast",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Separation between dark and bright areas. Default: 50.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .parse = [](float value) { return value * 0.02f; },
        .is_visible = []() { return CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ColorGradeSaturation",
        .binding = &shader_injection.tone_map_saturation,
        .default_value = 50.f,
        .label = "Saturation",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Overall color intensity. Default: 50.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .parse = [](float value) { return value * 0.02f; },
        .is_visible = []() { return CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ColorGradeHighlightSaturation",
        .binding = &shader_injection.tone_map_highlight_saturation,
        .default_value = 50.f,
        .label = "Highlight Saturation",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Adds or removes color in bright areas. Default: 50.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .parse = [](float value) { return value * 0.02f; },
        .is_visible = []() { return current_settings_mode >= 1 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ColorGradeBlowout",
        .binding = &shader_injection.tone_map_blowout,
        .default_value = 0.f,
        .label = "Blowout",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Desaturates overexposed highlights toward white. Default: 0%.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "ColorGradeFlare",
        .binding = &shader_injection.tone_map_flare,
        .default_value = 0.f,
        .label = "Flare",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Compensates for lens flare and glare by lifting shadows. RenoDRT only. Default: 0.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .parse = [](float value) { return value * 0.02f; },
        .is_visible = []() { return shader_injection.tone_map_type == 3.f; },
    },
    new settings_ui::Setting{
        .key = "ColorGradeScene",
        .binding = &shader_injection.color_grade_strength,
        .default_value = 100.f,
        .label = "Scene Grading",
        .section = COLOR_GRADING_SECTION,
        .tooltip = "Strength of the game's own color grading. Default: 100%.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return CustomToneMapActive(); },
    },

    // Bloom
    new settings_ui::Setting{
        .key = "FxBloom",
        .binding = &shader_injection.fx_bloom,
        .default_value = 50.f,
        .label = "Bloom",
        .section = BLOOM_SECTION,
        .tooltip = "Bloom strength. 50 matches the original game.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .parse = [](float value) { return value * 0.02f; },
    },
    new settings_ui::Setting{
        .key = "FxBloomMode",
        .binding = &shader_injection.fx_bloom_mode,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 1.f,
        .label = "Bloom Mode",
        .section = BLOOM_SECTION,
        .tooltip = "How bloom is combined with the scene. Default: Headroom."
                   "\nAdditive: full HDR add."
                   "\nHeadroom: bloom only fills up to SDR white like the original game."
                   "\nEnergy Conserving: blends the scene toward bloom and keeps average brightness."
                   "\nPost Tone Map: added after tone mapping, limited to UI white.",
        .labels = {"Additive", "Headroom", "Energy Conserving", "Post Tone Map"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_CRIMSON,
        .is_visible = []() { return CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "FxBloomMix",
        .binding = &shader_injection.fx_bloom_mix,
        .default_value = 10.f,
        .label = "Bloom Mix",
        .section = BLOOM_SECTION,
        .tooltip = "How far the scene is blended toward bloom. Default: 10%.",
        .tint = ui::TINT_CRIMSON,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return current_settings_mode >= 2 && CustomToneMapActive() && shader_injection.fx_bloom_mode == 2.f; },
    },
    new settings_ui::Setting{
        .key = "FxBloomSoftCap",
        .binding = &shader_injection.fx_bloom_soft_cap,
        .default_value = 0.f,
        .label = "Bloom Soft Cap",
        .section = BLOOM_SECTION,
        .tooltip = "Softly limits how bright bloom can get. 0 turns the cap off. Default: 0.",
        .tint = ui::TINT_CRIMSON,
        .min = 0.f,
        .max = 10.f,
        .format = "%.1f",
        .is_visible = []() { return current_settings_mode >= 2 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "FxBloomDarkGate",
        .binding = &shader_injection.fx_bloom_dark_gate,
        .default_value = 0.f,
        .label = "Bloom Dark Gate",
        .section = BLOOM_SECTION,
        .tooltip = "Reduces glow spilling onto dark areas. Default: 0%.",
        .tint = ui::TINT_CRIMSON,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return current_settings_mode >= 2 && CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "FxBloomHue",
        .binding = &shader_injection.bloom_hue,
        .default_value = 0.f,
        .label = "Bloom Hue",
        .section = BLOOM_SECTION,
        .tooltip = "0% keeps bloom the color of its light source. 100% matches the original game, which thresholds each color channel separately and makes bloom more saturated. Default: 0%.",
        .tint = ui::TINT_CRIMSON,
        .min = 0.f,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return CustomToneMapActive(); },
    },

    // Effects
    new settings_ui::Setting{
        .key = "FxEffectsHDR",
        .binding = &shader_injection.effects_hdr,
        .default_value = 50.f,
        .label = "Effects HDR",
        .section = EFFECTS_SECTION,
        .tooltip = "How far particles, sprites and transparent effects can go above SDR white. 0% imitates the original 8-bit clamp, 100% allows full HDR. Default: 50%.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
        .is_visible = []() { return CustomToneMapActive(); },
    },
    new settings_ui::Setting{
        .key = "FxGodRays",
        .binding = &shader_injection.fx_god_rays,
        .default_value = 50.f,
        .label = "God Rays",
        .section = EFFECTS_SECTION,
        .tooltip = "Light shaft strength. 50 matches the original game.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .parse = [](float value) { return value * 0.02f; },
    },
    new settings_ui::Setting{
        .key = "FxMotionBlur",
        .binding = &shader_injection.fx_motion_blur,
        .default_value = 100.f,
        .label = "Motion Blur",
        .section = EFFECTS_SECTION,
        .tooltip = "Motion blur amount. 100% matches the original game, 0% turns it off.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "FxDepthOfField",
        .binding = &shader_injection.fx_dof,
        .default_value = 100.f,
        .label = "Depth of Field",
        .section = EFFECTS_SECTION,
        .tooltip = "Depth of field blur. 100% matches the original game, 0% turns it off.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
    },
    new settings_ui::Setting{
        .key = "FxFog",
        .binding = &shader_injection.fx_fog,
        .default_value = 100.f,
        .label = "Fog",
        .section = EFFECTS_SECTION,
        .tooltip = "Fog and light scattering amount. 100% matches the original game, 0% turns it off.",
        .tint = ui::TINT_CRIMSON,
        .max = 100.f,
        .format = "%.0f%%",
        .parse = [](float value) { return value * 0.01f; },
    },

    // Display Output
    output_mode_setting = new settings_ui::Setting{
        .key = "OutputMode",
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 1.f,
        .can_reset = false,
        .label = "Output Mode",
        .section = DISPLAY_OUTPUT_SECTION,
        .tooltip = "SDR outputs the game's original image. HDR uses HDR10. Changing this requires a game restart. Default: HDR.",
        .labels = {"SDR", "HDR"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_CRIMSON,
        .is_global = true,
    },
    new settings_ui::Setting{
        .key = "SwapChainCustomColorSpace",
        .binding = &shader_injection.swap_chain_custom_color_space,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 0.f,
        .label = "Display Color Space",
        .section = DISPLAY_OUTPUT_SECTION,
        .tooltip = "Color space the image is mastered for. Default: US Modern."
                   "\nUS Modern: BT.709 D65."
                   "\nJPN Modern: BT.709 D93."
                   "\nUS CRT: BT.601 (NTSC-U)."
                   "\nJPN CRT: BT.601 ARIB-TR-B9 D93 (NTSC-J).",
        .labels = {"US Modern", "JPN Modern", "US CRT", "JPN CRT"},
        .tint = ui::TINT_CRIMSON,
        .is_visible = []() { return current_settings_mode >= 1; },
    },
    new settings_ui::Setting{
        .key = "DisplayCursorMode",
        .binding = &cursor_mode,
        .value_type = settings_ui::SettingValueType::INTEGER,
        .default_value = 0.f,
        .label = "Cursor",
        .section = DISPLAY_OUTPUT_SECTION,
        .tooltip = "Default: Game."
                   "\nGame: the game shows and hides the cursor as it normally does."
                   "\nHidden: the cursor is always hidden over the game. Use this if Game mode causes a black or frozen image.",
        .labels = {"Game", "Hidden"},
        .style = settings_ui::SettingStyle::SEGMENTED,
        .tint = ui::TINT_CRIMSON,
        .is_visible = []() { return current_settings_mode >= 2; },
    },

    // About
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::TEXT,
        .label = "Unofficial community HDR mod built with RenoDX. Not affiliated with Capcom.",
        .section = ABOUT_SECTION,
        .tint = ui::TINT_CRIMSON,
    },
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::TEXT,
        .label = "RenoDX by Carlos Lopez (clshortfuse) and contributors.",
        .section = ABOUT_SECTION,
        .tint = ui::TINT_CRIMSON,
    },
    new settings_ui::Setting{
        .value_type = settings_ui::SettingValueType::BUTTON,
        .label = "RenoDX Discord",
        .section = ABOUT_SECTION,
        .tint = ui::TINT_CRIMSON,
        .on_change = []() { renodx::utils::platform::LaunchURL("https://discord.gg/", "t9v7wx9NTD"); },
    },
};

void OnPresetOff() {
  settings_ui::UpdateSetting("ToneMapType", 0.f);
  settings_ui::UpdateSetting("ToneMapPeakNits", 1000.f);
  settings_ui::UpdateSetting("ToneMapGameNits", 203.f);
  settings_ui::UpdateSetting("ToneMapUINits", 203.f);
  settings_ui::UpdateSetting("ToneMapHueShift", 0.f);
  settings_ui::UpdateSetting("ToneMapHighlightHue", 100.f);
  settings_ui::UpdateSetting("ColorGradeExposure", 1.f);
  settings_ui::UpdateSetting("ColorGradeHighlights", 50.f);
  settings_ui::UpdateSetting("ColorGradeShadows", 50.f);
  settings_ui::UpdateSetting("ColorGradeContrast", 50.f);
  settings_ui::UpdateSetting("ColorGradeSaturation", 50.f);
  settings_ui::UpdateSetting("ColorGradeHighlightSaturation", 50.f);
  settings_ui::UpdateSetting("ColorGradeBlowout", 0.f);
  settings_ui::UpdateSetting("ColorGradeFlare", 0.f);
  settings_ui::UpdateSetting("ColorGradeScene", 100.f);
  settings_ui::UpdateSetting("FxBloom", 50.f);
  settings_ui::UpdateSetting("FxGodRays", 50.f);
  settings_ui::UpdateSetting("FxMotionBlur", 100.f);
  settings_ui::UpdateSetting("FxDepthOfField", 100.f);
  settings_ui::UpdateSetting("FxFog", 100.f);
  settings_ui::UpdateSetting("FxEffectsHDR", 50.f);
  settings_ui::UpdateSetting("FxBloomHue", 0.f);
  settings_ui::UpdateSetting("FxBloomMode", 0.f);
  settings_ui::UpdateSetting("FxBloomMix", 0.f);
  settings_ui::UpdateSetting("FxBloomSoftCap", 0.f);
  settings_ui::UpdateSetting("FxBloomDarkGate", 0.f);
  settings_ui::UpdateSetting("DisplayCursorMode", 0.f);
}

bool initialized = false;

// The game's D3D10 swapchain is blt-model; a flip swapchain on the same HWND deadlocks its Present in DWM
// (DwmpDxGetWindowSharedSurface). The proxy swapchain gets its own borderless window laid over the game's client area.
// The window lives on a dedicated thread with its own message loop: the render thread blocks in Present while DWM waits
// on it, so a window owned by that thread would never process messages.
std::atomic<HWND> proxy_output_window = nullptr;
std::atomic<HWND> proxy_game_window = nullptr;
constexpr UINT_PTR PROXY_SYNC_TIMER_ID = 1;
constexpr UINT PROXY_SYNC_INTERVAL_MS = 16;

// Sets the calling thread's DPI awareness to the game window's for the scope, so rects and the overlay window are in the
// game's coordinate space. The APIs need Windows 10 1607+; without them this is a no-op.
struct ScopedGameDpiAwareness {
  using GetWindowDpiAwarenessContextFn = DPI_AWARENESS_CONTEXT(WINAPI*)(HWND);
  using SetThreadDpiAwarenessContextFn = DPI_AWARENESS_CONTEXT(WINAPI*)(DPI_AWARENESS_CONTEXT);

  SetThreadDpiAwarenessContextFn set_thread_context = nullptr;
  DPI_AWARENESS_CONTEXT previous_context = nullptr;

  explicit ScopedGameDpiAwareness(HWND game_hwnd) {
    const HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (user32 == nullptr) return;
    const auto get_window_context =
        reinterpret_cast<GetWindowDpiAwarenessContextFn>(GetProcAddress(user32, "GetWindowDpiAwarenessContext"));
    const auto set_context =
        reinterpret_cast<SetThreadDpiAwarenessContextFn>(GetProcAddress(user32, "SetThreadDpiAwarenessContext"));
    if (get_window_context == nullptr || set_context == nullptr) return;
    const DPI_AWARENESS_CONTEXT game_context = get_window_context(game_hwnd);
    if (game_context == nullptr) return;
    previous_context = set_context(game_context);
    if (previous_context != nullptr) set_thread_context = set_context;
  }

  ~ScopedGameDpiAwareness() {
    if (set_thread_context != nullptr) set_thread_context(previous_context);
  }

  ScopedGameDpiAwareness(const ScopedGameDpiAwareness&) = delete;
  ScopedGameDpiAwareness& operator=(const ScopedGameDpiAwareness&) = delete;
};

bool GetGameClientScreenRect(HWND game_hwnd, RECT* rect) {
  RECT client_rect = {};
  POINT origin = {0, 0};
  if (GetClientRect(game_hwnd, &client_rect) == FALSE || ClientToScreen(game_hwnd, &origin) == FALSE) return false;
  *rect = {origin.x, origin.y, origin.x + std::max<LONG>(1, client_rect.right - client_rect.left),
           origin.y + std::max<LONG>(1, client_rect.bottom - client_rect.top)};
  return true;
}

// Keeps the overlay over the game's client area and directly above the game window in z-order, hidden while the game is
// minimized or hidden. Stateless and non-blocking (async SetWindowPos), so it is callable from any thread.
void UpdateProxyOutputWindow(HWND hwnd, HWND game_hwnd) {
  constexpr UINT BASE_FLAGS = SWP_NOACTIVATE | SWP_ASYNCWINDOWPOS;
  const ScopedGameDpiAwareness game_dpi(game_hwnd);
  const bool shown = IsWindowVisible(hwnd) != FALSE;
  RECT target = {};
  if (IsIconic(game_hwnd) != FALSE || IsWindowVisible(game_hwnd) == FALSE || !GetGameClientScreenRect(game_hwnd, &target)) {
    if (shown) SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, BASE_FLAGS | SWP_HIDEWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER);
    return;
  }

  RECT current = {};
  GetWindowRect(hwnd, &current);
  const bool rect_ok = memcmp(&current, &target, sizeof(RECT)) == 0;
  HWND above_game = GetWindow(game_hwnd, GW_HWNDPREV);
  const bool z_ok = above_game == hwnd;
  if (shown && rect_ok && z_ok) return;

  UINT flags = BASE_FLAGS;
  if (!shown) flags |= SWP_SHOWWINDOW;
  if (rect_ok) flags |= SWP_NOMOVE | SWP_NOSIZE;
  if (z_ok) flags |= SWP_NOZORDER;
  SetWindowPos(hwnd, above_game != nullptr ? above_game : HWND_TOP, target.left, target.top, target.right - target.left,
               target.bottom - target.top, flags);
}

// ReShade routes input by message HWND (input.cpp handle_window_message), and the game's keyboard focus stays on the game
// window (the overlay is never activated: the game fakes exclusive fullscreen and minimizes when deactivated), so the
// proxy runtime on the overlay window never sees keys. The game window's wndproc is subclassed to post key messages to the
// overlay window (this thread's hooked GetMessage hands them to the proxy runtime's input). While the proxy overlay is
// open they are also swallowed for the game, and the overlay takes mouse input directly (HTCLIENT).
std::atomic<bool> proxy_overlay_open = false;
HWND subclassed_game_window = nullptr;
WNDPROC original_game_wndproc = nullptr;

LRESULT CALLBACK GameWindowProc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param) {
  const auto CallAndSyncOverlay = [&] {
    const LRESULT result = CallWindowProcW(original_game_wndproc, hwnd, message, w_param, l_param);
    if (HWND overlay_hwnd = proxy_output_window; overlay_hwnd != nullptr) UpdateProxyOutputWindow(overlay_hwnd, hwnd);
    return result;
  };
  switch (message) {
    case WM_KEYDOWN:
    case WM_KEYUP:
    case WM_SYSKEYDOWN:
    case WM_SYSKEYUP:
    case WM_CHAR:
    case WM_SYSCHAR:
      if (HWND overlay_hwnd = proxy_output_window; overlay_hwnd != nullptr) {
        PostMessageW(overlay_hwnd, message, w_param, l_param);
        if (proxy_overlay_open) return 0;
      }
      break;
    case WM_WINDOWPOSCHANGED:
    case WM_MOVE:
    case WM_SIZE:
    case WM_MOVING:
    case WM_SIZING:
      // Follow immediately, including during the modal move/size loop; the overlay timer is only a fallback.
      return CallAndSyncOverlay();
    case WM_ACTIVATEAPP:
      if (w_param != FALSE) return CallAndSyncOverlay();
      break;
    case WM_ACTIVATE:
      // Re-assert z-order so no other window stays between the game and the overlay after focus changes.
      if (LOWORD(w_param) != WA_INACTIVE) return CallAndSyncOverlay();
      break;
    default:
      break;
  }
  return CallWindowProcW(original_game_wndproc, hwnd, message, w_param, l_param);
}

// Only unhooks while this wndproc is still the outermost; if another hook wrapped it, it stays and passes through.
void RestoreGameWindowProc() {
  if (subclassed_game_window == nullptr) return;
  if (GetWindowLongPtrW(subclassed_game_window, GWLP_WNDPROC) == reinterpret_cast<LONG_PTR>(GameWindowProc)) {
    SetWindowLongPtrW(subclassed_game_window, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(original_game_wndproc));
    subclassed_game_window = nullptr;
  }
}

constexpr UINT WM_PROXY_REFRESH_CURSOR = WM_APP + 1;
constexpr const wchar_t* PROXY_WINDOW_CLASS_NAME = L"RenoDXDMC4ProxyOutputWindow";
bool proxy_class_registered = false;
std::thread proxy_window_thread;
std::atomic<bool> proxy_window_thread_done = true;
// Only touched on the overlay thread.
thread_local bool proxy_cursor_hidden = false;
thread_local bool proxy_click_through = false;

// Game mode: while the ReShade menu is closed the overlay is click-through (WS_EX_TRANSPARENT, which needs WS_EX_LAYERED
// and works across threads), so mouse and cursor belong to the game. Hidden mode: the overlay keeps the mouse and hides
// the cursor with this thread's display count. Idempotent; runs on the overlay thread.
void ApplyOverlayCursorState(HWND hwnd) {
  const bool game_mode = cursor_mode == 0.f;
  const bool want_click_through = game_mode && !proxy_overlay_open;
  if (want_click_through != proxy_click_through) {
    const LONG ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);
    SetWindowLongW(hwnd, GWL_EXSTYLE, want_click_through ? (ex_style | WS_EX_TRANSPARENT) : (ex_style & ~WS_EX_TRANSPARENT));
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_ASYNCWINDOWPOS);
    proxy_click_through = want_click_through;
  }
  // The display count is per thread, so only this thread's count decides visibility over the overlay.
  const bool want_hidden = !game_mode && !proxy_overlay_open;
  if (want_hidden && !proxy_cursor_hidden) {
    while (ShowCursor(FALSE) >= 0) {}
    proxy_cursor_hidden = true;
  } else if (!want_hidden && proxy_cursor_hidden) {
    while (ShowCursor(TRUE) < 0) {}
    proxy_cursor_hidden = false;
  }
}

LRESULT CALLBACK ProxyOutputWindowProc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param) {
  // Pass mouse input through to the game window underneath while the overlay is closed. Never activate: that would
  // deactivate the game, which minimizes itself.
  if (message == WM_NCHITTEST) return proxy_overlay_open ? HTCLIENT : HTTRANSPARENT;
  if (message == WM_MOUSEACTIVATE) return MA_NOACTIVATE;
  // HTTRANSPARENT only passes through to windows of the same thread. In Game mode the click-through style routes the
  // cursor to the game while the menu is closed; otherwise the overlay owns it (arrow while open, hidden in Hidden mode).
  if (message == WM_SETCURSOR && (proxy_overlay_open || cursor_mode != 0.f)) {
    SetCursor(proxy_overlay_open ? LoadCursorW(nullptr, MAKEINTRESOURCEW(32512)) : nullptr);  // IDC_ARROW
    return TRUE;
  }
  // Re-applies the cursor without mouse movement: SetCursorPos to the current position makes the system re-send
  // WM_SETCURSOR to the window under the cursor.
  if (message == WM_PROXY_REFRESH_CURSOR) {
    ApplyOverlayCursorState(hwnd);
    if (proxy_overlay_open || cursor_mode != 0.f) {
      SetCursor(proxy_overlay_open ? LoadCursorW(nullptr, MAKEINTRESOURCEW(32512)) : nullptr);  // IDC_ARROW
    }
    if (POINT cursor_position = {}; GetCursorPos(&cursor_position) != FALSE) SetCursorPos(cursor_position.x, cursor_position.y);
    return 0;
  }
  // Follows the game window even when it does not present (e.g. during the modal move loop of a title-bar drag).
  if (message == WM_TIMER && w_param == PROXY_SYNC_TIMER_ID) {
    ApplyOverlayCursorState(hwnd);  // Picks up Cursor setting changes (including Reset All) without an extra message.
    if (HWND game_hwnd = proxy_game_window; game_hwnd != nullptr) UpdateProxyOutputWindow(hwnd, game_hwnd);
    return 0;
  }
  if (message == WM_DESTROY) PostQuitMessage(0);
  return DefWindowProcW(hwnd, message, w_param, l_param);
}

// Joins the overlay thread after a bounded wait when allowed. Otherwise (DLL detach holds the loader lock, or the thread
// is stuck) the thread is detached and exits on its own after WM_DESTROY.
void JoinProxyWindowThread(bool can_wait) {
  if (!proxy_window_thread.joinable()) return;
  for (int waited_ms = 0; can_wait && !proxy_window_thread_done && waited_ms < 2000; waited_ms += 10) Sleep(10);
  if (can_wait && proxy_window_thread_done) {
    proxy_window_thread.join();
  } else {
    proxy_window_thread.detach();
  }
}

void CloseProxyOutputWindow(bool can_wait) {
  renodx::utils::device_proxy::local_proxy_swapchain_hwnd_override = 0;
  proxy_game_window = nullptr;
  RestoreGameWindowProc();
  if (HWND hwnd = proxy_output_window.exchange(nullptr); hwnd != nullptr) PostMessageW(hwnd, WM_CLOSE, 0, 0);
  JoinProxyWindowThread(can_wait);
  // Fails harmlessly while a window of the class still exists.
  if (proxy_class_registered && FindWindowW(PROXY_WINDOW_CLASS_NAME, nullptr) == nullptr) {
    proxy_class_registered = !UnregisterClassW(PROXY_WINDOW_CLASS_NAME, GetModuleHandleW(nullptr));
  }
}

void SyncProxyOutputWindow(HWND game_hwnd) {
  proxy_game_window = game_hwnd;
  if (subclassed_game_window != game_hwnd) {
    RestoreGameWindowProc();
    if (subclassed_game_window == nullptr) {
      original_game_wndproc =
          reinterpret_cast<WNDPROC>(SetWindowLongPtrW(game_hwnd, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(GameWindowProc)));
      subclassed_game_window = game_hwnd;
    }
  }
  HWND hwnd = proxy_output_window;
  if (hwnd == nullptr) {
    RECT rect = {};
    {
      const ScopedGameDpiAwareness game_dpi(game_hwnd);
      if (!GetGameClientScreenRect(game_hwnd, &rect)) return;
    }
    std::promise<HWND> created;
    std::future<HWND> created_future = created.get_future();
    // A previous thread is already finished or detached by CloseProxyOutputWindow; never assign over a joinable one.
    JoinProxyWindowThread(true);
    proxy_window_thread_done = false;
    proxy_window_thread = std::thread([&created, rect, game_hwnd] {
      // The thread only owns the overlay, so its awareness stays set to the game window's for its lifetime.
      const ScopedGameDpiAwareness game_dpi(game_hwnd);
      const HINSTANCE instance = GetModuleHandleW(nullptr);
      if (!proxy_class_registered) {
        WNDCLASSEXW window_class = {};
        window_class.cbSize = sizeof(window_class);
        window_class.lpfnWndProc = ProxyOutputWindowProc;
        window_class.hInstance = instance;
        window_class.lpszClassName = PROXY_WINDOW_CLASS_NAME;
        proxy_class_registered = RegisterClassExW(&window_class) != 0;
      }

      HWND window = CreateWindowExW(
          WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_LAYERED, PROXY_WINDOW_CLASS_NAME, L"RenoDX Device Proxy Output", WS_POPUP,
          rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top, nullptr, nullptr, instance, nullptr);
      if (window != nullptr) {
        // Layered at creation, before the swapchain exists; it stays layered in both modes.
        SetLayeredWindowAttributes(window, 0, 255, LWA_ALPHA);
        ApplyOverlayCursorState(window);
        ShowWindow(window, SW_SHOWNOACTIVATE);
        SetTimer(window, PROXY_SYNC_TIMER_ID, PROXY_SYNC_INTERVAL_MS, nullptr);
      }
      created.set_value(window);  // `created` is not touched after this point.
      if (window != nullptr) {
        MSG msg = {};
        while (GetMessageW(&msg, nullptr, 0u, 0u) > 0) {
          TranslateMessage(&msg);
          DispatchMessageW(&msg);
        }
      }
      proxy_window_thread_done = true;
    });

    hwnd = created_future.get();
    if (hwnd == nullptr) {
      reshade::log::message(reshade::log::level::error, "dmc4se: failed to create proxy output window");
      return;
    }
    proxy_output_window = hwnd;
    renodx::utils::device_proxy::local_proxy_swapchain_hwnd_override = reinterpret_cast<uintptr_t>(hwnd);
  }

  UpdateProxyOutputWindow(hwnd, game_hwnd);
}

// The game's D3D10 runtime and the proxy runtime would both open an overlay; keep only the proxy's.
bool OnOpenOverlay(reshade::api::effect_runtime* runtime, bool open, reshade::api::input_source /*source*/) {
  if (!renodx::utils::device_proxy::IsProxyDevice(runtime->get_device())) return open;
  proxy_overlay_open = open;
  if (HWND overlay_hwnd = proxy_output_window; overlay_hwnd != nullptr) PostMessageW(overlay_hwnd, WM_PROXY_REFRESH_CURSOR, 0, 0);
  return false;
}

// With fullscreen faked, the swapchain does not own its output, so the game's per-frame gamma calls on that output fail
// with INVALID_CALL and the game exits ("ERR09"). The IDXGIOutput vtable is shared by every output in the process, so each
// hook calls the original first and only maps those two failures to success (zero gamma control points).
using GetGammaControlCapabilitiesFn = HRESULT(STDMETHODCALLTYPE*)(IDXGIOutput*, DXGI_GAMMA_CONTROL_CAPABILITIES*);
using SetGammaControlFn = HRESULT(STDMETHODCALLTYPE*)(IDXGIOutput*, const DXGI_GAMMA_CONTROL*);
using GetGammaControlFn = HRESULT(STDMETHODCALLTYPE*)(IDXGIOutput*, DXGI_GAMMA_CONTROL*);

constexpr std::size_t OUTPUT_VTABLE_GET_GAMMA_CONTROL_CAPABILITIES = 13;
constexpr std::size_t OUTPUT_VTABLE_SET_GAMMA_CONTROL = 14;
constexpr std::size_t OUTPUT_VTABLE_GET_GAMMA_CONTROL = 15;

GetGammaControlCapabilitiesFn original_get_gamma_control_capabilities = nullptr;
SetGammaControlFn original_set_gamma_control = nullptr;
GetGammaControlFn original_get_gamma_control = nullptr;
std::atomic<bool> gamma_remap_logged = false;

bool IsRemappedGammaError(HRESULT result) {
  if (result != DXGI_ERROR_INVALID_CALL && result != DXGI_ERROR_NOT_CURRENTLY_AVAILABLE) return false;
  if (!gamma_remap_logged.exchange(true)) {
    reshade::log::message(reshade::log::level::info, "dmc4se: remapped failing IDXGIOutput gamma call to S_OK");
  }
  return true;
}

HRESULT STDMETHODCALLTYPE HookGetGammaControlCapabilities(IDXGIOutput* output, DXGI_GAMMA_CONTROL_CAPABILITIES* caps) {
  const HRESULT result = original_get_gamma_control_capabilities(output, caps);
  if (!IsRemappedGammaError(result)) return result;
  if (caps != nullptr) *caps = {};
  return S_OK;
}

HRESULT STDMETHODCALLTYPE HookSetGammaControl(IDXGIOutput* output, const DXGI_GAMMA_CONTROL* control) {
  const HRESULT result = original_set_gamma_control(output, control);
  return IsRemappedGammaError(result) ? S_OK : result;
}

HRESULT STDMETHODCALLTYPE HookGetGammaControl(IDXGIOutput* output, DXGI_GAMMA_CONTROL* control) {
  const HRESULT result = original_get_gamma_control(output, control);
  return IsRemappedGammaError(result) ? S_OK : result;
}

renodx::utils::vtable::Slot<GetGammaControlCapabilitiesFn> get_gamma_control_capabilities_slot = {
    .index = OUTPUT_VTABLE_GET_GAMMA_CONTROL_CAPABILITIES,
    .original = &original_get_gamma_control_capabilities,
    .replacement = HookGetGammaControlCapabilities,
};
renodx::utils::vtable::Slot<SetGammaControlFn> set_gamma_control_slot = {
    .index = OUTPUT_VTABLE_SET_GAMMA_CONTROL,
    .original = &original_set_gamma_control,
    .replacement = HookSetGammaControl,
};
renodx::utils::vtable::Slot<GetGammaControlFn> get_gamma_control_slot = {
    .index = OUTPUT_VTABLE_GET_GAMMA_CONTROL,
    .original = &original_get_gamma_control,
    .replacement = HookGetGammaControl,
};

void InstallOutputGammaHooks(IDXGISwapChain* native_swapchain) {
  if (get_gamma_control_capabilities_slot.installed_address != nullptr) return;

  IDXGIOutput* output = nullptr;
  if (FAILED(native_swapchain->GetContainingOutput(&output)) || output == nullptr) {
    reshade::log::message(reshade::log::level::warning, "dmc4se: GetContainingOutput failed; gamma hooks not installed");
    return;
  }

  get_gamma_control_capabilities_slot.object = output;
  set_gamma_control_slot.object = output;
  get_gamma_control_slot.object = output;
  try {
    renodx::utils::vtable::Install(&get_gamma_control_capabilities_slot);
    renodx::utils::vtable::Install(&set_gamma_control_slot);
    renodx::utils::vtable::Install(&get_gamma_control_slot);
    reshade::log::message(reshade::log::level::info, "dmc4se: installed IDXGIOutput gamma hooks");
  } catch (const std::exception& error) {
    reshade::log::message(reshade::log::level::error, error.what());
  }
  output->Release();
}

void UninstallOutputGammaHooks() {
  try {
    if (get_gamma_control_capabilities_slot.installed_address != nullptr) {
      renodx::utils::vtable::Uninstall(&get_gamma_control_capabilities_slot);
    }
    if (set_gamma_control_slot.installed_address != nullptr) renodx::utils::vtable::Uninstall(&set_gamma_control_slot);
    if (get_gamma_control_slot.installed_address != nullptr) renodx::utils::vtable::Uninstall(&get_gamma_control_slot);
  } catch (const std::exception&) {
    // Another writer replaced a slot; leave it alone.
  }
}

// Runs before the swapchain mod's handlers (registered earlier), so the override is set before the proxy is created.
void OnInitSwapChain(reshade::api::swapchain* swapchain, bool /*resize*/) {
  if (swapchain->get_device()->get_api() != reshade::api::device_api::d3d10) return;
  SyncProxyOutputWindow(static_cast<HWND>(swapchain->get_hwnd()));
  InstallOutputGammaHooks(reinterpret_cast<IDXGISwapChain*>(swapchain->get_native()));
}

void OnDestroySwapChain(reshade::api::swapchain* swapchain, bool resize) {
  if (resize || swapchain->get_device()->get_api() != reshade::api::device_api::d3d10) return;
  CloseProxyOutputWindow(true);
}

// Tone mapping state for the current frame, driven by the on_draw callbacks attached in DllMain.
bool tone_mapped = false;
bool stage_seen = false;
bool clamp_seen = false;
// Last frame ran a clamp shader without any tone-map or grade stage, so the clamp shader must tone map.
bool fallback_active = false;

// Gameplay bloom texture captured at 0xC74A047B for the Post Tone Map mode; bound to the grade draws as t7.
ID3D10ShaderResourceView* bloom_srv = nullptr;
ID3D10SamplerState* linear_clamp_sampler = nullptr;

void ReleaseBloomResources() {
  if (bloom_srv != nullptr) {
    bloom_srv->Release();
    bloom_srv = nullptr;
  }
  if (linear_clamp_sampler != nullptr) {
    linear_clamp_sampler->Release();
    linear_clamp_sampler = nullptr;
  }
}

void OnPresent(reshade::api::command_queue* queue, reshade::api::swapchain* swapchain, const reshade::api::rect*,
               const reshade::api::rect*, uint32_t, const reshade::api::rect*) {
  if (queue->get_device()->get_api() != reshade::api::device_api::d3d10) return;
  fallback_active = clamp_seen && !stage_seen;
  tone_mapped = false;
  stage_seen = false;
  clamp_seen = false;
  if (bloom_srv != nullptr) {
    bloom_srv->Release();
    bloom_srv = nullptr;
  }
  if (proxy_output_window == nullptr) return;
  SyncProxyOutputWindow(static_cast<HWND>(swapchain->get_hwnd()));
}

}  // namespace

extern "C" __declspec(dllexport) constexpr const char* NAME = "RenoDX Devil May Cry 4 SE";
extern "C" __declspec(dllexport) constexpr const char* DESCRIPTION = "RenoDX for Devil May Cry 4 Special Edition";

BOOL APIENTRY DllMain(HMODULE h_module, DWORD fdw_reason, LPVOID lpv_reserved) {
  switch (fdw_reason) {
    case DLL_PROCESS_ATTACH:
      if (!reshade::register_addon(h_module)) return FALSE;

      if (!initialized) {
        renodx::mods::shader::force_pipeline_cloning = true;
        renodx::mods::shader::expected_constant_buffer_index = 13;

        renodx::mods::swapchain::expected_constant_buffer_index = 13;
        renodx::mods::swapchain::expected_constant_buffer_space = 50;
        renodx::mods::swapchain::use_resource_cloning = true;
        // The proxy pass runs on the D3D11 proxy device, so one dx11 pair serves every device.
        renodx::mods::swapchain::swap_chain_proxy_vertex_shader = __swap_chain_proxy_vertex_shader_dx11;
        renodx::mods::swapchain::swap_chain_proxy_pixel_shader = __swap_chain_proxy_pixel_shader_dx11;

        // Faking fullscreen makes DMC4 abort with "ERR09: Unsupported function"; the game runs windowed.
        renodx::mods::swapchain::prevent_full_screen = false;
        renodx::mods::swapchain::force_borderless = false;

        // Output is always HDR10 when the proxy is on.
        renodx::mods::swapchain::SetUseHDR10(true);
        renodx::mods::swapchain::use_resize_buffer = false;
        shader_injection.swap_chain_encoding = 4.f;
        shader_injection.swap_chain_encoding_color_space = 1.f;
        // Fixed values for settings that are not exposed: BT.709 tone map working space, no tone map gamut or
        // peak clamp, BT.709 clamp on the final output, no extra swapchain gamma.
        shader_injection.tone_map_working_color_space = 0.f;
        shader_injection.tone_map_clamp_color_space = -1.f;
        shader_injection.tone_map_clamp_peak = -1.f;
        shader_injection.swap_chain_clamp_color_space = 1.f;
        shader_injection.swap_chain_gamma_correction = 0.f;

        reshade::register_event<reshade::addon_event::present>(OnPresent);

        for (const uint32_t hash : {0x477DAFFDu, 0x12C6EEF6u, 0x1F5E2CA1u, 0x4720902Eu, 0xBDEC6F70u, 0xEE471F97u,
                                    0x18668485u, 0x2447C070u, 0x652CD5F4u, 0xD5A3CB40u, 0x4761E045u}) {
          custom_shaders.at(hash).on_draw = [](auto*) {
            tone_mapped = true;
            stage_seen = true;
            return true;
          };
        }
        custom_shaders.at(0xC74A047Bu).on_draw = [](reshade::api::command_list* cmd_list) {
          if (cmd_list->get_device()->get_api() != reshade::api::device_api::d3d10) return true;
          auto* device = reinterpret_cast<ID3D10Device*>(cmd_list->get_native());
          if (bloom_srv != nullptr) {
            bloom_srv->Release();
            bloom_srv = nullptr;
          }
          device->PSGetShaderResources(1, 1, &bloom_srv);
          return true;
        };
        for (const uint32_t hash : {0x35B6E686u, 0x6CDE02C8u}) {
          custom_shaders.at(hash).on_draw = [](reshade::api::command_list* cmd_list) {
            shader_injection.custom_tone_mapped = tone_mapped ? 1.f : 0.f;
            tone_mapped = true;
            stage_seen = true;

            const bool bind_bloom = shader_injection.fx_bloom_mode == 3.f && bloom_srv != nullptr &&
                                    cmd_list->get_device()->get_api() == reshade::api::device_api::d3d10;
            if (bind_bloom) {
              auto* device = reinterpret_cast<ID3D10Device*>(cmd_list->get_native());
              if (linear_clamp_sampler == nullptr) {
                const D3D10_SAMPLER_DESC sampler_desc = {
                    .Filter = D3D10_FILTER_MIN_MAG_MIP_LINEAR,
                    .AddressU = D3D10_TEXTURE_ADDRESS_CLAMP,
                    .AddressV = D3D10_TEXTURE_ADDRESS_CLAMP,
                    .AddressW = D3D10_TEXTURE_ADDRESS_CLAMP,
                    .MaxAnisotropy = 1,
                    .ComparisonFunc = D3D10_COMPARISON_NEVER,
                    .MaxLOD = D3D10_FLOAT32_MAX,
                };
                device->CreateSamplerState(&sampler_desc, &linear_clamp_sampler);
              }
              device->PSSetShaderResources(7, 1, &bloom_srv);
              device->PSSetSamplers(7, 1, &linear_clamp_sampler);
            }
            shader_injection.custom_bloom_bound = bind_bloom ? 1.f : 0.f;
            return true;
          };
          // Never leave the bloom texture bound as an SRV while it is a render target.
          custom_shaders.at(hash).on_drawn = [](reshade::api::command_list* cmd_list) {
            if (cmd_list->get_device()->get_api() != reshade::api::device_api::d3d10) return;
            auto* device = reinterpret_cast<ID3D10Device*>(cmd_list->get_native());
            ID3D10ShaderResourceView* null_srv = nullptr;
            device->PSSetShaderResources(7, 1, &null_srv);
          };
        }
        for (const uint32_t hash : {0xE7663907u, 0xEA86D828u, 0xA428D54Bu}) {
          custom_shaders.at(hash).on_draw = [](auto*) {
            clamp_seen = true;
            const bool tone_map_here = fallback_active && !tone_mapped;
            shader_injection.custom_clamp_tone_map = tone_map_here ? 1.f : 0.f;
            if (tone_map_here) tone_mapped = true;
            return true;
          };
        }

        if (const char* local_app_data = std::getenv("LOCALAPPDATA"); local_app_data != nullptr) {
          const std::string config_path =
              std::string(local_app_data) + "\\CAPCOM\\DEVILMAYCRY4SPECIALEDITION\\config.ini";
          char anti_alias[32] = {};
          GetPrivateProfileStringA("GRAPHICS", "AntiAlias", "", anti_alias, sizeof(anti_alias), config_path.c_str());
          csaa_enabled = std::strncmp(anti_alias, "CSAA", 4) == 0;
        }

        output_mode_setting->ReadFromConfig(renodx::utils::settings::global_name);
        const bool use_device_proxy = output_mode_setting->GetValue() == 1.f;
        renodx::mods::swapchain::use_device_proxy = use_device_proxy;
        renodx::mods::swapchain::set_color_space = !use_device_proxy;
        if (use_device_proxy) {
          reshade::register_event<reshade::addon_event::init_swapchain>(OnInitSwapChain);
          reshade::register_event<reshade::addon_event::destroy_swapchain>(OnDestroySwapChain);
          reshade::register_event<reshade::addon_event::reshade_open_overlay>(OnOpenOverlay);
          // Main Render
          renodx::mods::swapchain::swap_chain_upgrade_targets.push_back({
              .old_format = reshade::api::format::r8g8b8a8_unorm,
              .new_format = reshade::api::format::r16g16b16a16_float,
              .aspect_ratio = static_cast<float>(renodx::mods::swapchain::SwapChainUpgradeTarget::BACK_BUFFER),
              .usage_include = reshade::api::resource_usage::render_target,
          });
          // The game's Aspect option crops all scene/filter targets to that aspect (width rounded down to a multiple
          // of 8), so the back buffer ratio no longer matches. The tolerance covers the rounding and half/quarter sizes
          // while keeping 16:9 and 16:10 apart.
          for (const float aspect_ratio : {16.f / 9.f, 16.f / 10.f, 4.f / 3.f}) {
            renodx::mods::swapchain::swap_chain_upgrade_targets.push_back({
                .old_format = reshade::api::format::r8g8b8a8_unorm,
                .new_format = reshade::api::format::r16g16b16a16_float,
                .aspect_ratio = aspect_ratio,
                .aspect_ratio_tolerance = 0.02f,
                .usage_include = reshade::api::resource_usage::render_target,
            });
          }
        } else {
          // SDR leaves the game's D3D10 swapchain untouched; a D3D11 device here is the DevKit proxy.
          renodx::mods::swapchain::ignored_device_apis = {reshade::api::device_api::d3d10, reshade::api::device_api::d3d11};
        }

        initialized = true;
      }

      break;
    case DLL_PROCESS_DETACH:
      reshade::unregister_event<reshade::addon_event::init_swapchain>(OnInitSwapChain);
      reshade::unregister_event<reshade::addon_event::destroy_swapchain>(OnDestroySwapChain);
      reshade::unregister_event<reshade::addon_event::present>(OnPresent);
      reshade::unregister_event<reshade::addon_event::reshade_open_overlay>(OnOpenOverlay);
      CloseProxyOutputWindow(false);  // Loader lock: post only, never wait.
      UninstallOutputGammaHooks();
      ReleaseBloomResources();
      reshade::unregister_addon(h_module);
      break;
  }

  renodx::utils::settings::Use(fdw_reason, &settings, &OnPresetOff);
  renodx::mods::swapchain::Use(fdw_reason, &shader_injection);
  renodx::mods::shader::Use(fdw_reason, custom_shaders, &shader_injection);

  return TRUE;
}
