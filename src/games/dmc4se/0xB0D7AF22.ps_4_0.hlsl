#include "./shared.h"


cbuffer CBViewProjection : register(b0)
{
  row_major float4x4 fViewProj : packoffset(c0);
  float3 fCameraPos : packoffset(c4);
  float fCameraNearClip : packoffset(c4.w);
  float3 fCameraDir : packoffset(c5);
  float fCameraTargetDist : packoffset(c5.w);
  float fCameraFarClipLog2 : packoffset(c6);
  float fCameraFarClipLog2Inv : packoffset(c6.y);
  row_major float4x4 fView : packoffset(c7);
  row_major float4x4 fViewI : packoffset(c11);
  row_major float4x4 fProj : packoffset(c15);
  row_major float4x4 fProjI : packoffset(c19);
  row_major float4x4 fViewProjI : packoffset(c23);
}

cbuffer CBMotionBlur : register(b1)
{
  float fVelocityDepthScale : packoffset(c0);
  float fVelocityDepthBias : packoffset(c0.y);
  float fVelocityLimite : packoffset(c0.z);
  float fVelocityScale : packoffset(c0.w);
  row_major float4x4 fVelocityViewProjPF : packoffset(c1);
}

SamplerState SSPoint_s : register(s0);
Texture2D<float4> tDepthMap : register(t0);
Texture2D<float4> tBaseMap : register(t1);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = tDepthMap.Sample(SSPoint_s, v1.xy);
  r0.x = fProj._m22 + r0.x;
  r0.x = 1 / r0.x;
  r0.x = fProj._m32 * r0.x;
  o0.w = fVelocityDepthScale * r0.x;
  r0.xyzw = tBaseMap.Sample(SSPoint_s, v1.xy);
  o0.xyz = r0.xyz;
  o0.w = saturate(o0.w);
  return;
}