#include "./shared.h"
#include "./effects_hdr.hlsli"


cbuffer CBROPTest : register(b0)
{
  float fAlphaRef : packoffset(c0);
  float fStencilRef : packoffset(c0.y);
  float fDepthBias : packoffset(c0.z);
  float fAlphaToCoverageScale : packoffset(c0.w);
  float fGlobalTransparency : packoffset(c1);
}

cbuffer CBPrimitiveMetaDataLvCorrection : register(b1)
{
  float3 fPrimLvCorrColorConst : packoffset(c0);
  float3 fPrimLvCorrValue : packoffset(c1);
}

SamplerState SSWrapLinear_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  float4 v3 : TEXCOORD2,
  float4 v4 : TEXCOORD3,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = tBaseMap.Sample(SSWrapLinear_s, v4.xy);
  r0.xyz = v1.xyz * r0.xyz;
  r0.w = v1.w * r0.w + -fPrimLvCorrValue.x;
  r1.x = fPrimLvCorrValue.y + -fPrimLvCorrValue.x;
  r0.w = saturate(r0.w / r1.x);
  r0.w = fPrimLvCorrValue.z * r0.w;
  r0.w = -5.77078009 * r0.w;
  r0.w = exp2(r0.w);
  r0.w = 1 + -r0.w;
  r1.x = cmp(fAlphaRef >= r0.w);
  if (r1.x != 0) {
    if (-1 != 0) discard;
  }
  o0.xyz = r0.xyz * v3.xyz + v2.xyz;
  o0.w = r0.w;
  o0 = ApplyEffectsHDR(o0);
  return;
}