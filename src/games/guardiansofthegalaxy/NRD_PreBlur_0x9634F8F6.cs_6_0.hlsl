#include "./shared.h"
Texture2D<float4> gIn_Normal_Roughness : register(t0);

Texture2D<float> gIn_ViewZ : register(t1);

Texture2D<float4> gIn_Spec : register(t2);

RWTexture2D<float> gOut_ScaledViewZ : register(u0);

RWTexture2D<float4> gOut_Spec : register(u1);

cbuffer _REBLUR_Specular_PreBlur : register(b0) {
  float4 gViewToClip[4] : packoffset(c000.x);
  float4 gFrustum : packoffset(c004.x);
  float4 gSpecHitDistParams : packoffset(c005.x);
  float2 gInvScreenSize : packoffset(c006.x);
  float2 gScreenSize : packoffset(c006.z);
  float2 gInvRectSize : packoffset(c007.x);
  float2 gRectSize : packoffset(c007.z);
  float2 gRectSizePrev : packoffset(c008.x);
  float2 gResolutionScale : packoffset(c008.z);
  float2 gRectOffset : packoffset(c009.x);
  uint2 gRectOrigin : packoffset(c009.z);
  float gReference : packoffset(c010.x);
  float gIsOrtho : packoffset(c010.y);
  float gUnproject : packoffset(c010.z);
  float gDebug : packoffset(c010.w);
  float gInf : packoffset(c011.x);
  float gPlaneDistSensitivity_game : packoffset(c011.y);
  float gFramerateScale : packoffset(c011.z);
  float gJitterDelta : packoffset(c011.w);
  float gSpecBlurRadius_game : packoffset(c012.x);
  float gSpecMaxAccumulatedFrameNum_game : packoffset(c012.y);
  uint gWorldSpaceMotion : packoffset(c012.z);
  uint gFrameIndex : packoffset(c012.w);
  float4 gWorldToView[4] : packoffset(c013.x);
  float4 gRotator : packoffset(c017.x);
  float4 gSpecTrimmingParams : packoffset(c018.x);
  uint gSpecCheckerboard_game : packoffset(c019.x);
  uint gSpatialFiltering : packoffset(c019.y);
  float gNormalWeightStrictness_game : packoffset(c019.z);
  float fPadding0 : packoffset(c019.w);
};
#include "./nrd_common.hlsli"

SamplerState MaterialSamplers[1920] : register(s0);

groupshared float _global_0[324];
groupshared float _global_1[1296];

