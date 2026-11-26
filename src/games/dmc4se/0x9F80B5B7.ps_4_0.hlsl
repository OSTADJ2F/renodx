#include "./shared.h"

cbuffer LevelCorrect : register(b0)
{
  float3 gXfInBlack : packoffset(c0);
  float3 gXfInGamma : packoffset(c1);
  float3 gXfInWhite : packoffset(c2);
  float3 gXfOutBlack : packoffset(c3);
  float3 gXfOutWhite : packoffset(c4);
}

SamplerState SSLinear_s : register(s0);
Texture2D<float4> tFilterLinear0 : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0 = tFilterLinear0.Sample(SSLinear_s, v1.xy);
  o0.w = r0.w;
  float3 leveled = (r0.xyz - gXfInBlack) * gXfInWhite;
  leveled = leveled * gXfOutWhite + gXfOutBlack;
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) {
    o0.xyz = exp(log(saturate(leveled)) * gXfInGamma);
  } else {
    // RenoDX: gamma on the 0-1 part only; above 1 continue linearly with the gamma curve's slope at 1.
    leveled = max(leveled, 0.f);
    float3 lower = min(leveled, 1.f);
    o0.xyz = exp(log(lower) * gXfInGamma) + gXfInGamma * (leveled - lower);
  }
}
