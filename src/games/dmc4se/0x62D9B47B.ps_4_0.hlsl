#include "./shared.h"
#include "./bloom_composite.hlsli"

cbuffer CBBloomFilter : register(b0)
{
  float3 fBloomColorScale : packoffset(c0);
  float fBloomThreshold : packoffset(c0.w);
}

SamplerState SSLinear_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0 = tBaseMap.Sample(SSLinear_s, v1.xy);
  float3 bloom = r0.xyz * fBloomColorScale * RENODX_FX_BLOOM;
  // No scene input here, so only the soft cap applies (no dark gate).
  // Added after the grade/tone map: in HDR keep the bloom bounded to graphics white, as vanilla's clip did.
  if (RENODX_TONE_MAP_TYPE == 0.f || RENODX_PEAK_WHITE_NITS == 0.f) {
    o0.xyz = bloom;
  } else {
    o0.xyz = renodx::draw::RenderIntermediatePass(renodx::color::srgb::DecodeSafe(saturate(BloomSoftCap(bloom))));
  }
  o0.w = 1.0;
}
