#include "./bloom_bright_pass.hlsli"

void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float3 x = tFilterPoint0.Sample(SSWrapPoint_s, v1).xyz;
  o0.xyz = BloomBrightPass(x);
  o0.w = 1;
}
