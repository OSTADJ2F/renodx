#include "./shared.h"

cbuffer CBMotionBlur : register(b0)
{
  float fVelocityDepthScale : packoffset(c0);
  float fVelocityDepthBias : packoffset(c0.y);
  float fVelocityLimite : packoffset(c0.z);
  float fVelocityScale : packoffset(c0.w);
  row_major float4x4 fVelocityViewProjPF : packoffset(c1);
}

SamplerState SSPoint_s : register(s0);
SamplerState SSBorderPoint_s : register(s1);
Texture2D<float4> tFilterTempMap1 : register(t0);
Texture2D<float4> tBaseMap : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0, r1, r2, r3, r4, r5;
  r0 = tFilterTempMap1.Sample(SSPoint_s, v1.xy);
  r0.xy = r0.xy - 0.501961;
  r0.xy = r0.xy * fVelocityScale * RENODX_FX_MOTION_BLUR;
  r1.xy = r0.xy * 0.333333 + v1.xy;
  r1 = tBaseMap.Sample(SSBorderPoint_s, r1.xy);
  r2.y = r1.w;
  r3.xy = r0.xy * 0.666667 + v1.xy;
  r0.xy = r0.xy * -0.333333 + v1.xy;
  r3 = tBaseMap.Sample(SSBorderPoint_s, r3.xy);
  r2.z = r3.w;
  r4 = tBaseMap.Sample(SSBorderPoint_s, r0.xy);
  r2.w = r4.w;
  r5 = tBaseMap.Sample(SSBorderPoint_s, v1.xy);
  r2.x = r5.w;
  r0 = (r2 >= r0.z) ? 1.0 : 0.0;
  o0.w = r2.x;
  r1.xyz = r1.xyz * r0.y;
  r1.xyz = r5.xyz * r0.x + r1.xyz;
  r1.xyz = r3.xyz * r0.z + r1.xyz;
  r1.xyz = r4.xyz * r0.w + r1.xyz;
  r0.x = r0.y + r0.x;
  r0.x = r0.z + r0.x;
  r0.x = r0.w + r0.x;
  r0.y = max(r0.x, 1.0);
  r0.x = min(r0.x, 1.0);
  r1.xyz = r1.xyz / r0.y;
  r1.xyz = -r5.xyz + r1.xyz;
  o0.xyz = r0.x * r1.xyz + r5.xyz;
}
