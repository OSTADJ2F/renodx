#include "./shared.h"

cbuffer CBGodRaysFilter : register(b0)
{
  float3 fGodRaysOrigin : packoffset(c0);
  float fGodRaysMaskWeight : packoffset(c0.w);
  float3 fGodRaysWorldOrigin : packoffset(c1);
  float fGodRaysMaskRadius : packoffset(c1.w);
  float fGodRaysDecay : packoffset(c2);
  float fGodRaysThreshold : packoffset(c2.y);
  float fGodRaysSamples : packoffset(c2.z);
  float fGodRaysGamma : packoffset(c2.w);
  float4 fGodRaysColor : packoffset(c3);
  float fGodRaysShadowThreshold : packoffset(c4);
  float fGodRaysBlurWidthScale : packoffset(c4.y);
  float fGodRaysBlurWidthOffset : packoffset(c4.z);
}

SamplerState SSBorderLinear_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0 = tBaseMap.Sample(SSBorderLinear_s, v1.xy);
  r0.xyz = r0.xyz / r0.w;
  float4 r1;
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) {
    r1.xyz = exp2(log2(r0.xyz) * fGodRaysGamma);
  } else {
    // RenoDX: apply the gamma to the part within 0..1 only, then scale the highlights back.
    float3 x = max(r0.xyz, 0.f);
    float m = max(max(x.r, max(x.g, x.b)), 1.f);
    r1.xyz = exp2(log2(x / m) * fGodRaysGamma) * m;
  }
  r1.w = exp2(log2(1.f) * fGodRaysGamma);
  o0 = r1 * fGodRaysColor;
  o0.xyz *= RENODX_FX_GOD_RAYS;
}
