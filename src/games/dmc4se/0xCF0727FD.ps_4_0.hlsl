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

cbuffer CBBokehComposite : register(b1)
{
  float fBokehMipBias : packoffset(c0);
  float fBokehMipScale : packoffset(c0.y);
  float fBokehAlphaScale : packoffset(c0.z);
  float fBokehRangeScale : packoffset(c0.w);
  float fBokehDitherScale : packoffset(c1);
  float2 fBokehTap[25] : packoffset(c2);
}

SamplerState SSPoint_s : register(s0);
SamplerState SSLinear_s : register(s1);
Texture2D<float4> tDepthMap : register(t0);
Texture2D<float4> tBaseMap : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0, r1, r2;
  r0 = tDepthMap.Sample(SSPoint_s, v1.xy);
  r1.xyz = (r0.x < fDOFFocus) ? float3(fDOFCorrectParamNear, -fDOFNearLimit, 0.0) : float3(fDOFCorrectParamFar, 0.0, fDOFFarLimit);
  r0.y = r0.x - fDOFFocus;
  r0.y = r1.x * r0.y;
  r0.y = max(r1.y, r0.y);
  r0.y = min(r1.z, r0.y);
  if (0.0001 >= r0.y) {
    r0.x = r0.x * fDOFCoCScale - fDOFCoCBias;
    r0.x = abs(r0.y) * abs(r0.x);
    r0.z = r0.x * fBokehMipScale + fBokehMipBias;
    r0.z = max(r0.z, 0.0);
    r1.xy = fBokehTap[0] * r0.x + v1.xy;
    r1 = tBaseMap.SampleLevel(SSLinear_s, r1.xy, r0.z);
    r0.w = 1.0 - r1.w;
    r2.xy = fBokehTap[1] * r0.x + v1.xy;
    r2 = tBaseMap.SampleLevel(SSLinear_s, r2.xy, r0.z);
    r1.w = 1.0 - r2.w;
    r2.xyz = r2.xyz * r1.w;
    r1.xyz = r0.w * r1.xyz + r2.xyz;
    r0.w = r0.w + r1.w;
    [unroll]
    for (int i = 2; i < 19; i++) {
      r2.xy = fBokehTap[i] * r0.x + v1.xy;
      r2 = tBaseMap.SampleLevel(SSLinear_s, r2.xy, r0.z);
      r1.w = 1.0 - r2.w;
      r1.xyz = r1.w * r2.xyz + r1.xyz;
      r0.w = r0.w + r1.w;
    }
    r0.z = r0.w;
    r1.xyz = r1.xyz / r0.z;
    r0.y = saturate(-r0.y * fBokehAlphaScale);
    r0.y = r0.y + r0.y;
    r0.w = r0.z / 19.0;
    r0.y = r0.y * r0.w;
    r0.x = saturate(r0.x * 3.0);
    o0.w = min(r0.y, r0.x);
  } else {
    r1.xyz = float3(0.0, 0.0, 0.0);
    r0.z = 0.0;
    o0.w = 0.0;
  }
  if (r0.z == 0.0) {
    r0 = tBaseMap.Sample(SSLinear_s, v1.xy);
    r1.xyz = r0.xyz;
  }
  o0.w *= RENODX_FX_DOF;
  o0.xyz = r1.xyz * fDOFGradateColor;
}
