#include "./tonemap_reinhard.hlsli"

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  o0.xyz = ReinhardTonemap(v1.xy, 0);
  o0.w = 1;
}
