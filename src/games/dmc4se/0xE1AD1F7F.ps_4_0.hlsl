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
  float4 r0, r1, r2, r3, r4, r5, r6, r7, r8;
  r0 = tFilterTempMap1.Sample(SSPoint_s, v1.xy);
  r0.xy = r0.xy - 0.501961;
  r1.xy = r0.xy * fVelocityScale * RENODX_FX_MOTION_BLUR;
  r0.xy = r1.xy + v1.xy;
  r2.xy = r1.xy * 0.142857 + v1.xy;
  r2 = tBaseMap.Sample(SSBorderPoint_s, r2.xy);
  r3.y = r2.w;
  r4.xy = r1.xy * 0.285714 + v1.xy;
  r4 = tBaseMap.Sample(SSBorderPoint_s, r4.xy);
  r3.z = r4.w;
  r5.xy = r1.xy * 0.428571 + v1.xy;
  r5 = tBaseMap.Sample(SSBorderPoint_s, r5.xy);
  r3.w = r5.w;
  r6 = tBaseMap.Sample(SSBorderPoint_s, v1.xy);
  r3.x = r6.w;
  r7 = (r3 >= r0.z) ? 1.0 : 0.0;
  o0.w = r3.x;
  r3 = r7;
  r2.xyz = r2.xyz * r3.y;
  r2.xyz = r6.xyz * r3.x + r2.xyz;
  r2.xyz = r4.xyz * r3.z + r2.xyz;
  r2.xyz = r5.xyz * r3.w + r2.xyz;
  r4 = tBaseMap.Sample(SSBorderPoint_s, r0.xy);
  r5.w = r4.w;
  r0.xy = r1.xy * 0.571429 + v1.xy;
  r7 = tBaseMap.Sample(SSBorderPoint_s, r0.xy);
  r5.x = r7.w;
  r0.xy = r1.xy * 0.714286 + v1.xy;
  r1.xy = r1.xy * 0.857143 + v1.xy;
  r8 = tBaseMap.Sample(SSBorderPoint_s, r0.xy);
  r5.y = r8.w;
  r1 = tBaseMap.Sample(SSBorderPoint_s, r1.xy);
  r5.z = r1.w;
  r0 = (r5 >= r0.z) ? 1.0 : 0.0;
  r2.xyz = r7.xyz * r0.x + r2.xyz;
  r2.xyz = r8.xyz * r0.y + r2.xyz;
  r1.xyz = r1.xyz * r0.z + r2.xyz;
  r1.xyz = r4.xyz * r0.w + r1.xyz;
  r0.x = r0.y + r0.x;
  r0.x = r0.z + r0.x;
  r0.x = r0.w + r0.x;
  r0.y = r3.y + r3.x;
  r0.y = r3.z + r0.y;
  r0.y = r3.w + r0.y;
  r0.x = r0.x + r0.y;
  r0.y = max(r0.x, 1.0);
  r0.x = min(r0.x, 1.0);
  r1.xyz = r1.xyz / r0.y;
  r1.xyz = -r6.xyz + r1.xyz;
  o0.xyz = r0.x * r1.xyz + r6.xyz;
}
