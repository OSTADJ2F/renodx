#include "./shared.h"

cbuffer CBSystemGamma : register(b0)
{
  float3 fGamma : packoffset(c0);
}

SamplerState SSPoint_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 base = tBaseMap.Sample(SSPoint_s, v1.xy);
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) {
    o0.xyz = exp(log(base.xyz) * fGamma.x);
  } else {
    // Gamma only on the 0..1 part; above 1 extend linearly with slope 1.
    float3 magnitude = abs(base.xyz);
    float3 below = min(magnitude, 1.f);
    o0.xyz = sign(base.xyz) * (exp(log(below) * fGamma.x) + (magnitude - below));
  }
  o0.w = base.w;
}
