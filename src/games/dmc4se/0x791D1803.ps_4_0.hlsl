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

cbuffer CBNoiseFog : register(b1)
{
  float4 fDepthHeightFactor : packoffset(c0);
}

cbuffer CBVolumeNoise : register(b2)
{
  float4 fNoiseUVWOffset : packoffset(c0);
  float4 fNoiseColor : packoffset(c1);
  float4 fEase : packoffset(c2);
  float fNoiseScale : packoffset(c3);
  float fNoiseBias : packoffset(c3.y);
}

SamplerState SSPoint_s : register(s0);
SamplerState SSWrapLinear_s : register(s1);
Texture2D<float4> tDepthMap : register(t0);
Texture3D<float4> tVolumeMap : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  out float4 o0 : SV_TARGET0)
{
  float depth = tDepthMap.Sample(SSPoint_s, v1.xy).x;
  float4 world = v2.y * fViewProjI[1] + v2.x * fViewProjI[0] + depth * fViewProjI[2] + fViewProjI[3];
  world.xyz /= world.w;
  float3 toPixel = world.xyz - fCameraPos;
  float invLen = rsqrt(dot(toPixel, toPixel));
  float3 dir = toPixel * invLen;
  float2 factor = float2(world.y - fDepthHeightFactor.z, toPixel.x * invLen - fDepthHeightFactor.x) * fDepthHeightFactor.wy;
  float3 uvw = dir * fNoiseUVWOffset.w;
  float noise = tVolumeMap.Sample(SSWrapLinear_s, uvw + fNoiseUVWOffset.xyz).x * 0.5f;
  noise += tVolumeMap.Sample(SSWrapLinear_s, uvw * 2.0f + fNoiseUVWOffset.xyz).x * 0.25f;
  noise += tVolumeMap.Sample(SSWrapLinear_s, uvw * 4.0f + fNoiseUVWOffset.xyz).x * 0.125f;
  noise += tVolumeMap.Sample(SSWrapLinear_s, uvw * 8.0f + fNoiseUVWOffset.xyz).x * 0.0625f;
  noise += fNoiseBias;
  o0.w = saturate(noise * max(factor.x, factor.y) * fNoiseColor.w);
  o0.xyz = fNoiseColor.xyz;
  // RenoDX: fog strength scales the fog blend amount (0 = no fog, 1 = vanilla).
  o0.w *= RENODX_FX_FOG;  // FOGLINE
}
