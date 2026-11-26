#ifndef SRC_DMC4SE_TONEMAP_REINHARD_HLSLI_
#define SRC_DMC4SE_TONEMAP_REINHARD_HLSLI_

#include "./shared.h"
#include "./bloom_composite.hlsli"

cbuffer CBHDRFactor : register(b0)
{
  float fHDRCompressEncode : packoffset(c0);
  float fHDRCompressDecode : packoffset(c0.y);
  float fHDRRelativeEncode : packoffset(c0.z);
  float fHDRRelativeDecode : packoffset(c0.w);
}

cbuffer FilterToneMap : register(b1)
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
Texture2D<float4> tBaseMap : register(t1);

// Extended Reinhard. `bloom` is the weighted bloom sum that vanilla adds after the curve.
float3 ReinhardTonemap(float2 uv, float3 bloom) {
  bloom *= RENODX_FX_BLOOM;
  float4 base = tBaseMap.Sample(SSLinear_s, uv);
  base.xyz = base.xyz / base.www;
  float3 scene = tFilterPoint0.Sample(SSWrapPoint_s, uv).xyz;
  float3 excess = max(0, base.xyz * fHDRRelativeDecode - 1);

  // Vanilla: the clamped scene plus the relative-HDR excess, then extended Reinhard.
  float3 vanilla_input = saturate(scene) + excess;
  float3 exposed = gXfMiddleGray * vanilla_input;
  float3 curve = ((exposed * gXfMaxLuminance + 1) * exposed) / (exposed + 1);
  float3 vanilla = curve + bloom;

  // RenoDX: the clamp shader (0xE7663907) is normally bypassed.
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) return vanilla;

  // Works whether or not the upstream clamp was removed: unclamped A wins, a clamped A is restored by the excess.
  float3 untonemapped = gXfMiddleGray * max(scene, saturate(scene) + excess);
  // Vanilla values are display (gamma) encoded and the path ends in a plain copy: bloom mode, decode, tonemap linear, re-encode.
  return BloomToneMapPass(curve, untonemapped, bloom);
}

#endif  // SRC_DMC4SE_TONEMAP_REINHARD_HLSLI_
