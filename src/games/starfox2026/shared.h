#ifndef SRC_GAMES_STARFOX2026_SHARED_H_
#define SRC_GAMES_STARFOX2026_SHARED_H_

#define RENODX_TONE_MAP_TYPE_VANILLA 0.f
#define RENODX_TONE_MAP_TYPE_PSYCHOV35 9.f
#define RENODX_COLOR_REFERENCE_PSYCHOV35 0.f
#define RENODX_COLOR_REFERENCE_GAME_HDR 1.f
#define RENODX_COLOR_REFERENCE_GAME_SDR 2.f

struct ShaderInjectData {
  float tone_map_type;
  float peak_white_nits;
  float diffuse_white_nits;
  float ui_nits;
  float color_reference;
  float hue_strength;
  float chroma_strength;
};

#ifdef __cplusplus
static_assert(sizeof(ShaderInjectData) == 7u * sizeof(float));
#else
#ifdef RENODX_STARFOX_PROBE
// Standalone probe build: injected values hardcoded to the addon defaults.
#define RENODX_TONE_MAP_TYPE RENODX_TONE_MAP_TYPE_PSYCHOV35
#define RENODX_PEAK_WHITE_NITS 1000.f
#define RENODX_DIFFUSE_WHITE_NITS 203.f
#define RENODX_UI_NITS 310.f
#ifndef RENODX_COLOR_REFERENCE
#define RENODX_COLOR_REFERENCE RENODX_COLOR_REFERENCE_GAME_HDR
#endif
#define RENODX_HUE_STRENGTH 100.f
#define RENODX_CHROMA_STRENGTH 100.f
#else
// Injected constants: space 1 / slot 4 (set 1 / binding 4). The native shader uses set 0 only.
layout(set = 1, binding = 4, scalar) uniform StarFoxShaderConstants {
  ShaderInjectData shader_injection;
} starfox_constants;
#define shader_injection starfox_constants.shader_injection
#define RENODX_TONE_MAP_TYPE shader_injection.tone_map_type
#define RENODX_PEAK_WHITE_NITS shader_injection.peak_white_nits
#define RENODX_DIFFUSE_WHITE_NITS shader_injection.diffuse_white_nits
#define RENODX_UI_NITS shader_injection.ui_nits
#define RENODX_COLOR_REFERENCE shader_injection.color_reference
#define RENODX_HUE_STRENGTH shader_injection.hue_strength
#define RENODX_CHROMA_STRENGTH shader_injection.chroma_strength
#endif
#include "../../shaders/renodx.hlsl"
#endif

#endif  // SRC_GAMES_STARFOX2026_SHARED_H_
