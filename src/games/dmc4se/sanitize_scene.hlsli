#ifndef SRC_DMC4SE_SANITIZE_SCENE_HLSLI_
#define SRC_DMC4SE_SANITIZE_SCENE_HLSLI_

// The RGBA16F scene can hold NaN/Inf (the original UNORM targets could not).
// D3D10 max/min return the non-NaN operand, so max(x, 0) maps NaN to 0.
float3 SanitizeScene(float3 color) {
  return min(max(color, 0.f), 65000.f);
}

#endif  // SRC_DMC4SE_SANITIZE_SCENE_HLSLI_
