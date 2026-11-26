#include "./shared.h"


cbuffer CBROPTest : register(b0)
{
  float fAlphaRef : packoffset(c0);
  float fStencilRef : packoffset(c0.y);
  float fDepthBias : packoffset(c0.z);
  float fAlphaToCoverageScale : packoffset(c0.w);
  float fGlobalTransparency : packoffset(c1);
}

cbuffer CBGUIColor : register(b1)
{
  float4 fGUIColorScale : packoffset(c0);
  float4 fGUIAmbientColor : packoffset(c1);
}

SamplerState SSGUI_s : register(s0);
Texture2D<float4> tGUIBaseMap : register(t0);
Texture2D<float4> tGUIBlendMap : register(t1);


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

  r0.xyzw = tGUIBaseMap.Sample(SSGUI_s, v2.xy).xzwy;
  r1.x = -0.482353002 + r0.x;
  r0.x = r1.x * 1.40199995 + r0.z;
  r1.y = -0.482353002 + r0.y;
  r1.z = -r1.y * 0.344139993 + r0.z;
  r0.y = -r1.x * 0.714139998 + r1.z;
  r0.z = r1.y * 1.77199996 + r0.z;
  r1.xyzw = tGUIBlendMap.Sample(SSGUI_s, v2.zw);
  r0.xyzw = v1.xyzw * r0.xyzw;
  r0.xyzw = r0.xyzw * r1.xyzw;
  r0.xyzw = r0.xyzw * fGUIColorScale.xyzw + fGUIAmbientColor.xyzw;
  r1.x = cmp(fAlphaRef >= r0.w);
  if (r1.x != 0) {
    if (-1 != 0) discard;
  }
  o0.xyzw = r0.xyzw;
  o0.w = saturate(o0.w);
  return;
}