#include "./shared.h"


cbuffer CBROPTest : register(b0)
{
  float fAlphaRef : packoffset(c0);
  float fStencilRef : packoffset(c0.y);
  float fDepthBias : packoffset(c0.z);
  float fAlphaToCoverageScale : packoffset(c0.w);
  float fGlobalTransparency : packoffset(c1);
}

SamplerState SSWrapPoint_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = tBaseMap.Sample(SSWrapPoint_s, v2.xy);
  r0.xyzw = v1.xyzw * r0.xxxx;
  r1.x = cmp(fAlphaRef >= r0.w);
  if (r1.x != 0) {
    if (-1 != 0) discard;
  }
  o0.xyzw = r0.xyzw;
  o0.w = saturate(o0.w);
  return;
}