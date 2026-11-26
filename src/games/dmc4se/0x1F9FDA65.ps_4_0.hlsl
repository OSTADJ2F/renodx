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
  out float4 o0 : SV_TARGET0)
{
  float lumaNW = AAColorLuma(tBaseMap.SampleLevel(SSLinear_s, v1.zw, 0).xyz);
  float lumaNE = AAColorLuma(tBaseMap.SampleLevel(SSLinear_s, v1.zw, 0, int2(1, 0)).xyz);
  float lumaSW = AAColorLuma(tBaseMap.SampleLevel(SSLinear_s, v1.zw, 0, int2(0, 1)).xyz);
  float lumaSE = AAColorLuma(tBaseMap.SampleLevel(SSLinear_s, v1.zw, 0, int2(1, 1)).xyz);

  float2 dir;
  dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
  dir.y = (lumaNW + lumaSW) - (lumaNE + lumaSE);
  float dirReduce = max((((lumaNW + lumaNE) + lumaSW) + lumaSE) * 0.03125, 0.007812);
  float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
  dir = clamp(dir * rcpDirMin, -8.0, 8.0) * fScreenInverseSize;

  float3 wide = (tBaseMap.SampleLevel(SSLinear_s, dir * -0.5 + v1.xy, 0).xyz
               + tBaseMap.SampleLevel(SSLinear_s, dir * 0.5 + v1.xy, 0).xyz) * 0.25;
  float3 narrow = tBaseMap.SampleLevel(SSLinear_s, dir * -0.166667 + v1.xy, 0).xyz
                + tBaseMap.SampleLevel(SSLinear_s, dir * 0.166667 + v1.xy, 0).xyz;
  float3 rgbB = narrow * 0.25 + wide;
  float lumaB = AAColorLuma(rgbB);

  float lumaM = AAColorLuma(tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0).xyz);
  float lumaMin = min(min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)), lumaM);
  float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
  o0.xyz = (lumaB < lumaMin || lumaMax < lumaB) ? narrow * 0.5 : rgbB;
  o0.w = 1.0;
}
