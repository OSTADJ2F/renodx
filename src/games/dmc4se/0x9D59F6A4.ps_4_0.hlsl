#include "./shared.h"

cbuffer CBHDRFactor : register(b0)
{
  float fHDRCompressEncode : packoffset(c0);
  float fHDRCompressDecode : packoffset(c0.y);
  float fHDRRelativeEncode : packoffset(c0.z);
  float fHDRRelativeDecode : packoffset(c0.w);
}

cbuffer CBROPTest : register(b1)
{
  float fAlphaRef : packoffset(c0);
  float fStencilRef : packoffset(c0.y);
  float fDepthBias : packoffset(c0.z);
  float fAlphaToCoverageScale : packoffset(c0.w);
  float fGlobalTransparency : packoffset(c1);
}

cbuffer CBGUICoord : register(b2)
{
  float4 fGUIUVClamp : packoffset(c0);
  float2 fGUIInvTextureSize : packoffset(c1);
}

SamplerState SSGUI_s : register(s0);
Texture2D<float4> tGUIBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float2 v2 : TEXCOORD1,
  out float4 o0 : SV_TARGET0)
{
  float2 size = fGUIUVClamp.zw - fGUIUVClamp.xy;
  float2 r1 = v2 / size;
  float2 f = frac(abs(r1));
  f = (r1 >= -r1) ? f : -f;
  float4 r0 = tGUIBaseMap.Sample(SSGUI_s, f * size + fGUIUVClamp.xy);
  r0 *= v1;
  if (fAlphaRef >= r0.w) {
    discard;
  }
  o0.xyz = r0.xyz * fHDRCompressEncode;
  // RenoDX: the UI is composited into the scene before tone mapping; keep it at UI brightness.
  if (!(RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0)) {
    float ui_scale = RENODX_GRAPHICS_WHITE_NITS / RENODX_DIFFUSE_WHITE_NITS;
    o0.xyz = min(o0.xyz * ui_scale, ui_scale);
  }
  o0.w = r0.w;
}
