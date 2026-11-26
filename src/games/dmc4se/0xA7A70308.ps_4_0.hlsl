#include "./shared.h"
#include "./effects_hdr.hlsli"


cbuffer CBHDRFactor : register(b0)
{
  float fHDRCompressEncode : packoffset(c0);
  float fHDRCompressDecode : packoffset(c0.y);
  float fHDRRelativeEncode : packoffset(c0.z);
  float fHDRRelativeDecode : packoffset(c0.w);
}

cbuffer CBROPTest : register(b1)
{
  float fAlphaRef : packoffset(c0);
  float fStencilRef : packoffset(c0.y);
  float fDepthBias : packoffset(c0.z);
  float fAlphaToCoverageScale : packoffset(c0.w);
  float fGlobalTransparency : packoffset(c1);
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
  r0.xyzw = v1.xyzw * r0.xyzw;
  r1.x = cmp(fAlphaRef >= r0.w);
  if (r1.x != 0) {
    if (-1 != 0) discard;
  }
  r1.xyz = ClampVertexColorHDR(v3.xyz);
  r0.xyz = r0.xyz * r1.xyz + v2.xyz;
  o0.xyz = fHDRCompressEncode * r0.xyz;
  o0.w = r0.w;
  return;
}