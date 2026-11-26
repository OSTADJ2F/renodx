#include "./tonemap_adaptive.hlsli"

SamplerState SSWrapPoint_s : register(s0);
SamplerState SSWrapLinear_s : register(s1);
SamplerState SSLinear_s : register(s2);
Texture2D<float4> tFilterPoint0 : register(t0);
Texture2D<float4> tBaseMap : register(t1);
Texture2D<float4> tFilterPoint4 : register(t2);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 base = tBaseMap.Sample(SSWrapLinear_s, v1.xy);
  float3 rel = base.xyz / base.www * fHDRRelativeDecode;
  float3 scene = tFilterPoint0.Sample(SSWrapPoint_s, v1.xy).xyz;
  float2 adapted = tFilterPoint4.Sample(SSWrapPoint_s, float2(0.5, 0.5)).xy;
  float3 bloom = 0;
  o0.xyz = AdaptiveReinhard(scene, rel, adapted, bloom);
  o0.w = 1;
}
