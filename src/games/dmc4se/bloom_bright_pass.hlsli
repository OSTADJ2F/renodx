#ifndef SRC_DMC4SE_BLOOM_BRIGHT_PASS_HLSLI_
#define SRC_DMC4SE_BLOOM_BRIGHT_PASS_HLSLI_

#include "./shared.h"

cbuffer FilterToneMap : register(b0) {
  float gXfElapsedTime : packoffset(c0);
  float gXfMiddleGray : packoffset(c0.y);
  float gXfAdaptedLum : packoffset(c0.z);
  float gXfMaxLuminance : packoffset(c0.w);
  float gXfMinLuminance : packoffset(c1);
  float gXfBrightPassThreshold : packoffset(c1.y);
  float gXfBrightPassOffset : packoffset(c1.z);
  float4 gXfScaleColor : packoffset(c2);
  float4 gXfBrightPassMax : packoffset(c3);
}

SamplerState SSWrapPoint_s : register(s0);
Texture2D<float4> tFilterPoint0 : register(t0);

// scale * (w * x) / (w * x + offset), 0 where the denominator is not positive (black input with offset 0 is 0/0 = NaN in vanilla).
float3 BrightPassCurve(float3 w, float3 x) {
  float3 d = w * x + gXfBrightPassOffset;
  return (d > 0.f) ? gXfScaleColor.xyz * (w * x) / d : 0.f;
}

// Vanilla: w = max(0, min(x, 2) - threshold); out = scale * (w * x) / (w * x + offset).
// That asymptotes to gXfScaleColor, which clips HDR bloom.
// HDR: identical up to x = 2 (the vanilla cap), then continues proportionally (y(2) * x / 2) so bloom keeps growing with the input.
// The input is limited to a multiple of the peak/graphics white ratio to avoid fireflies.
float3 BloomBrightPass(float3 x) {
  float3 w = max(0, min(x, 2.f) - gXfBrightPassThreshold);
  float3 vanilla = BrightPassCurve(w, x);
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) return vanilla;

  float3 y = min(x, 2.f);
  float3 w2 = max(0, y - gXfBrightPassThreshold);
  float3 knee = BrightPassCurve(w2, y);
  float3 x_max = 4.f * RENODX_PEAK_WHITE_NITS / RENODX_GRAPHICS_WHITE_NITS;
  float3 per_channel = (x <= 2.f) ? vanilla : knee * (min(x, x_max) / 2.f);

  // Hue-preserving: run the same curve on the brightest channel, then rescale by the source ratio.
  float m = max(max(x.r, max(x.g, x.b)), 1e-6f);
  float ym = min(m, 2.f);
  float wm = max(0, ym - gXfBrightPassThreshold);
  float3 knee_m = BrightPassCurve(wm, ym);
  float3 g = (m <= 2.f) ? knee_m : knee_m * (min(m, x_max) / 2.f);
  float3 hue_preserving = g * (x / m);

  return lerp(hue_preserving, per_channel, RENODX_BLOOM_HUE);
}

#endif  // SRC_DMC4SE_BLOOM_BRIGHT_PASS_HLSLI_
