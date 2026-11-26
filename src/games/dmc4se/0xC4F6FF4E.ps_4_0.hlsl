#include "./shared.h"

cbuffer CBImagePlane : register(b0)
{
  float4 fImagePlaneColor : packoffset(c0);
  row_major float4x4 fImagePlaneUVTransform : packoffset(c1);
}

SamplerState SSFilter_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);
Texture2D<float4> tFilterTempMap1 : register(t1);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 plane = tBaseMap.Sample(SSFilter_s, v1.zw);
  float3 invColor = 1.0 - plane.xyz * fImagePlaneColor.xyz;
  float alpha = plane.w * fImagePlaneColor.w;
  float4 scene = tFilterTempMap1.Sample(SSFilter_s, v1.xy);
  float3 blendBase = scene.xyz;
  if (RENODX_PEAK_WHITE_NITS != 0 && RENODX_TONE_MAP_TYPE != 0) {
    // RenoDX: screen against the 0-1 part of the scene; the excess is added back below.
    blendBase = saturate(scene.xyz);
  }
  float3 r = -invColor * (1.0 - blendBase) - blendBase + 1.0;
  o0.xyz = alpha * r + scene.xyz;
  o0.w = 1.0;
}
