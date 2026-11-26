#include "./shared.h"
#include "./bloom_composite.hlsli"

cbuffer FilterToneMap : register(b0)
{
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
SamplerState SSLinear_s : register(s1);
Texture2D<float4> tFilterPoint0 : register(t0);
Texture2D<float4> tFilterLinear1 : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0 = tFilterPoint0.Sample(SSWrapPoint_s, v1.xy);
  float4 r1 = tFilterLinear1.Sample(SSLinear_s, v1.xy);
  if (RENODX_PEAK_WHITE_NITS == 0.f || RENODX_TONE_MAP_TYPE == 0.f) {
    o0.xyz = gXfScaleColor.x * RENODX_FX_BLOOM * r1.xyz + r0.xyz;
  } else if (RENODX_FX_BLOOM_MODE == 3.f) {
    // Post Tone Map: the grade adds bloom after ToneMapPass.
    o0.xyz = r0.xyz;
  } else {
    o0.xyz = BloomCombine(r0.xyz, BloomShape(gXfScaleColor.x * RENODX_FX_BLOOM * r1.xyz, r0.xyz), r0.xyz);
  }
  o0.w = 1.0;
}
