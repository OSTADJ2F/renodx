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

cbuffer CBVolumeNoise : register(b1)
{
  float4 fNoiseUVWOffset : packoffset(c0);
  float4 fNoiseColor : packoffset(c1);
  float4 fEase : packoffset(c2);
  float fNoiseScale : packoffset(c3);
  float fNoiseBias : packoffset(c3.y);
}

SamplerState SSFilter_s : register(s0);
SamplerState SSWrapLinear_s : register(s1);
Texture2D<float4> tDepthMap : register(t0);
Texture3D<float4> tVolumeMap : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float depth = dot(tDepthMap.Sample(SSFilter_s, v1.xy), float4(0.003891f, 0.000015f, 0.0f, 0.996094f));
  float below = min(max((depth - fEase.z) / fEase.z, -1.0f), 0.0f);
  float above = saturate((depth - fEase.z) / (1.0f - fEase.z));
  float s = (depth < fEase.z ? below : above) * 0.5f + 0.5f;
  float4 poly = float4(s * s * s, s * s, s, 1.0f);
  float4 coef = float4(dot(poly, float4(-1.0f, 3.0f, -3.0f, 1.0f)), dot(poly.xyz, float3(3.0f, -6.0f, 3.0f)), dot(poly.xy, float2(-3.0f, 3.0f)), poly.x);
  float ease = dot(coef, float4(0.0f, fEase.x, fEase.y, 1.0f));
  float3 dir = v1.x * fViewI[0].xyz - v1.y * fViewI[1].xyz - fViewI[2].xyz;
  float3 uvw = dir * fNoiseUVWOffset.w;
  float noise = tVolumeMap.Sample(SSWrapLinear_s, uvw + fNoiseUVWOffset.xyz).x * 0.5f;
  noise += tVolumeMap.Sample(SSWrapLinear_s, uvw * 2.0f + fNoiseUVWOffset.xyz).x * 0.25f;
  noise += tVolumeMap.Sample(SSWrapLinear_s, uvw * 4.0f + fNoiseUVWOffset.xyz).x * 0.125f;
  noise += tVolumeMap.Sample(SSWrapLinear_s, uvw * 8.0f + fNoiseUVWOffset.xyz).x * 0.0625f;
  noise = max(noise + fNoiseBias, 0.0f);
  o0.w = ease * noise * fNoiseColor.w;
  o0.xyz = fNoiseColor.xyz;
  // RenoDX: fog strength scales the fog blend amount (0 = no fog, 1 = vanilla).
  o0.w *= RENODX_FX_FOG;  // FOGLINE
  o0.w = saturate(o0.w);
}
