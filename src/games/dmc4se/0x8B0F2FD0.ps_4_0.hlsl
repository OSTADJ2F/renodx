#include "./aa_luma.hlsli"

cbuffer CBScreen : register(b0)
{
  float2 fScreenOffset : packoffset(c0);
  float2 fScreenScale : packoffset(c0.z);
  float2 fScreenSize : packoffset(c1);
  float2 fScreenInverseSize : packoffset(c1.z);
  float2 fScreenHalfPixelOffset : packoffset(c2);
}

SamplerState SSLinear_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  out float4 o0 : SV_TARGET0)
{
  // Luma lives in alpha (written by the pass before); the edge tests use it saturated.
  float lumaA = AAEdgeValue(tBaseMap.SampleLevel(SSLinear_s, float2(v2.x, v1.w), 0).w) + 0.002604;
  float lumaB = AAEdgeValue(tBaseMap.SampleLevel(SSLinear_s, float2(v1.z, v2.y), 0).w);
  float lumaC = AAEdgeValue(tBaseMap.SampleLevel(SSLinear_s, v1.zw, 0).w);
  float lumaD = AAEdgeValue(tBaseMap.SampleLevel(SSLinear_s, v2.xy, 0).w);
  float4 center = tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0);
  float lumaM = AAEdgeValue(center.w);

  float lumaMin4 = min(min(lumaB, lumaC), min(lumaA, lumaD));
  float lumaMax4 = max(max(lumaB, lumaC), max(lumaA, lumaD));
  float range = min(lumaM, lumaMin4);
  range = max(lumaM, lumaMax4) - range;

  if (range >= max(lumaMax4 * 0.125, 0.05)) {
    float2 halfSize = fScreenInverseSize * 0.5;
    float t = lumaB - lumaA;
    float3 dir;
    dir.x = lumaD + (t - lumaC);
    dir.y = 0;
    dir.z = (lumaC + t) - lumaD;
    dir.xy = dir.xz * rsqrt(dot(dir, dir));
    float dirMin = min(abs(dir.y), abs(dir.x)) * 8.0;
    float2 dir2 = clamp(dir.xy / dirMin, -2.0, 2.0);

    float4 narrow = (tBaseMap.SampleLevel(SSLinear_s, -dir.xy * halfSize + v1.xy, 0)
                   + tBaseMap.SampleLevel(SSLinear_s, dir.xy * halfSize + v1.xy, 0)) * 0.5;
    float4 wide = (tBaseMap.SampleLevel(SSLinear_s, -dir2 * (fScreenInverseSize + fScreenInverseSize) + v1.xy, 0)
                 + tBaseMap.SampleLevel(SSLinear_s, dir2 * (fScreenInverseSize + fScreenInverseSize) + v1.xy, 0)) * 0.5 + narrow;
    wide = wide * 0.5;
    float wideLuma = AAEdgeValue(wide.w);
    o0 = (wideLuma < lumaMin4 || lumaMax4 < wideLuma) ? narrow : wide;
  } else {
    o0 = center;
  }
}
