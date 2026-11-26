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
SamplerState SSLinear_s : register(s1);
Texture2D<float4> tDepthMap : register(t0);
Texture2D<float4> tDOFMap : register(t1);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1,r2,r3,r4,r5;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = tDepthMap.Sample(SSPoint_s, v1.xy);
  r0.y = cmp(r0.x < fDOFFocus);
  r1.x = fDOFCorrectParamNear;
  r1.y = -fDOFNearLimit;
  r1.z = 0;
  r2.x = fDOFCorrectParamFar;
  r2.y = 0;
  r2.z = fDOFFarLimit;
  r3.xyz = r0.yyy ? r1.xyz : r2.xyz;
  r0.y = -fDOFFocus + r0.x;
  r0.y = r0.y * r3.x;
  r0.y = max(r0.y, r3.y);
  r0.y = min(r0.y, r3.z);
  r0.x = r0.x * fDOFCoCScale + -fDOFCoCBias;
  r0.x = fDOFRadiusScale * abs(r0.x);
  r3.xyzw = float4(0,0,0,0);
  r0.z = 0;
  while (true) {
    r0.w = cmp((int)r0.z >= 8);
    if (r0.w != 0) break;
    r4.xy = r0.xx * fDOFPoissonOffsets[r0.z].xy + v1.xy;
    r4.xyzw = tDOFMap.Sample(SSLinear_s, r4.xy);
    r5.xyz = fDOFGradateColor.xyz * r4.xyz;
    r0.w = cmp(r4.w < fDOFFocus);
    r4.xyz = r0.www ? r1.xyz : r2.xyz;
    r0.w = -fDOFFocus + r4.w;
    r0.w = r0.w * r4.x;
    r0.w = max(r0.w, r4.y);
    r0.w = min(r0.w, r4.z);
    r1.w = cmp(r0.w < r0.y);
    r2.w = cmp(r0.w < 0);
    r1.w = r1.w ? r2.w : 0;
    r0.w = max(abs(r0.w), abs(r0.y));
    r5.w = r1.w ? r0.w : abs(r0.y);
    r3.xyzw = r5.xyzw + r3.xyzw;
    r0.z = (int)r0.z + 1;
  }
  o0.xyzw = r3.xyzw / float4(8,8,8,8);
  o0.w = saturate(o0.w);
  return;
}