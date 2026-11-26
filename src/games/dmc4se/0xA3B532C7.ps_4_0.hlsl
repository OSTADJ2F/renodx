#include "./shared.h"
#include "./sanitize_scene.hlsli"

cbuffer CBHDRFactor : register(b0)
{
  float fHDRCompressEncode : packoffset(c0);
  float fHDRCompressDecode : packoffset(c0.y);
  float fHDRRelativeEncode : packoffset(c0.z);
  float fHDRRelativeDecode : packoffset(c0.w);
}

SamplerState SSLinear_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0 = tBaseMap.Sample(SSLinear_s, v1.xy);
  r0.xyz = SanitizeScene(r0.xyz) * fHDRCompressDecode * fHDRRelativeEncode;
  r0.w = max(1.0 / max(max(max(r0.x, r0.y), r0.z), 1.0), 0.01);
  o0.xyz = r0.xyz * r0.w;
  o0.w = r0.w;
}
