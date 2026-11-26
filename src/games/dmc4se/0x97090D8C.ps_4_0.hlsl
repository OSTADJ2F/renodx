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
SamplerState SSLinear_s : register(s1);
Texture2D<float4> tFilterTempMap1 : register(t0);
Texture2D<float4> tBaseMap : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0;
  r0 = tFilterTempMap1.Sample(SSPoint_s, v1.xy);
  r0.xy = r0.xy - 0.501961;
  r0.xy = abs(r0.xy) * fVelocityScale * RENODX_FX_MOTION_BLUR;
  r0.x = max(r0.y, r0.x);
  r0.x = r0.x * 1000.0;
  o0.w = min(r0.x, 1.0);
  r0 = tBaseMap.Sample(SSLinear_s, v1.xy);
  o0.xyz = r0.xyz;
}
