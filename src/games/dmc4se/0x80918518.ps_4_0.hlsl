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

cbuffer CBFog : register(b1)
{
  float3 fFogColor : packoffset(c0);
  float fFogDensity : packoffset(c0.w);
  float fFogHStart : packoffset(c1);
  float fFogHInvRange : packoffset(c1.y);
  float fFogStart : packoffset(c1.z);
  float fFogInvRange : packoffset(c1.w);
  float3 fFogHColor : packoffset(c2);
  float fFogHDensity : packoffset(c2.w);
  float fFogHUVScale : packoffset(c3);
  float fFogHSlopeBias : packoffset(c3.y);
  float2 fFogHUVOffset : packoffset(c3.z);
  float fFogDiffuseBlend : packoffset(c4);
}

SamplerState SSPoint_s : register(s0);
SamplerState SSLinear_s : register(s1);
Texture2D<float4> tDepthMap : register(t0);
Texture1D<float4> tFogTable : register(t1);
Texture2D<float4> tBaseMap : register(t2);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  out float4 o0 : SV_TARGET0)
{
  float depth = tDepthMap.Sample(SSPoint_s, v1.xy).x;
  float2 clip = v2.y * float2(fViewProjI[1].y, fViewProjI[1].w) + v2.x * float2(fViewProjI[0].y, fViewProjI[0].w) + depth * float2(fViewProjI[2].y, fViewProjI[2].w) + float2(fViewProjI[3].y, fViewProjI[3].w);
  float h = saturate((clip.x / clip.y - fFogHStart) * fFogHInvRange);
  float hd = h * fFogHDensity;
  float3 fog = hd * fFogHColor;
  float f = saturate((fProj[3].z * (1.0f / (depth + fProj[2].z)) - fFogStart) * fFogInvRange);
  float fd = f * fFogDensity;
  float3 table = tFogTable.SampleLevel(SSLinear_s, fd, 0).xyz * fFogColor * fd;
  fog = table * (1.0f - hd) + fog;
  float4 base = tBaseMap.Sample(SSPoint_s, v1.xy);
  float3 fogged = base.xyz * ((1.0f - hd) * (1.0f - fd)) + fog;
  // RenoDX: fog strength scales the fog blend amount (0 = no fog, 1 = vanilla).
  o0.xyz = base.xyz + RENODX_FX_FOG * (fogged - base.xyz);  // FOGLINE
  o0.w = base.w;
}