[numthreads(16, 16, 1)]
void main(
  uint3 SV_DispatchThreadID : SV_DispatchThreadID,
  uint3 SV_GroupID : SV_GroupID,
  uint3 SV_GroupThreadID : SV_GroupThreadID,
  uint SV_GroupIndex : SV_GroupIndex
) {
  float _24 = (float((uint)SV_GroupIndex) + 0.5f) * 0.0555555559694767f;
  int _27 = int(frac(_24) * 18.0f);
  int _28 = int(_24);
  uint _31 = (SV_DispatchThreadID.x - SV_GroupThreadID.x) + -1u;
  uint _32 = (SV_DispatchThreadID.y - SV_GroupThreadID.y) + -1u;
  int _151;
  int _152;
  float _410;
  float _411;
  float _412;
  float _413;
  float _604;
  float _605;
  float _606;
  float _607;
  float _608;
  float _609;
  float _748;
  float _749;
  float _750;
  float _928;
  float _929;
  float _930;
  float _1095;
  float _1096;
  float _1097;
  float _1262;
  float _1263;
  float _1264;
  float _1429;
  float _1430;
  float _1431;
  float _1596;
  float _1597;
  float _1598;
  float _1763;
  float _1764;
  float _1765;
  float _1930;
  float _1931;
  float _1932;
  if ((int)_28 < (int)14) {
    uint _40 = (_27 + _31) + (int)(gRectOrigin.x);
    uint _41 = (_28 + _32) + (int)(gRectOrigin.y);
    float4 _42 = gIn_Normal_Roughness.Load(int3(_40, _41, 0));
    float _50 = (_42.x * 2.0f) + -1.0f;
    float _51 = (_42.y * 2.0f) + -1.0f;
    float _52 = (_42.z * 2.0f) + -1.0f;
    float _54 = rsqrt(dot(float3(_50, _51, _52), float3(_50, _51, _52)));
    _global_1[((uint)(0u + (((uint)(_27 + (_28 * 18))) * 4)))] = (_50 * _54);
    _global_1[((uint)(1u + (((uint)(_27 + (_28 * 18))) * 4)))] = (_51 * _54);
    _global_1[((uint)(2u + (((uint)(_27 + (_28 * 18))) * 4)))] = (_52 * _54);
    _global_1[((uint)(3u + (((uint)(_27 + (_28 * 18))) * 4)))] = _42.w;
    float _78 = gIn_ViewZ.Load(int3(_40, _41, 0));
    _global_0[((uint)(_27 + (_28 * 18)))] = abs(_78.x);
  }
  int _85 = _28 + 14;
  if ((int)_85 < (int)18) {
    uint _93 = (_27 + _31) + (int)(gRectOrigin.x);
    uint _94 = (_85 + _32) + (int)(gRectOrigin.y);
    float4 _95 = gIn_Normal_Roughness.Load(int3(_93, _94, 0));
    float _103 = (_95.x * 2.0f) + -1.0f;
    float _104 = (_95.y * 2.0f) + -1.0f;
    float _105 = (_95.z * 2.0f) + -1.0f;
    float _107 = rsqrt(dot(float3(_103, _104, _105), float3(_103, _104, _105)));
    _global_1[((uint)(0u + (((uint)(_27 + (_85 * 18))) * 4)))] = (_103 * _107);
    _global_1[((uint)(1u + (((uint)(_27 + (_85 * 18))) * 4)))] = (_104 * _107);
    _global_1[((uint)(2u + (((uint)(_27 + (_85 * 18))) * 4)))] = (_105 * _107);
    _global_1[((uint)(3u + (((uint)(_27 + (_85 * 18))) * 4)))] = _95.w;
    float _131 = gIn_ViewZ.Load(int3(_93, _94, 0));
    _global_0[((uint)(_27 + (_85 * 18)))] = abs(_131.x);
  }
  GroupMemoryBarrierWithGroupSync();
  if (!(gSpecCheckerboard == 2)) {
    _151 = ((int)(uint)((bool)(((((uint)(SV_DispatchThreadID.y) ^ (uint)(SV_DispatchThreadID.x)) ^ gFrameIndex) & 1) == gSpecCheckerboard)));
    _152 = ((uint)(SV_DispatchThreadID.x) >> 1);
  } else {
    _151 = 1;
    _152 = (uint)(SV_DispatchThreadID.x);
  }
  uint _153 = SV_GroupThreadID.x + 1u;
  uint _154 = SV_GroupThreadID.y + 1u;
  float _158 = _global_0[((uint)(_153 + (_154 * 18)))];
  gOut_ScaledViewZ[int2((uint)(SV_DispatchThreadID.x), (uint)(SV_DispatchThreadID.y))] = min((_158 * 0.012500000186264515f), 65504.0f);
  [branch]
  if (!(_158 > gInf)) {
    float _170 = _global_1[((uint)(0u + (((uint)(_153 + (_154 * 18))) * 4)))];
    float _176 = _global_1[((uint)(1u + (((uint)(_153 + (_154 * 18))) * 4)))];
    float _182 = _global_1[((uint)(2u + (((uint)(_153 + (_154 * 18))) * 4)))];
    float _188 = _global_1[((uint)(3u + (((uint)(_153 + (_154 * 18))) * 4)))];
    float _203 = mad((gWorldToView[2].x), _182, mad((gWorldToView[1].x), _176, ((gWorldToView[0].x) * _170)));
    float _206 = mad((gWorldToView[2].y), _182, mad((gWorldToView[1].y), _176, ((gWorldToView[0].y) * _170)));
    float _209 = mad((gWorldToView[2].z), _182, mad((gWorldToView[1].z), _176, ((gWorldToView[0].z) * _170)));
    float _224 = ((1.0f - abs(gIsOrtho)) * _158) + gIsOrtho;
    float _225 = _224 * (((gInvRectSize.x * (float((int)((uint)(SV_DispatchThreadID.x))) + 0.5f)) * gFrustum.z) + gFrustum.x);
    float _226 = _224 * (((gInvRectSize.y * (float((int)((uint)(SV_DispatchThreadID.y))) + 0.5f)) * gFrustum.w) + gFrustum.y);
    uint _232 = SV_GroupThreadID.x + 2u;
    uint _254 = SV_GroupThreadID.y + 2u;
    float _297 = ((((_global_1[((uint)(0u + (((uint)(_232 + (_154 * 18))) * 4)))]) + _170) + (_global_1[((uint)(0u + (((uint)(_153 + (_254 * 18))) * 4)))])) + (_global_1[((uint)(0u + (((uint)(_232 + (_254 * 18))) * 4)))])) * 0.25f;
    float _298 = ((((_global_1[((uint)(1u + (((uint)(_232 + (_154 * 18))) * 4)))]) + _176) + (_global_1[((uint)(1u + (((uint)(_153 + (_254 * 18))) * 4)))])) + (_global_1[((uint)(1u + (((uint)(_232 + (_254 * 18))) * 4)))])) * 0.25f;
    float _299 = ((((_global_1[((uint)(2u + (((uint)(_232 + (_154 * 18))) * 4)))]) + _182) + (_global_1[((uint)(2u + (((uint)(_153 + (_254 * 18))) * 4)))])) + (_global_1[((uint)(2u + (((uint)(_232 + (_254 * 18))) * 4)))])) * 0.25f;
    float _308 = saturate((sqrt(((_298 * _298) + (_297 * _297)) + (_299 * _299)) + -0.8500000238418579f) * 6.666667938232422f);
    float _312 = (_308 * _308) * (3.0f - (_308 * 2.0f));
    float _313 = 1.0f - _312;
    float4 _319 = gIn_Spec.Load(int3(((uint)((int)(gRectOrigin.x) + _152)), ((uint)((int)(gRectOrigin.y) + SV_DispatchThreadID.y)), 0));
    float _327 = _global_0[((uint)(SV_GroupThreadID.x + (_154 * 18)))];
    float _331 = _global_0[((uint)(_232 + (_154 * 18)))];
    float _336 = abs(_158);
    float _345 = (1.0f / (min(abs(_327), _336) + 0.0010000000474974513f)) * abs(_327 - _158);
    float _346 = (1.0f / (min(abs(_331), _336) + 0.0010000000474974513f)) * abs(_331 - _158);
    float _357 = select((_345 > 0.05000000074505806f), 0.0f, 1.0f) * (1.0f / ((_345 * 100.0f) + 1.0f));
    float _358 = select((_346 > 0.05000000074505806f), 0.0f, 1.0f) * (1.0f / ((_346 * 100.0f) + 1.0f));
    float _361 = 1.0f / max((_358 + _357), 1.0000000036274937e-15f);
    float _362 = _361 * _357;
    float _363 = _358 * _361;
    uint _372 = (int)(gRectOrigin.y) + SV_DispatchThreadID.y;
    float4 _374 = gIn_Spec.Load(int3(((uint)((int)(gRectOrigin.x) + (((uint)(SV_DispatchThreadID.x + -1u)) >> 1))), _372, 0));
    float4 _375 = gIn_Spec.Load(int3(((uint)((int)(gRectOrigin.x) + (((uint)(SV_DispatchThreadID.x + 1u)) >> 1))), _372, 0));
    if (_151 == 0) {
      float _388 = saturate((1.0f - _362) - _363);
      _410 = (((_375.x * _363) + (_374.x * _362)) + (_388 * _319.x));
      _411 = (((_375.y * _363) + (_374.y * _362)) + (_388 * _319.y));
      _412 = (((_375.z * _363) + (_374.z * _362)) + (_388 * _319.z));
      _413 = (((_375.w * _363) + (_374.w * _362)) + (_388 * _319.w));
    } else {
      _410 = _319.x;
      _411 = _319.y;
      _412 = _319.z;
      _413 = _319.w;
    }
    float4 pt = float4(_410, _411, _412, _413);
    if (RENODX_NRD_PASSTHROUGH > 0.5f && RENODX_NRD_FIREFLY > 0.f) {
      int cx = (int)gRectOrigin.x + _152;
      int cy = (int)(gRectOrigin.y + SV_DispatchThreadID.y);
      uint pw = (gSpecCheckerboard == 2) ? uint(gRectSize.x) : (uint(gRectSize.x) + 1) / 2;
      int xMin = (int)gRectOrigin.x;
      int xMax = (int)(gRectOrigin.x + pw) - 1;
      int yMin = (int)gRectOrigin.y;
      int yMax = (int)(gRectOrigin.y + uint(gRectSize.y)) - 1;
      // Cap at the mean of the 7 darkest of the 8 neighbours, so a neighbouring firefly cannot raise the cap.
      float sum = 0.f;
      float lmax = 0.f;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          float nl = dot(gIn_Spec.Load(int3(clamp(cx + dx, xMin, xMax), clamp(cy + dy, yMin, yMax), 0)).rgb, float3(0.299f, 0.587f, 0.114f));
          sum += nl;
          lmax = max(lmax, nl);
        }
      }
      float rest = (sum - lmax) / 7.f;
      float limit = rest * (2.f + 14.f * (1.f - RENODX_NRD_FIREFLY));
      float l = dot(pt.rgb, float3(0.299f, 0.587f, 0.114f));
      if (l > limit && l > 0.f) {
        pt.rgb *= limit / l;
      }
    }
    [branch]
    if (gSpatialFiltering == 0 || RENODX_NRD_PASSTHROUGH > 0.5f) {
      gOut_Spec[int2((uint)(SV_DispatchThreadID.x), (uint)(SV_DispatchThreadID.y))] = (RENODX_NRD_PASSTHROUGH > 0.5f ? pt : float4(_410, _411, _412, _413));
    } else {
      float _423 = gSpecBlurRadius * (8.0f - (_188 * 4.0f));
      float _431 = _188 * _188;
      float _439 = (((_336 * gSpecHitDistParams.y) + gSpecHitDistParams.x) * _413) * ((saturate(exp2(_431 * gSpecHitDistParams.w)) * (gSpecHitDistParams.z + -1.0f)) + 1.0f);
      float _441 = _439 / (_439 + _158);
      float _443 = log2(saturate(_188));
      float _448 = saturate(1.0f - exp2(_443 * 0.125f)) * _441;
      float _464 = saturate((_188 - gSpecTrimmingParams.y) / (gSpecTrimmingParams.z - gSpecTrimmingParams.y));
      float _467 = _431 * 4.0f;
      float _482 = abs(gIsOrtho);
      float _485 = (_482 * (1.0f - _158)) + _158;
      float _491 = (((((_441 * (1.0f - exp2(_431 * -200.0f))) * (((lerp(_448, 1.0f, 0.125f)) * _423) + (min(3.0f, (_423 * 0.3330000042915344f)) * _188))) * exp2(_443 * 0.25f)) * ((_467 + 1.0f) - (((_464 * _464) * (gSpecTrimmingParams.x * _467)) * (3.0f - (_464 * 2.0f))))) * gUnproject) * _485;
      float _493 = select((_209 < 0.0f), -1.0f, 1.0f);
      float _495 = 1.0f / (_493 + _209);
      float _496 = _495 * _206;
      float _497 = _496 * _203;
      float _498 = _493 * _203;
      float _506 = rsqrt(dot(float3(_225, _226, _158), float3(_225, _226, _158)));
      float _507 = _506 * _225;
      float _508 = _506 * _226;
      float _509 = _506 * _158;
      float _513 = dot(float3(_203, _206, _209), float3((-0.0f - _507), (-0.0f - _508), (-0.0f - _509)));
      float _518 = log2(39.4114990234375f - (_188 * 39.002899169921875f)) * 0.20688709616661072f;
      float _520 = saturate(1.0f - abs(_513));
      float _527 = saturate(((pow(_520, 10.864899635314941f)) * (1.0f - _518)) + _518);
      float _529 = dot(float3(_507, _508, _509), float3(_203, _206, _209)) * 2.0f;
      float _542 = (((_507 - _203) - (_529 * _203)) * _527) + _203;
      float _543 = (((_508 - _206) - (_529 * _206)) * _527) + _206;
      float _544 = (((_509 - _209) - (_529 * _209)) * _527) + _209;
      float _546 = rsqrt(dot(float3(_542, _543, _544), float3(_542, _543, _544)));
      float _547 = _542 * _546;
      float _548 = _543 * _546;
      float _549 = _544 * _546;
      if ((bool)(_188 < 0.800000011920929f) && (bool)(abs(dot(float3(_203, _206, _209), float3(_547, _548, _549))) < 0.9990000128746033f)) {
        float _558 = -0.0f - _547;
        float _559 = -0.0f - _548;
        float _560 = -0.0f - _549;
        float _562 = dot(float3(_558, _559, _560), float3(_203, _206, _209)) * 2.0f;
        float _566 = _558 - (_562 * _203);
        float _567 = _559 - (_562 * _206);
        float _568 = _560 - (_562 * _209);
        float _571 = (_568 * _206) - (_567 * _209);
        float _574 = (_566 * _209) - (_568 * _203);
        float _577 = (_567 * _203) - (_566 * _206);
        float _579 = rsqrt(dot(float3(_571, _574, _577), float3(_571, _574, _577)));
        float _580 = _571 * _579;
        float _581 = _574 * _579;
        float _582 = _577 * _579;
        float _596 = (_527 * (_188 + -1.0f)) * sqrt(saturate(_520));
        float _599 = (_596 + 1.0f) - (_596 * (_313 + (_312 * 0.125f)));
        _604 = (_599 * _580);
        _605 = (_599 * _581);
        _606 = (_599 * _582);
        _607 = ((_582 * _567) - (_581 * _568));
        _608 = ((_580 * _568) - (_582 * _566));
        _609 = ((_581 * _566) - (_580 * _567));
      } else {
        _604 = (((_498 * _203) * _495) + -1.0f);
        _605 = (_497 * _493);
        _606 = _498;
        _607 = _497;
        _608 = ((_496 * _206) - _493);
        _609 = _206;
      }
      float _610 = _604 * _491;
      float _611 = _605 * _491;
      float _612 = _606 * _491;
      float _613 = _607 * _491;
      float _614 = _608 * _491;
      float _615 = _609 * _491;
      float _620 = (gPlaneDistSensitivity * 0.8812500238418579f) / (_158 + 1.0f);
      float _621 = dot(float3(_203, _206, _209), float3(_225, _226, _158));
      float _633 = _188 * 2.0f;
      float _637 = (gNormalWeightStrictness * 0.15000000596046448f) * ((_633 + 1.0f) - ((1.0f / (((gUnproject * gScreenSize.y) * _485) + 1.0f)) * _633));
      float _647 = (((0.5f - _637) * _188) * exp2(log2(saturate(1.0f - saturate(_513))) * 5.0f)) + _637;
      float _650 = ((1.0f - _647) * _313) + _647;
      float _657 = exp2(_431 * -17.0f);
      float _664 = 1.0f / (((_413 * 0.9900000095367432f) * (lerp(_657, 1.0f, 0.125f))) + 0.009999999776482582f);
      float _667 = 1.0f / ((_188 * 0.1979999989271164f) + 0.009999999776482582f);
      float _688 = (gRotator.y * -0.44271120429039f) - (gRotator.x * 0.47060689330101013f);
      float _689 = (gRotator.w * -0.44271120429039f) - (gRotator.z * 0.47060689330101013f);
      float _699 = ((_610 * _688) + _225) + (_613 * _689);
      float _700 = ((_611 * _688) + _226) + (_614 * _689);
      float _701 = ((_612 * _688) + _158) + (_615 * _689);
      float _713 = mad((gViewToClip[2].w), _701, mad((gViewToClip[1].w), _700, ((gViewToClip[0].w) * _699))) + (gViewToClip[3].w);
      float _718 = (((mad((gViewToClip[2].x), _701, mad((gViewToClip[1].x), _700, ((gViewToClip[0].x) * _699))) + (gViewToClip[3].x)) / _713) * 0.5f) + 0.5f;
      float _719 = 0.5f - (((mad((gViewToClip[2].y), _701, mad((gViewToClip[1].y), _700, ((gViewToClip[0].y) * _699))) + (gViewToClip[3].y)) / _713) * 0.5f);
      bool _721 = (gSpecCheckerboard == 2);
      if (!_721) {
        int _732 = int(gRectSize.x * _718);
        int _733 = int(gRectSize.y * _719);
        float _744 = (float((int)(_732)) + 0.5f) * gInvRectSize.x;
        _748 = _744;
        _749 = ((float((int)(int((bool)(bool)((((_733 ^ gFrameIndex) ^ _732) & 1) != gSpecCheckerboard)) + _733)) + 0.5f) * gInvRectSize.y);
        _750 = (_744 * 0.5f);
      } else {
        _748 = _718;
        _749 = _719;
        _750 = _718;
      }
      float _759 = (gResolutionScale.x * _748) + gRectOffset.x;
      float _760 = (gResolutionScale.y * _749) + gRectOffset.y;
      float4 _761 = gIn_Normal_Roughness.SampleLevel(MaterialSamplers[6u], float2(_759, _760), 0.0f);
      float4 _768 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(((gResolutionScale.x * _750) + gRectOffset.x), _760), 0.0f);
      float _773 = gIn_ViewZ.SampleLevel(MaterialSamplers[6u], float2(_759, _760), 0.0f);
      float _775 = abs(_773.x);
      float _785 = 1.0f - _482;
      float _787 = (_785 * _775) + gIsOrtho;
      float _793 = (_761.x * 2.0f) + -1.0f;
      float _794 = (_761.y * 2.0f) + -1.0f;
      float _795 = (_761.z * 2.0f) + -1.0f;
      float _797 = rsqrt(dot(float3(_793, _794, _795), float3(_793, _794, _795)));
      float _806 = saturate(1.0f - abs((dot(float3(_203, _206, _209), float3((_787 * ((gFrustum.z * _748) + gFrustum.x)), (_787 * ((gFrustum.w * _749) + gFrustum.y)), _775)) - _621) * _620));
      float _819 = saturate(1.0f - abs((_761.w - _188) * _667));
      float _827 = 1.4142135381698608f / (((lerp(_650, 1.0f, 0.125f)) * atan(_431 * 3.0f)) + 0.010908308438956738f);
      float _832 = saturate(1.0f - abs((_827 * sqrt(saturate(1.0f - saturate(dot(float3(_170, _176, _182), float3((_797 * _793), (_797 * _794), (_797 * _795))))))) + -0.0010000000474974513f));
      float _849 = saturate(1.0f - abs((_768.w - _413) * _664));
      float _856 = ((((_849 * _849) * (3.0f - (_849 * 2.0f))) * 0.6000000238418579f) + 0.4000000059604645f) * (((_832 * _832) * (((((((_806 * _806) * 0.7591724991798401f) * (3.0f - (_806 * 2.0f))) * _819) * float((bool)((bool)((bool)(saturate(_748) == _748) && (bool)(saturate(_749) == _749))))) * _819) * (3.0f - (_819 * 2.0f)))) * (3.0f - (_832 * 2.0f)));
      float _870 = (gRotator.y * 0.30034708976745605f) - (gRotator.x * 0.9057375192642212f);
      float _871 = (gRotator.w * 0.30034708976745605f) - (gRotator.z * 0.9057375192642212f);
      float _881 = ((_610 * _870) + _225) + (_613 * _871);
      float _882 = ((_611 * _870) + _226) + (_614 * _871);
      float _883 = ((_612 * _870) + _158) + (_615 * _871);
      float _895 = mad((gViewToClip[2].w), _883, mad((gViewToClip[1].w), _882, ((gViewToClip[0].w) * _881))) + (gViewToClip[3].w);
      float _900 = (((mad((gViewToClip[2].x), _883, mad((gViewToClip[1].x), _882, ((gViewToClip[0].x) * _881))) + (gViewToClip[3].x)) / _895) * 0.5f) + 0.5f;
      float _901 = 0.5f - (((mad((gViewToClip[2].y), _883, mad((gViewToClip[1].y), _882, ((gViewToClip[0].y) * _881))) + (gViewToClip[3].y)) / _895) * 0.5f);
      if (!_721) {
        int _912 = int(gRectSize.x * _900);
        int _913 = int(gRectSize.y * _901);
        float _924 = (float((int)(_912)) + 0.5f) * gInvRectSize.x;
        _928 = _924;
        _929 = ((float((int)(((int)(uint)((bool)((((_913 ^ gFrameIndex) ^ _912) & 1) != gSpecCheckerboard))) + _913)) + 0.5f) * gInvRectSize.y);
        _930 = (_924 * 0.5f);
      } else {
        _928 = _900;
        _929 = _901;
        _930 = _900;
      }
      float _933 = (gResolutionScale.x * _928) + gRectOffset.x;
      float _934 = (gResolutionScale.y * _929) + gRectOffset.y;
      float4 _935 = gIn_Normal_Roughness.SampleLevel(MaterialSamplers[6u], float2(_933, _934), 0.0f);
      float4 _942 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(((gResolutionScale.x * _930) + gRectOffset.x), _934), 0.0f);
      float _947 = gIn_ViewZ.SampleLevel(MaterialSamplers[6u], float2(_933, _934), 0.0f);
      float _949 = abs(_947.x);
      float _955 = (_785 * _949) + gIsOrtho;
      float _961 = (_935.x * 2.0f) + -1.0f;
      float _962 = (_935.y * 2.0f) + -1.0f;
      float _963 = (_935.z * 2.0f) + -1.0f;
      float _965 = rsqrt(dot(float3(_961, _962, _963), float3(_961, _962, _963)));
      float _974 = saturate(1.0f - abs((dot(float3(_203, _206, _209), float3((_955 * ((gFrustum.z * _928) + gFrustum.x)), (_955 * ((gFrustum.w * _929) + gFrustum.y)), _949)) - _621) * _620));
      float _987 = saturate(1.0f - abs((_935.w - _188) * _667));
      float _999 = saturate(1.0f - abs((_827 * sqrt(saturate(1.0f - saturate(dot(float3(_170, _176, _182), float3((_965 * _961), (_965 * _962), (_965 * _963))))))) + -0.0010000000474974513f));
      float _1016 = saturate(1.0f - abs((_942.w - _413) * _664));
      float _1023 = ((((_1016 * _1016) * (3.0f - (_1016 * 2.0f))) * 0.6000000238418579f) + 0.4000000059604645f) * (((_999 * _999) * (((((((_974 * _974) * 0.5482766032218933f) * (3.0f - (_974 * 2.0f))) * _987) * float((bool)((bool)((bool)(saturate(_928) == _928) && (bool)(saturate(_929) == _929))))) * _987) * (3.0f - (_987 * 2.0f)))) * (3.0f - (_999 * 2.0f)));
      float _1037 = (gRotator.y * 0.4037880003452301f) - (gRotator.x * 0.34873878955841064f);
      float _1038 = (gRotator.w * 0.4037880003452301f) - (gRotator.z * 0.34873878955841064f);
      float _1048 = ((_610 * _1037) + _225) + (_613 * _1038);
      float _1049 = ((_611 * _1037) + _226) + (_614 * _1038);
      float _1050 = ((_612 * _1037) + _158) + (_615 * _1038);
      float _1062 = mad((gViewToClip[2].w), _1050, mad((gViewToClip[1].w), _1049, ((gViewToClip[0].w) * _1048))) + (gViewToClip[3].w);
      float _1067 = (((mad((gViewToClip[2].x), _1050, mad((gViewToClip[1].x), _1049, ((gViewToClip[0].x) * _1048))) + (gViewToClip[3].x)) / _1062) * 0.5f) + 0.5f;
      float _1068 = 0.5f - (((mad((gViewToClip[2].y), _1050, mad((gViewToClip[1].y), _1049, ((gViewToClip[0].y) * _1048))) + (gViewToClip[3].y)) / _1062) * 0.5f);
      if (!_721) {
        int _1079 = int(gRectSize.x * _1067);
        int _1080 = int(gRectSize.y * _1068);
        float _1091 = (float((int)(_1079)) + 0.5f) * gInvRectSize.x;
        _1095 = _1091;
        _1096 = ((float((int)(int((bool)(bool)((((_1080 ^ gFrameIndex) ^ _1079) & 1) != gSpecCheckerboard)) + _1080)) + 0.5f) * gInvRectSize.y);
        _1097 = (_1091 * 0.5f);
      } else {
        _1095 = _1067;
        _1096 = _1068;
        _1097 = _1067;
      }
      float _1100 = (gResolutionScale.x * _1095) + gRectOffset.x;
      float _1101 = (gResolutionScale.y * _1096) + gRectOffset.y;
      float4 _1102 = gIn_Normal_Roughness.SampleLevel(MaterialSamplers[6u], float2(_1100, _1101), 0.0f);
      float4 _1109 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(((gResolutionScale.x * _1097) + gRectOffset.x), _1101), 0.0f);
      float _1114 = gIn_ViewZ.SampleLevel(MaterialSamplers[6u], float2(_1100, _1101), 0.0f);
      float _1116 = abs(_1114.x);
      float _1122 = (_785 * _1116) + gIsOrtho;
      float _1128 = (_1102.x * 2.0f) + -1.0f;
      float _1129 = (_1102.y * 2.0f) + -1.0f;
      float _1130 = (_1102.z * 2.0f) + -1.0f;
      float _1132 = rsqrt(dot(float3(_1128, _1129, _1130), float3(_1128, _1129, _1130)));
      float _1141 = saturate(1.0f - abs((dot(float3(_203, _206, _209), float3((_1122 * ((gFrustum.z * _1095) + gFrustum.x)), (_1122 * ((gFrustum.w * _1096) + gFrustum.y)), _1116)) - _621) * _620));
      float _1154 = saturate(1.0f - abs((_1102.w - _188) * _667));
      float _1166 = saturate(1.0f - abs((_827 * sqrt(saturate(1.0f - saturate(dot(float3(_170, _176, _182), float3((_1132 * _1128), (_1132 * _1129), (_1132 * _1130))))))) + -0.0010000000474974513f));
      float _1183 = saturate(1.0f - abs((_1109.w - _413) * _664));
      float _1190 = ((((_1183 * _1183) * (3.0f - (_1183 * 2.0f))) * 0.6000000238418579f) + 0.4000000059604645f) * (((_1166 * _1166) * (((((((_1141 * _1141) * 0.8287159204483032f) * (3.0f - (_1141 * 2.0f))) * _1154) * float((bool)((bool)((bool)(saturate(_1095) == _1095) && (bool)(saturate(_1096) == _1096))))) * _1154) * (3.0f - (_1154 * 2.0f)))) * (3.0f - (_1166 * 2.0f)));
      float _1204 = (gRotator.x * 0.10230419784784317f) + (gRotator.y * 0.6439372897148132f);
      float _1205 = (gRotator.z * 0.10230419784784317f) + (gRotator.w * 0.6439372897148132f);
      float _1215 = ((_610 * _1204) + _225) + (_613 * _1205);
      float _1216 = ((_611 * _1204) + _226) + (_614 * _1205);
      float _1217 = ((_612 * _1204) + _158) + (_615 * _1205);
      float _1229 = mad((gViewToClip[2].w), _1217, mad((gViewToClip[1].w), _1216, ((gViewToClip[0].w) * _1215))) + (gViewToClip[3].w);
      float _1234 = (((mad((gViewToClip[2].x), _1217, mad((gViewToClip[1].x), _1216, ((gViewToClip[0].x) * _1215))) + (gViewToClip[3].x)) / _1229) * 0.5f) + 0.5f;
      float _1235 = 0.5f - (((mad((gViewToClip[2].y), _1217, mad((gViewToClip[1].y), _1216, ((gViewToClip[0].y) * _1215))) + (gViewToClip[3].y)) / _1229) * 0.5f);
      if (!_721) {
        int _1246 = int(gRectSize.x * _1234);
        int _1247 = int(gRectSize.y * _1235);
        float _1258 = (float((int)(_1246)) + 0.5f) * gInvRectSize.x;
        _1262 = _1258;
        _1263 = ((float((int)(((int)(uint)((bool)((((_1247 ^ gFrameIndex) ^ _1246) & 1) != gSpecCheckerboard))) + _1247)) + 0.5f) * gInvRectSize.y);
        _1264 = (_1258 * 0.5f);
      } else {
        _1262 = _1234;
        _1263 = _1235;
        _1264 = _1234;
      }
      float _1267 = (gResolutionScale.x * _1262) + gRectOffset.x;
      float _1268 = (gResolutionScale.y * _1263) + gRectOffset.y;
      float4 _1269 = gIn_Normal_Roughness.SampleLevel(MaterialSamplers[6u], float2(_1267, _1268), 0.0f);
      float4 _1276 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(((gResolutionScale.x * _1264) + gRectOffset.x), _1268), 0.0f);
      float _1281 = gIn_ViewZ.SampleLevel(MaterialSamplers[6u], float2(_1267, _1268), 0.0f);
      float _1283 = abs(_1281.x);
      float _1289 = (_785 * _1283) + gIsOrtho;
      float _1295 = (_1269.x * 2.0f) + -1.0f;
      float _1296 = (_1269.y * 2.0f) + -1.0f;
      float _1297 = (_1269.z * 2.0f) + -1.0f;
      float _1299 = rsqrt(dot(float3(_1295, _1296, _1297), float3(_1295, _1296, _1297)));
      float _1308 = saturate(1.0f - abs((dot(float3(_203, _206, _209), float3((_1289 * ((gFrustum.z * _1262) + gFrustum.x)), (_1289 * ((gFrustum.w * _1263) + gFrustum.y)), _1283)) - _621) * _620));
      float _1321 = saturate(1.0f - abs((_1269.w - _188) * _667));
      float _1333 = saturate(1.0f - abs((_827 * sqrt(saturate(1.0f - saturate(dot(float3(_170, _176, _182), float3((_1299 * _1295), (_1299 * _1296), (_1299 * _1297))))))) + -0.0010000000474974513f));
      float _1350 = saturate(1.0f - abs((_1276.w - _413) * _664));
      float _1357 = ((((_1350 * _1350) * (3.0f - (_1350 * 2.0f))) * 0.6000000238418579f) + 0.4000000059604645f) * (((_1333 * _1333) * (((((((_1308 * _1308) * 0.755345344543457f) * (3.0f - (_1308 * 2.0f))) * _1321) * float((bool)((bool)((bool)(saturate(_1262) == _1262) && (bool)(saturate(_1263) == _1263))))) * _1321) * (3.0f - (_1321 * 2.0f)))) * (3.0f - (_1333 * 2.0f)));
      float _1371 = (gRotator.x * 0.5699276924133301f) + (gRotator.y * 0.351375013589859f);
      float _1372 = (gRotator.z * 0.5699276924133301f) + (gRotator.w * 0.351375013589859f);
      float _1382 = ((_610 * _1371) + _225) + (_613 * _1372);
      float _1383 = ((_611 * _1371) + _226) + (_614 * _1372);
      float _1384 = ((_612 * _1371) + _158) + (_615 * _1372);
      float _1396 = mad((gViewToClip[2].w), _1384, mad((gViewToClip[1].w), _1383, ((gViewToClip[0].w) * _1382))) + (gViewToClip[3].w);
      float _1401 = (((mad((gViewToClip[2].x), _1384, mad((gViewToClip[1].x), _1383, ((gViewToClip[0].x) * _1382))) + (gViewToClip[3].x)) / _1396) * 0.5f) + 0.5f;
      float _1402 = 0.5f - (((mad((gViewToClip[2].y), _1384, mad((gViewToClip[1].y), _1383, ((gViewToClip[0].y) * _1382))) + (gViewToClip[3].y)) / _1396) * 0.5f);
      if (!_721) {
        int _1413 = int(gRectSize.x * _1401);
        int _1414 = int(gRectSize.y * _1402);
        float _1425 = (float((int)(_1413)) + 0.5f) * gInvRectSize.x;
        _1429 = _1425;
        _1430 = ((float((int)(int((bool)(bool)((((_1414 ^ gFrameIndex) ^ _1413) & 1) != gSpecCheckerboard)) + _1414)) + 0.5f) * gInvRectSize.y);
        _1431 = (_1425 * 0.5f);
      } else {
        _1429 = _1401;
        _1430 = _1402;
        _1431 = _1401;
      }
      float _1434 = (gResolutionScale.x * _1429) + gRectOffset.x;
      float _1435 = (gResolutionScale.y * _1430) + gRectOffset.y;
      float4 _1436 = gIn_Normal_Roughness.SampleLevel(MaterialSamplers[6u], float2(_1434, _1435), 0.0f);
      float4 _1443 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(((gResolutionScale.x * _1431) + gRectOffset.x), _1435), 0.0f);
      float _1448 = gIn_ViewZ.SampleLevel(MaterialSamplers[6u], float2(_1434, _1435), 0.0f);
      float _1450 = abs(_1448.x);
      float _1456 = (_785 * _1450) + gIsOrtho;
      float _1462 = (_1436.x * 2.0f) + -1.0f;
      float _1463 = (_1436.y * 2.0f) + -1.0f;
      float _1464 = (_1436.z * 2.0f) + -1.0f;
      float _1466 = rsqrt(dot(float3(_1462, _1463, _1464), float3(_1462, _1463, _1464)));
      float _1475 = saturate(1.0f - abs((dot(float3(_203, _206, _209), float3((_1456 * ((gFrustum.z * _1429) + gFrustum.x)), (_1456 * ((gFrustum.w * _1430) + gFrustum.y)), _1450)) - _621) * _620));
      float _1488 = saturate(1.0f - abs((_1436.w - _188) * _667));
      float _1500 = saturate(1.0f - abs((_827 * sqrt(saturate(1.0f - saturate(dot(float3(_170, _176, _182), float3((_1466 * _1462), (_1466 * _1463), (_1466 * _1464))))))) + -0.0010000000474974513f));
      float _1517 = saturate(1.0f - abs((_1443.w - _413) * _664));
      float _1524 = ((((_1517 * _1517) * (3.0f - (_1517 * 2.0f))) * 0.6000000238418579f) + 0.4000000059604645f) * (((_1500 * _1500) * (((((((_1475 * _1475) * 0.7438870072364807f) * (3.0f - (_1475 * 2.0f))) * _1488) * float((bool)((bool)((bool)(saturate(_1429) == _1429) && (bool)(saturate(_1430) == _1430))))) * _1488) * (3.0f - (_1488 * 2.0f)))) * (3.0f - (_1500 * 2.0f)));
      float _1538 = (gRotator.x * 0.293912798166275f) - (gRotator.y * 0.1131225973367691f);
      float _1539 = (gRotator.z * 0.293912798166275f) - (gRotator.w * 0.1131225973367691f);
      float _1549 = ((_610 * _1538) + _225) + (_613 * _1539);
      float _1550 = ((_611 * _1538) + _226) + (_614 * _1539);
      float _1551 = ((_612 * _1538) + _158) + (_615 * _1539);
      float _1563 = mad((gViewToClip[2].w), _1551, mad((gViewToClip[1].w), _1550, ((gViewToClip[0].w) * _1549))) + (gViewToClip[3].w);
      float _1568 = (((mad((gViewToClip[2].x), _1551, mad((gViewToClip[1].x), _1550, ((gViewToClip[0].x) * _1549))) + (gViewToClip[3].x)) / _1563) * 0.5f) + 0.5f;
      float _1569 = 0.5f - (((mad((gViewToClip[2].y), _1551, mad((gViewToClip[1].y), _1550, ((gViewToClip[0].y) * _1549))) + (gViewToClip[3].y)) / _1563) * 0.5f);
      if (!_721) {
        int _1580 = int(gRectSize.x * _1568);
        int _1581 = int(gRectSize.y * _1569);
        float _1592 = (float((int)(_1580)) + 0.5f) * gInvRectSize.x;
        _1596 = _1592;
        _1597 = ((float((int)(((int)(uint)((bool)((((_1581 ^ gFrameIndex) ^ _1580) & 1) != gSpecCheckerboard))) + _1581)) + 0.5f) * gInvRectSize.y);
        _1598 = (_1592 * 0.5f);
      } else {
        _1596 = _1568;
        _1597 = _1569;
        _1598 = _1568;
      }
      float _1601 = (gResolutionScale.x * _1596) + gRectOffset.x;
      float _1602 = (gResolutionScale.y * _1597) + gRectOffset.y;
      float4 _1603 = gIn_Normal_Roughness.SampleLevel(MaterialSamplers[6u], float2(_1601, _1602), 0.0f);
      float4 _1610 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(((gResolutionScale.x * _1598) + gRectOffset.x), _1602), 0.0f);
      float _1615 = gIn_ViewZ.SampleLevel(MaterialSamplers[6u], float2(_1601, _1602), 0.0f);
      float _1617 = abs(_1615.x);
      float _1623 = (_785 * _1617) + gIsOrtho;
      float _1629 = (_1603.x * 2.0f) + -1.0f;
      float _1630 = (_1603.y * 2.0f) + -1.0f;
      float _1631 = (_1603.z * 2.0f) + -1.0f;
      float _1633 = rsqrt(dot(float3(_1629, _1630, _1631), float3(_1629, _1630, _1631)));
      float _1642 = saturate(1.0f - abs((dot(float3(_203, _206, _209), float3((_1623 * ((gFrustum.z * _1596) + gFrustum.x)), (_1623 * ((gFrustum.w * _1597) + gFrustum.y)), _1617)) - _621) * _620));
      float _1655 = saturate(1.0f - abs((_1603.w - _188) * _667));
      float _1667 = saturate(1.0f - abs((_827 * sqrt(saturate(1.0f - saturate(dot(float3(_170, _176, _182), float3((_1633 * _1629), (_1633 * _1630), (_1633 * _1631))))))) + -0.0010000000474974513f));
      float _1684 = saturate(1.0f - abs((_1610.w - _413) * _664));
      float _1691 = ((((_1684 * _1684) * (3.0f - (_1684 * 2.0f))) * 0.6000000238418579f) + 0.4000000059604645f) * (((_1667 * _1667) * (((((((_1642 * _1642) * 0.936636745929718f) * (3.0f - (_1642 * 2.0f))) * _1655) * float((bool)((bool)((bool)(saturate(_1596) == _1596) && (bool)(saturate(_1597) == _1597))))) * _1655) * (3.0f - (_1655 * 2.0f)))) * (3.0f - (_1667 * 2.0f)));
      float _1705 = (gRotator.x * 0.7836657762527466f) - (gRotator.y * 0.42087841033935547f);
      float _1706 = (gRotator.z * 0.7836657762527466f) - (gRotator.w * 0.42087841033935547f);
      float _1716 = ((_610 * _1705) + _225) + (_613 * _1706);
      float _1717 = ((_611 * _1705) + _226) + (_614 * _1706);
      float _1718 = ((_612 * _1705) + _158) + (_615 * _1706);
      float _1730 = mad((gViewToClip[2].w), _1718, mad((gViewToClip[1].w), _1717, ((gViewToClip[0].w) * _1716))) + (gViewToClip[3].w);
      float _1735 = (((mad((gViewToClip[2].x), _1718, mad((gViewToClip[1].x), _1717, ((gViewToClip[0].x) * _1716))) + (gViewToClip[3].x)) / _1730) * 0.5f) + 0.5f;
      float _1736 = 0.5f - (((mad((gViewToClip[2].y), _1718, mad((gViewToClip[1].y), _1717, ((gViewToClip[0].y) * _1716))) + (gViewToClip[3].y)) / _1730) * 0.5f);
      if (!_721) {
        int _1747 = int(gRectSize.x * _1735);
        int _1748 = int(gRectSize.y * _1736);
        float _1759 = (float((int)(_1747)) + 0.5f) * gInvRectSize.x;
        _1763 = _1759;
        _1764 = ((float((int)(int((bool)(bool)((((_1748 ^ gFrameIndex) ^ _1747) & 1) != gSpecCheckerboard)) + _1748)) + 0.5f) * gInvRectSize.y);
        _1765 = (_1759 * 0.5f);
      } else {
        _1763 = _1735;
        _1764 = _1736;
        _1765 = _1735;
      }
      float _1768 = (gResolutionScale.x * _1763) + gRectOffset.x;
      float _1769 = (gResolutionScale.y * _1764) + gRectOffset.y;
      float4 _1770 = gIn_Normal_Roughness.SampleLevel(MaterialSamplers[6u], float2(_1768, _1769), 0.0f);
      float4 _1777 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(((gResolutionScale.x * _1765) + gRectOffset.x), _1769), 0.0f);
      float _1782 = gIn_ViewZ.SampleLevel(MaterialSamplers[6u], float2(_1768, _1769), 0.0f);
      float _1784 = abs(_1782.x);
      float _1790 = (_785 * _1784) + gIsOrtho;
      float _1796 = (_1770.x * 2.0f) + -1.0f;
      float _1797 = (_1770.y * 2.0f) + -1.0f;
      float _1798 = (_1770.z * 2.0f) + -1.0f;
      float _1800 = rsqrt(dot(float3(_1796, _1797, _1798), float3(_1796, _1797, _1798)));
      float _1809 = saturate(1.0f - abs((dot(float3(_203, _206, _209), float3((_1790 * ((gFrustum.z * _1763) + gFrustum.x)), (_1790 * ((gFrustum.w * _1764) + gFrustum.y)), _1784)) - _621) * _620));
      float _1822 = saturate(1.0f - abs((_1770.w - _188) * _667));
      float _1834 = saturate(1.0f - abs((_827 * sqrt(saturate(1.0f - saturate(dot(float3(_170, _176, _182), float3((_1800 * _1796), (_1800 * _1797), (_1800 * _1798))))))) + -0.0010000000474974513f));
      float _1851 = saturate(1.0f - abs((_1777.w - _413) * _664));
      float _1858 = ((((_1851 * _1851) * (3.0f - (_1851 * 2.0f))) * 0.6000000238418579f) + 0.4000000059604645f) * (((_1834 * _1834) * (((((((_1809 * _1809) * 0.5931911468505859f) * (3.0f - (_1809 * 2.0f))) * _1822) * float((bool)((bool)((bool)(saturate(_1763) == _1763) && (bool)(saturate(_1764) == _1764))))) * _1822) * (3.0f - (_1822 * 2.0f)))) * (3.0f - (_1834 * 2.0f)));
      float _1872 = (gRotator.x * 0.1564120054244995f) - (gRotator.y * 0.8198990225791931f);
      float _1873 = (gRotator.z * 0.1564120054244995f) - (gRotator.w * 0.8198990225791931f);
      float _1883 = ((_610 * _1872) + _225) + (_613 * _1873);
      float _1884 = ((_611 * _1872) + _226) + (_614 * _1873);
      float _1885 = ((_612 * _1872) + _158) + (_615 * _1873);
      float _1897 = mad((gViewToClip[2].w), _1885, mad((gViewToClip[1].w), _1884, ((gViewToClip[0].w) * _1883))) + (gViewToClip[3].w);
      float _1902 = (((mad((gViewToClip[2].x), _1885, mad((gViewToClip[1].x), _1884, ((gViewToClip[0].x) * _1883))) + (gViewToClip[3].x)) / _1897) * 0.5f) + 0.5f;
      float _1903 = 0.5f - (((mad((gViewToClip[2].y), _1885, mad((gViewToClip[1].y), _1884, ((gViewToClip[0].y) * _1883))) + (gViewToClip[3].y)) / _1897) * 0.5f);
      if (!_721) {
        int _1914 = int(gRectSize.x * _1902);
        int _1915 = int(gRectSize.y * _1903);
        float _1926 = (float((int)(_1914)) + 0.5f) * gInvRectSize.x;
        _1930 = _1926;
        _1931 = ((float((int)(((int)(uint)((bool)((((_1915 ^ gFrameIndex) ^ _1914) & 1) != gSpecCheckerboard))) + _1915)) + 0.5f) * gInvRectSize.y);
        _1932 = (_1926 * 0.5f);
      } else {
        _1930 = _1902;
        _1931 = _1903;
        _1932 = _1902;
      }
      float _1935 = (gResolutionScale.x * _1930) + gRectOffset.x;
      float _1936 = (gResolutionScale.y * _1931) + gRectOffset.y;
      float4 _1937 = gIn_Normal_Roughness.SampleLevel(MaterialSamplers[6u], float2(_1935, _1936), 0.0f);
      float4 _1944 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(((gResolutionScale.x * _1932) + gRectOffset.x), _1936), 0.0f);
      float _1949 = gIn_ViewZ.SampleLevel(MaterialSamplers[6u], float2(_1935, _1936), 0.0f);
      float _1951 = abs(_1949.x);
      float _1957 = (_785 * _1951) + gIsOrtho;
      float _1963 = (_1937.x * 2.0f) + -1.0f;
      float _1964 = (_1937.y * 2.0f) + -1.0f;
      float _1965 = (_1937.z * 2.0f) + -1.0f;
      float _1967 = rsqrt(dot(float3(_1963, _1964, _1965), float3(_1963, _1964, _1965)));
      float _1976 = saturate(1.0f - abs((dot(float3(_203, _206, _209), float3((_1957 * ((gFrustum.z * _1930) + gFrustum.x)), (_1957 * ((gFrustum.w * _1931) + gFrustum.y)), _1951)) - _621) * _620));
      float _1989 = saturate(1.0f - abs((_1937.w - _188) * _667));
      float _2001 = saturate(1.0f - abs((_827 * sqrt(saturate(1.0f - saturate(dot(float3(_170, _176, _182), float3((_1967 * _1963), (_1967 * _1964), (_1967 * _1965))))))) + -0.0010000000474974513f));
      float _2018 = saturate(1.0f - abs((_1944.w - _413) * _664));
      float _2025 = ((((_2018 * _2018) * (3.0f - (_2018 * 2.0f))) * 0.6000000238418579f) + 0.4000000059604645f) * (((_2001 * _2001) * (((((((_1976 * _1976) * 0.6313964128494263f) * (3.0f - (_1976 * 2.0f))) * _1989) * float((bool)((bool)((bool)(saturate(_1930) == _1930) && (bool)(saturate(_1931) == _1931))))) * _1989) * (3.0f - (_1989 * 2.0f)))) * (3.0f - (_2001 * 2.0f)));
      float _2034 = (((((((_856 + 1.0f) + _1023) + _1190) + _1357) + _1524) + _1691) + _1858) + _2025;
      gOut_Spec[int2((uint)(SV_DispatchThreadID.x), (uint)(SV_DispatchThreadID.y))] = (RENODX_NRD_PASSTHROUGH > 0.5f ? pt : float4(((((((((((_856 * _768.x) + _410) + (_1023 * _942.x)) + (_1190 * _1109.x)) + (_1357 * _1276.x)) + (_1524 * _1443.x)) + (_1691 * _1610.x)) + (_1858 * _1777.x)) + (_2025 * _1944.x)) / _2034), ((((((((((_856 * _768.y) + _411) + (_1023 * _942.y)) + (_1190 * _1109.y)) + (_1357 * _1276.y)) + (_1524 * _1443.y)) + (_1691 * _1610.y)) + (_1858 * _1777.y)) + (_2025 * _1944.y)) / _2034), ((((((((((_856 * _768.z) + _412) + (_1023 * _942.z)) + (_1190 * _1109.z)) + (_1357 * _1276.z)) + (_1524 * _1443.z)) + (_1691 * _1610.z)) + (_1858 * _1777.z)) + (_2025 * _1944.z)) / _2034), ((((((((((_856 * _768.w) + _413) + (_1023 * _942.w)) + (_1190 * _1109.w)) + (_1357 * _1276.w)) + (_1524 * _1443.w)) + (_1691 * _1610.w)) + (_1858 * _1777.w)) + (_2025 * _1944.w)) / _2034)));
    }
  }
}
