#ifndef SRC_GAMES_GUARDIANSOFTHEGALAXY_NRD_COMMON_HLSLI_
#define SRC_GAMES_GUARDIANSOFTHEGALAXY_NRD_COMMON_HLSLI_

// Requires shared.h (RENODX_NRD_* settings) and the pass's cbuffer (*_game fields) to be declared before use.
// Accumulation depth, scaled by nrd_accumulation (1.0 keeps the game value), capped at 63.
#define gSpecMaxAccumulatedFrameNum (RENODX_NRD_ACCUMULATION == 1.f ? gSpecMaxAccumulatedFrameNum_game : min(63.f, round(gSpecMaxAccumulatedFrameNum_game * RENODX_NRD_ACCUMULATION)))
// Spec blur radius, scaled by nrd_blur_radius.
#define gSpecBlurRadius (gSpecBlurRadius_game * RENODX_NRD_BLUR_RADIUS)
// Plane distance sensitivity, scaled by nrd_plane_sensitivity.
#define gPlaneDistSensitivity (gPlaneDistSensitivity_game * RENODX_NRD_PLANE_SENSITIVITY)
// Normal weight strictness, scaled by nrd_normal_strictness.
#define gNormalWeightStrictness (gNormalWeightStrictness_game * RENODX_NRD_NORMAL_STRICTNESS)
// Checkerboard mode, forced to 2 when rt_full_res is on, otherwise the game value.
#define gSpecCheckerboard (RENODX_RT_FULL_RES > 0.5f ? 2u : gSpecCheckerboard_game)

#endif  // SRC_GAMES_GUARDIANSOFTHEGALAXY_NRD_COMMON_HLSLI_
