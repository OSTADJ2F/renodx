#include "./shared.h"

cbuffer CBDOFFilter : register(b0)
{
  float2 fDOFPoissonOffsets[8] : packoffset(c0);
  float2 fDOFPixelSizeLow : packoffset(c7.z);
  float2 fDOFPixelSizeHigh : packoffset(c8);
  float3 fDOFGradateColor : packoffset(c9);
  float fDOFFocus : packoffset(c9.w);
  float fDOFNear : packoffset(c10);
  float fDOFFar : packoffset(c10.y);
  float fDOFNearLimit : packoffset(c10.z);
  float fDOFFarLimit : packoffset(c10.w);
  float fDOFCoCScale : packoffset(c11);
  float fDOFCoCBias : packoffset(c11.y);
  float fDOFRadiusScale : packoffset(c11.z);
  float fDOFCorrectParamNear : packoffset(c11.w);
  float fDOFCorrectParamFar : packoffset(c12);
  float4 fDOFVelocityFactor : packoffset(c13);
}

SamplerState SSPoint_s : register(s0);
SamplerState SSFilter_s : register(s1);
Texture2D<float4> tDepthMap : register(t0);
Texture2D<float4> tDOFMap : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float depth = tDepthMap.Sample(SSPoint_s, v1.xy).x;
  float diff = depth - fDOFFocus;
  float3 limits = (depth < fDOFFocus) ? float3(fDOFCorrectParamNear, -fDOFNearLimit, 0.0f) : float3(fDOFCorrectParamFar, 0.0f, fDOFFarLimit);
  float coc = min(limits.z, max(limits.y, diff * limits.x));
  o0.w = abs(coc);
  o0.xyz = tDOFMap.Sample(SSFilter_s, v1.xy).xyz * fDOFGradateColor;
  // RenoDX: DOF strength scales the blur blend factor (0 = sharp, 1 = vanilla).
  o0.w *= RENODX_FX_DOF;
}
