#include "./shared.h"
#include "./sanitize_scene.hlsli"

cbuffer CBHDRFactor : register(b0)
{
  float fHDRCompressEncode : packoffset(c0);
  float fHDRCompressDecode : packoffset(c0.y);
  float fHDRRelativeEncode : packoffset(c0.z);
  float fHDRRelativeDecode : packoffset(c0.w);
}

SamplerState SSPoint_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0 = tBaseMap.Sample(SSPoint_s, v1.xy);
  r0.xyz = SanitizeScene(r0.xyz);
  o0.xyz = fHDRCompressDecode * r0.xyz;
  // RenoDX: keep the scene unclamped when RenoDX tone mapping is active (type 0 is vanilla).
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) {
    o0.xyz = saturate(o0.xyz);
  } else if (CUSTOM_CLAMP_TONE_MAP != 0.f) {
    float3 untonemapped = renodx::color::srgb::DecodeSafe(o0.xyz);
    o0.xyz = renodx::draw::RenderIntermediatePass(renodx::draw::ToneMapPass(untonemapped, renodx::color::srgb::DecodeSafe(saturate(o0.xyz))));
  }
  o0.w = r0.w;
}
