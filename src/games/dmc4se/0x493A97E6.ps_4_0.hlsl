#include "./shared.h"

cbuffer CBHDRFactor : register(b0)
{
  float fHDRCompressEncode : packoffset(c0);
  float fHDRCompressDecode : packoffset(c0.y);
  float fHDRRelativeEncode : packoffset(c0.z);
  float fHDRRelativeDecode : packoffset(c0.w);
}

cbuffer CBBloomFilter : register(b1)
{
  float3 fBloomColorScale : packoffset(c0);
  float fBloomThreshold : packoffset(c0.w);
}

SamplerState SSPoint_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0 = tBaseMap.Sample(SSPoint_s, v1.xy);
  float3 rgb = r0.a <= 0.0 ? 0.0 : r0.rgb / r0.a;
  rgb *= fHDRRelativeDecode;
  rgb *= fHDRRelativeEncode;
  float m = max(max(rgb.r, rgb.g), rgb.b);
  float t = m - fBloomThreshold;
  float x = max(t, 0.0);
  float y = max(t, 1.0);
  float d = m * y;
  float w = d <= 0.0 ? 0.0 : x / d;
  o0.rgb = rgb * w;
  o0.a = 1.0;
}
