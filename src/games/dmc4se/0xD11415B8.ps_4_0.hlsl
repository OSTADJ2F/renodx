#include "./bloom_bright_pass.hlsli"

void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float3 x = tFilterPoint0.Sample(SSWrapPoint_s, v1).xyz;
  float l = dot(x, 0.33333f);
  // Vanilla caps the luminance at 2; HDR leaves it uncapped (factor -> 1, so the output is already unbounded).
  if (RENODX_PEAK_WHITE_NITS != 0 && RENODX_TONE_MAP_TYPE != 0) {
    l = min(l, 4.f * RENODX_PEAK_WHITE_NITS / RENODX_GRAPHICS_WHITE_NITS);
  } else {
    l = min(l, 2.f);
  }
  o0.xyz = x * ((l > 0.f) ? max(l - gXfBrightPassThreshold, 0.f) / l : 0.f) * gXfScaleColor.xyz;
  o0.w = 1;
}
