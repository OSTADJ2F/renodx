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

SamplerState SSPoint_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);
Texture1D<float4> tColorCorrectTableMap : register(t1);
SamplerState SSBloom_s : register(s7);
Texture2D<float4> tBloom : register(t7);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 base = tBaseMap.Sample(SSPoint_s, v1.xy);
  float w = fColorCorrectColor.w;

  // [RenoDX] Vanilla: the original math, untouched. Guard: tone map type 0 or peak nits 0 is exact vanilla.
  if (RENODX_TONE_MAP_TYPE == 0.f || RENODX_PEAK_WHITE_NITS == 0.f) {
    // Row-major matrix: base.x * row0 + base.y * row1 + base.z * row2 + row3.
    float3 lut_coord = base.x * fColorCorrectMatrix._m00_m01_m02
                     + base.y * fColorCorrectMatrix._m10_m11_m12
                     + base.z * fColorCorrectMatrix._m20_m21_m22
                     + fColorCorrectMatrix._m30_m31_m32;

    // Per-channel 1D LUT lookups; each channel takes its own lookup's matching component.
    float3 lut;
    lut.x = tColorCorrectTableMap.SampleLevel(SSPoint_s, lut_coord.x, 0).x;
    lut.y = tColorCorrectTableMap.SampleLevel(SSPoint_s, lut_coord.y, 0).y;
    lut.z = tColorCorrectTableMap.SampleLevel(SSPoint_s, lut_coord.z, 0).z;

    // Blend: LUT at weight w, original color at (1 - w).
    o0.xyz = lut * w + base.xyz * (1 - w);
  } else {
    // [RenoDX] The scene and table are in display gamma and the HDR scene is unclamped (the scene clamp is skipped).
    float3 untonemapped_enc = max(0.f, base.xyz);

    // The matrix on the unclamped base pushes values past the table's 0..1 address range (a hard clip in vanilla).
    // Normalise by the max channel so the table is sampled in range, then restore the scale in gamma space.
    // Where the matrix result stays within 0..1 this equals the vanilla grade.
    float3 matrix_out = untonemapped_enc.x * fColorCorrectMatrix._m00_m01_m02
                      + untonemapped_enc.y * fColorCorrectMatrix._m10_m11_m12
                      + untonemapped_enc.z * fColorCorrectMatrix._m20_m21_m22
                      + fColorCorrectMatrix._m30_m31_m32;
    float scale = max(1.f, max(matrix_out.x, max(matrix_out.y, matrix_out.z)));
    float3 lut_coord = matrix_out / scale;
    float3 lut;
    lut.x = tColorCorrectTableMap.SampleLevel(SSPoint_s, lut_coord.x, 0).x;
    lut.y = tColorCorrectTableMap.SampleLevel(SSPoint_s, lut_coord.y, 0).y;
    lut.z = tColorCorrectTableMap.SampleLevel(SSPoint_s, lut_coord.z, 0).z;
    lut *= scale;

    // Input already tone mapped and intermediate-encoded upstream: same grade and blend, no further tone map.
    if (CUSTOM_TONE_MAPPED != 0.f) {
      o0.xyz = lut * w + untonemapped_enc * (1 - w);
      o0.w = base.w;
      return;
    }

    // Same blend as vanilla, in gamma space.
    float3 graded_enc = lut * w + untonemapped_enc * (1 - w);
    float3 graded_hdr = renodx::color::srgb::DecodeSafe(graded_enc);

    // Vanilla clipped warm highlights toward white; this restores that hue from the vanilla clipped grade.
    float3 base_sdr = saturate(base.xyz);
    float3 mv = base_sdr.x * fColorCorrectMatrix._m00_m01_m02 + base_sdr.y * fColorCorrectMatrix._m10_m11_m12
              + base_sdr.z * fColorCorrectMatrix._m20_m21_m22 + fColorCorrectMatrix._m30_m31_m32;
    float3 lv;
    lv.x = tColorCorrectTableMap.SampleLevel(SSPoint_s, mv.x, 0).x;
    lv.y = tColorCorrectTableMap.SampleLevel(SSPoint_s, mv.y, 0).y;
    lv.z = tColorCorrectTableMap.SampleLevel(SSPoint_s, mv.z, 0).z;
    float3 vanilla_sdr = renodx::color::srgb::DecodeSafe(lv * w + base_sdr * (1 - w));
    float3 graded = lerp(graded_hdr, renodx::draw::ComputeUntonemappedGraded(graded_hdr, vanilla_sdr), RENODX_HIGHLIGHT_HUE);
    float3 tone_mapped = renodx::draw::ToneMapPass(graded);
    if (RENODX_FX_BLOOM_MODE == 3.f && CUSTOM_BLOOM_BOUND != 0.f) {
      // Approximation: C74A047B's gXfScaleColor.x is not available here, so the bloom scale is the RENODX_FX_BLOOM slider alone.
      tone_mapped = BloomPostToneMap(tone_mapped, tBloom.SampleLevel(SSBloom_s, v1.xy, 0).xyz * RENODX_FX_BLOOM, graded_enc);
    }
    o0.xyz = renodx::draw::RenderIntermediatePass(tone_mapped);
  }
  o0.w = base.w;
}
