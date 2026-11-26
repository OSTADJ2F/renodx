#include "./shared.h"

SamplerState SSLinear_s : register(s0);
Texture2D<float4> tYUVDecoderY : register(t0);
Texture2D<float4> tYUVDecoderU : register(t1);
Texture2D<float4> tYUVDecoderV : register(t2);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float v = tYUVDecoderV.Sample(SSLinear_s, v1.xy).w - 0.5f;
  float u = tYUVDecoderU.Sample(SSLinear_s, v1.xy).w - 0.5f;
  float y = (tYUVDecoderY.Sample(SSLinear_s, v1.xy).w - 0.0625f) * 1.164f;
  o0.x = v * 1.596f + y;
  o0.y = u * -0.391f - v * 0.813f + y;
  o0.z = u * 2.018f + y;
  if (!(RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0)) {
    o0.xyz = saturate(o0.xyz);
  }
  o0.w = 1.0f;
}
