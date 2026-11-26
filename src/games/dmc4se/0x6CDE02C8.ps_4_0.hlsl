#include "./shared.h"
#include "./bloom_composite.hlsli"

cbuffer CBColorCorrectMatrix : register(b0)
{
  row_major float4x4 fColorCorrectMatrix : packoffset(c0);
}

cbuffer CBColorCorrectColor : register(b1)
{
  float4 fColorCorrectColor : packoffset(c0);
}

cbuffer CBColorCorrectGamma : register(b2)
{
  float3 fColorCorrectGamma : packoffset(c0);
}

SamplerState SSPoint_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);
SamplerState SSBloom_s : register(s7);
Texture2D<float4> tBloom : register(t7);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 base = tBaseMap.Sample(SSPoint_s, v1.xy);
  float w = fColorCorrectColor.w;

  float3 matrix_out = base.x * fColorCorrectMatrix._m00_m01_m02
                    + base.y * fColorCorrectMatrix._m10_m11_m12
                    + base.z * fColorCorrectMatrix._m20_m21_m22
                    + fColorCorrectMatrix._m30_m31_m32;
  float3 c = max(matrix_out * w + base.xyz * (-w + 1), 0);

  // RenoDX: type 0 is vanilla (gamma on the whole value).
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) {
    o0.xyz = exp(log(c) * fColorCorrectGamma);
  } else {
    // Gamma only on the 0..1 part; above 1 extend linearly with slope 1.
    float3 below = min(c, 1.f);
    float3 hdr = exp(log(below) * fColorCorrectGamma) + (c - below);
    if (CUSTOM_TONE_MAPPED == 0.f) {
      // Nothing tone mapped yet: vanilla math on the saturated input is the SDR reference.
      float3 base_sdr = saturate(base.xyz);
      float3 sdr_c = max((base_sdr.x * fColorCorrectMatrix._m00_m01_m02
                        + base_sdr.y * fColorCorrectMatrix._m10_m11_m12
                        + base_sdr.z * fColorCorrectMatrix._m20_m21_m22
                        + fColorCorrectMatrix._m30_m31_m32) * w + base_sdr * (-w + 1), 0);
      float3 vanilla_sdr = renodx::color::srgb::DecodeSafe(exp(log(sdr_c) * fColorCorrectGamma));
      float3 graded_hdr = renodx::color::srgb::DecodeSafe(hdr);
      float3 graded = lerp(graded_hdr, renodx::draw::ComputeUntonemappedGraded(graded_hdr, vanilla_sdr), RENODX_HIGHLIGHT_HUE);
      float3 tone_mapped = renodx::draw::ToneMapPass(graded);
      if (RENODX_FX_BLOOM_MODE == 3.f && CUSTOM_BLOOM_BOUND != 0.f) {
        // Approximation: C74A047B's gXfScaleColor.x is not available here, so the bloom scale is the RENODX_FX_BLOOM slider alone.
        tone_mapped = BloomPostToneMap(tone_mapped, tBloom.SampleLevel(SSBloom_s, v1.xy, 0).xyz * RENODX_FX_BLOOM, hdr);
      }
      hdr = renodx::draw::RenderIntermediatePass(tone_mapped);
    }
    o0.xyz = hdr;
  }
  o0.w = base.w;
}
