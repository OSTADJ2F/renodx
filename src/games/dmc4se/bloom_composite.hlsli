#ifndef SRC_DMC4SE_BLOOM_COMPOSITE_HLSLI_
#define SRC_DMC4SE_BLOOM_COMPOSITE_HLSLI_

#include "./shared.h"

// Hue-preserving soft cap on the max channel (L in composite-domain white units, 0 = off).
float3 BloomSoftCap(float3 bloom) {
  float cap = RENODX_FX_BLOOM_SOFT_CAP;
  if (cap > 0.f) bloom *= 1.f / (1.f + max(bloom.x, max(bloom.y, bloom.z)) / cap);
  return bloom;
}

// Soft cap, then fade bloom over dark scene pixels. scene_display is display-encoded (clip point 1.0).
float3 BloomShape(float3 bloom, float3 scene_display) {
  float gate = smoothstep(0.02f, 0.35f, renodx::color::y::from::BT709(scene_display));
  return BloomSoftCap(bloom) * lerp(1.f, gate, RENODX_FX_BLOOM_DARK_GATE);
}

// Display-domain composite for modes 0..2 (mode 3 never reaches here). bloom is already shaped.
// headroom_ref is the scene value Headroom measures against (vanilla's 8-bit clip).
float3 BloomCombine(float3 scene, float3 bloom, float3 headroom_ref) {
  if (RENODX_FX_BLOOM_MODE == 1.f) return scene + min(bloom, max(0.f, 1.f - headroom_ref));
  if (RENODX_FX_BLOOM_MODE == 2.f) return lerp(scene, bloom, RENODX_FX_BLOOM_MIX);
  return scene + bloom;
}

// Mode 3: bloom added after ToneMapPass (linear, 1.0 = diffuse white), capped to the peak.
float3 BloomPostToneMap(float3 tone_mapped, float3 bloom, float3 scene_display) {
  float peak = RENODX_PEAK_WHITE_NITS / RENODX_DIFFUSE_WHITE_NITS;
  float3 added = tone_mapped + renodx::color::srgb::DecodeSafe(saturate(BloomShape(bloom, scene_display)));
  return min(added, max(tone_mapped, peak));
}

// Path A HDR tail. curve = vanilla tone curve without bloom (display encoded), untonemapped = HDR input
// without bloom (display encoded), bloom = scaled game bloom terms.
float3 BloomToneMapPass(float3 curve, float3 untonemapped, float3 bloom) {
  float3 vanilla_lin = renodx::color::srgb::DecodeSafe(curve);
  if (RENODX_FX_BLOOM_MODE == 3.f) {
    return renodx::draw::RenderIntermediatePass(BloomPostToneMap(
        renodx::draw::ToneMapPass(renodx::color::srgb::DecodeSafe(untonemapped), vanilla_lin, vanilla_lin), bloom, curve));
  }
  float3 shaped = BloomShape(bloom, curve);
  vanilla_lin = renodx::color::srgb::DecodeSafe(BloomCombine(curve, shaped, curve));
  return renodx::draw::RenderIntermediatePass(renodx::draw::ToneMapPass(
      renodx::color::srgb::DecodeSafe(BloomCombine(untonemapped, shaped, curve)), vanilla_lin, vanilla_lin));
}

#endif  // SRC_DMC4SE_BLOOM_COMPOSITE_HLSLI_
