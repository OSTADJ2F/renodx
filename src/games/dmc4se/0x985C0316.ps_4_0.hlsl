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

cbuffer CBViewProjection : register(b1)
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

SamplerState SSWrapLinear_s : register(s0);
SamplerState SSSpecularMap_s : register(s1);
SamplerState SSNormalMap_s : register(s2);
SamplerState SSEnvMap_s : register(s3);
Texture2D<float4> tBaseMap : register(t0);
Texture2D<float4> tPrimMaskMap : register(t1);
Texture2D<float4> tPrimNormalMap : register(t2);
TextureCube<float4> tGlobalEnvMap : register(t3);


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
  float4 v7 : TEXCOORD6,
  float4 v8 : TEXCOORD7,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1,r2,r3;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = tBaseMap.Sample(SSWrapLinear_s, v8.xy);
  r0.x = v1.w * r0.w;
  r0.y = cmp(fAlphaRef >= r0.x);
  if (r0.y != 0) {
    if (-1 != 0) discard;
  }
  r1.xyz = -fCameraPos.xyz + v7.xyz;
  r0.y = dot(r1.xyz, r1.xyz);
  r0.y = rsqrt(r0.y);
  r1.xyz = r0.yyy * r1.xyz;
  r2.xyzw = tPrimMaskMap.Sample(SSSpecularMap_s, v8.xy);
  r3.xyzw = tPrimNormalMap.Sample(SSNormalMap_s, v8.xy);
  r0.y = -0.498039216 + r3.x;
  r0.y = r0.y + r0.y;
  r0.z = -0.498039216 + r3.y;
  r0.z = r0.z + r0.z;
  r0.w = -r0.y * r0.y + 1;
  r0.w = -r0.z * r0.z + r0.w;
  r0.w = max(9.99999975e-005, r0.w);
  r0.w = sqrt(r0.w);
  r3.xyz = v5.xyz * r0.zzz;
  r3.xyz = r0.yyy * v4.xyz + r3.xyz;
  r3.xyz = r0.www * v6.xyz + r3.xyz;
  r0.y = dot(r3.xyz, r3.xyz);
  r0.y = rsqrt(r0.y);
  r3.xyz = r0.yyy * r3.xyz;
  r0.y = dot(r1.xyz, r3.xyz);
  r0.y = r0.y + r0.y;
  r1.xyz = r3.xyz * -r0.yyy + r1.xyz;
  r1.xyzw = tGlobalEnvMap.SampleLevel(SSEnvMap_s, r1.xyz, 0);
  r1.xyz = r1.xyz / r1.www;
  r0.y = v5.w * r2.x;
  r2.xyz = r0.yyy * r1.xyz;
  r1.xyz = -r0.yyy * r1.xyz + v2.xyz;
  o0.xyz = v3.xyz * r1.xyz + r2.xyz;
  o0.w = r0.x;
  o0 = ApplyEffectsHDR(o0);
  return;
}