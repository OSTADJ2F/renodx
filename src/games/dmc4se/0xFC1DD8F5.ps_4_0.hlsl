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
Texture2D<float4> tBaseMap : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0 = tDepthMap.Sample(SSPoint_s, v1.xy);
  o0.w = (fDOFFocus < r0.x) ? 1.0 : r0.x;
  o0.w *= RENODX_FX_DOF;
  r0 = tBaseMap.Sample(SSFilter_s, v1.xy);
  o0.xyz = r0.xyz;
}
