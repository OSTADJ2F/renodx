#ifndef SRC_DMC4SE_AA_LUMA_HLSLI_
#define SRC_DMC4SE_AA_LUMA_HLSLI_

#include "./shared.h"

// Edge-test luma for the AA passes. The vanilla thresholds assume 0..1 input, so
// when RenoDX tone mapping is active the luma is taken from saturate()d values.
// Only the tests use it; the blended output color stays unclamped.
float AAEdgeValue(float value) {
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) return value;
  return saturate(value);
}

float AAColorLuma(float3 color) {
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) return dot(color, float3(0.299, 0.587, 0.114));
  return dot(saturate(color), float3(0.299, 0.587, 0.114));
}

#endif  // SRC_DMC4SE_AA_LUMA_HLSLI_
