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

cbuffer CBLightScattering : register(b1)
{
  float4 fLSFactor0 : packoffset(c0);
  float4 fLSFactor1 : packoffset(c1);
  float4 fLSFactor2 : packoffset(c2);
  float4 fLSSunColor : packoffset(c3);
  float3 fLSSunDir : packoffset(c4);
}

SamplerState SSPoint_s : register(s0);
Texture2D<float4> tDepthMap : register(t0);
Texture2D<float4> tBaseMap : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  out float4 o0 : SV_TARGET0)
{
  float depth = tDepthMap.Sample(SSPoint_s, v1.xy).x;
  float4 world = v2.y * fViewProjI[1] + v2.x * fViewProjI[0] + depth * fViewProjI[2] + fViewProjI[3];
  float3 toPixel = world.xyz / world.w - fCameraPos;
  float dist = length(toPixel);
  float cosTheta = dot(toPixel * rsqrt(dot(toPixel, toPixel)), fLSSunDir);
  float phase = exp2(log2(fLSFactor0.w * cosTheta + fLSFactor1.w) * 1.5f);
  float3 inscatter = (cosTheta * cosTheta + 1.0f) * fLSFactor1.xyz + (fLSFactor2.w / phase) * fLSFactor2.xyz;
  inscatter *= fLSSunColor.xyz;
  float3 extinction = exp2(dist * fLSFactor0.xyz * 1.442695f);
  float3 scatter = inscatter * (1.0f - extinction);
  float3 base = tBaseMap.Sample(SSPoint_s, v1.xy).xyz;
  scatter = base * extinction + scatter;
  scatter -= base;
  // RenoDX: fog strength scales the fog blend amount (0 = no fog, 1 = vanilla).
  o0.xyz = fLSSunColor.w * RENODX_FX_FOG * scatter + base;
  o0.w = 1.0f;
}
