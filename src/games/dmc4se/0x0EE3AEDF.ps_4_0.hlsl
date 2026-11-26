#include "./bloom_bright_pass.hlsli"

Texture2D<float4> tFilterPoint4 : register(t1);

void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float3 c = tFilterPoint0.Sample(SSWrapPoint_s, v1).xyz;
  float2 lum = tFilterPoint4.Sample(SSWrapPoint_s, float2(0.5, 0.5)).xy;
  float3 scaled = c * lum.x;
  o0.xyz = BloomBrightPass(scaled * (scaled * lum.y + 1) / (c * lum.x + 1));
  o0.w = 1;
}
