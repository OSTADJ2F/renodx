#ifndef DMC4SE_TONEMAP_ADAPTIVE_HLSLI
#define DMC4SE_TONEMAP_ADAPTIVE_HLSLI

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

// scene: clamp-pass output (unclamped when RenoDX bypasses the clamp shader)
// rel: relative-HDR bloom sample, already decoded
// adapted: 1x1 adapted-luminance texture (x = exposure, y = max luminance)
// bloom: post-tonemap additive bloom/glare terms
float3 AdaptiveReinhard(float3 scene, float3 rel, float2 adapted, float3 bloom) {
  bloom *= RENODX_FX_BLOOM;
  // Vanilla: max(scene, rel) wherever the clamped scene saturated, then extended Reinhard with adapted exposure.
  float3 clamped = saturate(scene);
  float3 vanilla_input = (clamped == 1.0) ? max(rel, clamped) : clamped;
  float3 exposed = adapted.x * vanilla_input;
  float3 curve = ((exposed * adapted.y + 1.0) * exposed) / (exposed + 1.0);
  float3 vanilla = curve + bloom;

  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) return vanilla;

  // RenoDX: same reconstruction as vanilla on the unclamped scene (works with or without the upstream clamp); keep the adapted exposure.
  float3 recon = (clamped == 1.0) ? max(rel, scene) : scene;
  float3 untonemapped = adapted.x * recon;
  // Vanilla values are display (gamma) encoded and the path ends in a plain copy: bloom mode, decode, tonemap linear, re-encode.
  return BloomToneMapPass(curve, untonemapped, bloom);
}

#endif
