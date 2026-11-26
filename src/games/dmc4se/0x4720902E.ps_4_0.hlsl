#include "./tonemap_reinhard.hlsli"

Texture2D<float4> tFilterLinear1 : register(t2);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float3 bloom = gXfScaleColor.x * tFilterLinear1.Sample(SSLinear_s, v1.xy).xyz;
  o0.xyz = ReinhardTonemap(v1.xy, bloom);
  o0.w = 1;
}
