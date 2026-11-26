#include "./shared.h"


SamplerState SSDevelop_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1,r2;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = tBaseMap.Sample(SSDevelop_s, v2.xy, int2(-1, 0));
  r1.xyzw = tBaseMap.Sample(SSDevelop_s, v2.xy, int2(1, 0));
  r0.x = r1.x + r0.x;
  r1.xyzw = tBaseMap.Sample(SSDevelop_s, v2.xy, int2(0, -1));
  r0.x = r1.x + r0.x;
  r1.xyzw = tBaseMap.Sample(SSDevelop_s, v2.xy, int2(0, 1));
  r0.x = r1.x + r0.x;
  r1.xyzw = tBaseMap.Sample(SSDevelop_s, v2.xy, int2(-1, 1));
  r0.x = r1.x + r0.x;
  r2.xyzw = tBaseMap.Sample(SSDevelop_s, v2.xy, int2(1, 1));
  r0.x = r2.x + r0.x;
  r2.xyzw = tBaseMap.Sample(SSDevelop_s, v2.xy, int2(-1, -1));
  r0.x = r2.x + r0.x;
  r0.x = r0.x + r1.x;
  r0.x = 0.5 * r0.x;
  r0.x = min(1, r0.x);
  r1.xyzw = tBaseMap.Sample(SSDevelop_s, v2.xy);
  r0.w = max(r1.x, r0.x);
  r0.xyz = r1.xxx;
  o0.xyzw = v1.xyzw * r0.xyzw;
  o0.w = saturate(o0.w);
  return;
}