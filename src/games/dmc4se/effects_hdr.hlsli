#ifndef SRC_DMC4SE_EFFECTS_HDR_HLSLI_
#define SRC_DMC4SE_EFFECTS_HDR_HLSLI_

#include "./shared.h"

// Effect shaders relied on the 8-bit render target clamp. Vanilla (or no RenoDX tone mapping)
// keeps that clamp; otherwise RENODX_EFFECTS_HDR blends towards the unclamped colour.
float4 ApplyEffectsHDR(float4 c) {
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) {
    return saturate(c);
  }
  return float4(lerp(saturate(c.rgb), max(c.rgb, 0), RENODX_EFFECTS_HDR), saturate(c.a));
}

// min(v, 1) on vertex colour, relaxed by RENODX_EFFECTS_HDR when tone mapping is active.
float3 ClampVertexColorHDR(float3 v) {
  float3 clamped = min(float3(1, 1, 1), v);
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) {
    return clamped;
  }
  return lerp(clamped, v, RENODX_EFFECTS_HDR);
}

#endif  // SRC_DMC4SE_EFFECTS_HDR_HLSLI_
