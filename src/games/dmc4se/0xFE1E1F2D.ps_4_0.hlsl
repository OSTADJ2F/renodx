#include "./shared.h"
#include "./effects_hdr.hlsli"


cbuffer CBHDRFactor : register(b0)
{
  float fHDRCompressEncode : packoffset(c0);
  float fHDRCompressDecode : packoffset(c0.y);
  float fHDRRelativeEncode : packoffset(c0.z);
  float fHDRRelativeDecode : packoffset(c0.w);
}

cbuffer CBScreen : register(b1)
{
  float2 fScreenOffset : packoffset(c0);
  float2 fScreenScale : packoffset(c0.z);
  float2 fScreenSize : packoffset(c1);
  float2 fScreenInverseSize : packoffset(c1.z);
  float2 fScreenHalfPixelOffset : packoffset(c2);
}

cbuffer CBROPTest : register(b2)
{
  float fAlphaRef : packoffset(c0);
  float fStencilRef : packoffset(c0.y);
  float fDepthBias : packoffset(c0.z);
  float fAlphaToCoverageScale : packoffset(c0.w);
  float fGlobalTransparency : packoffset(c1);
}

cbuffer CBViewProjection : register(b3)
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

cbuffer CBPrimitiveMetaDataLvCorrection : register(b4)
{
  float3 fPrimLvCorrColorConst : packoffset(c0);
  float3 fPrimLvCorrValue : packoffset(c1);
}

SamplerState SSWrapLinear_s : register(s0);
SamplerState SSPoint_s : register(s1);
Texture2D<float4> tBaseMap : register(t0);
Texture2D<float4> tPrimDepthMap : register(t1);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  float4 v3 : TEXCOORD2,
  float4 v4 : TEXCOORD3,
  float4 v5 : TEXCOORD4,
  float4 v6 : TEXCOORD5,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1,r2;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xy = fScreenInverseSize.xy * v0.xy;
  r1.xyzw = tBaseMap.Sample(SSWrapLinear_s, v6.xy);
  r1.xyzw = v1.xyzw * r1.xyzw;
  r0.xyzw = tPrimDepthMap.Sample(SSPoint_s, r0.xy);
  r0.x = fProj._m22 + r0.x;
  r0.x = 1 / r0.x;
  r0.x = fProj._m32 * r0.x + -v5.z;
  r0.x = v4.w * abs(r0.x);
  r0.x = min(1, r0.x);
  r0.x = r1.w * r0.x + -fPrimLvCorrValue.x;
  r0.y = fPrimLvCorrValue.y + -fPrimLvCorrValue.x;
  r0.x = saturate(r0.x / r0.y);
  r0.y = cmp(fAlphaRef >= r0.x);
  if (r0.y != 0) {
    if (-1 != 0) discard;
  }
  r2.xyz = ClampVertexColorHDR(v3.xyz);
  r1.xyz = r1.xyz * r2.xyz + v2.xyz;
  r0.x = r0.x;
  o0.xyz = fHDRCompressEncode * r1.xyz;
  o0.w = r0.x;
  return;
}