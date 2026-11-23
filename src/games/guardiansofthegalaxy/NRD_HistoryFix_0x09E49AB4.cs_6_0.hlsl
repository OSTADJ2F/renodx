#include "./shared.h"
Texture2D<float4> gIn_Normal_Roughness : register(t0);

Texture2D<float3> gIn_InternalData : register(t1);

Texture2D<float> gIn_ScaledViewZ : register(t2);

Texture2D<float4> gIn_Spec : register(t3);

Texture2D<float4> gIn_Fast_Spec : register(t4);

RWTexture2D<float4> gOut_Spec : register(u0);

cbuffer _REBLUR_Specular_HistoryFix : register(b0) {
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
  float gSpecMaxFastAccumulatedFrameNum : packoffset(c013.x);
  float gSpecFastHistoryClampingColorBoxSigmaScale : packoffset(c013.y);
  uint gSpecAntiFirefly : packoffset(c013.z);
  float fPadding0 : packoffset(c013.w);
};
#include "./nrd_common.hlsli"

SamplerState MaterialSamplers[1920] : register(s0);

groupshared float _global_0[1600];

[numthreads(16, 16, 1)]
void main(
  uint3 SV_DispatchThreadID : SV_DispatchThreadID,
  uint3 SV_GroupID : SV_GroupID,
  uint3 SV_GroupThreadID : SV_GroupThreadID,
  uint SV_GroupIndex : SV_GroupIndex
) {
  float _30 = (float((uint)SV_GroupIndex) + 0.5f) * 0.05000000074505806f;
  int _33 = int(frac(_30) * 20.0f);
  int _34 = int(_30);
  uint _37 = (SV_DispatchThreadID.x - SV_GroupThreadID.x) + -2u;
  uint _38 = (SV_DispatchThreadID.y - SV_GroupThreadID.y) + -2u;
  float _135;
  float _136;
  float _137;
  float _138;
  float _139;
  float _140;
  float _692;
  float _693;
  float _694;
  float _695;
  float _696;
  float _1870;
  float _1871;
  float _1872;
  float _1873;
  float _1899;
  float _1900;
  float _1901;
  float _1902;
  if ((int)_34 < (int)12) {
    float4 _43 = gIn_Fast_Spec.Load(int3(((uint)(_33 + _37)), ((uint)(_34 + _38)), 0));
    _global_0[((uint)(0u + (((uint)(_33 + (_34 * 20))) * 4)))] = _43.x;
    _global_0[((uint)(1u + (((uint)(_33 + (_34 * 20))) * 4)))] = _43.y;
    _global_0[((uint)(2u + (((uint)(_33 + (_34 * 20))) * 4)))] = _43.z;
    _global_0[((uint)(3u + (((uint)(_33 + (_34 * 20))) * 4)))] = _43.w;
  }
  int _69 = _34 + 12;
  if ((int)_69 < (int)20) {
    float4 _74 = gIn_Fast_Spec.Load(int3(((uint)(_33 + _37)), ((uint)(_69 + _38)), 0));
    _global_0[((uint)(0u + (((uint)(_33 + (_69 * 20))) * 4)))] = _74.x;
    _global_0[((uint)(1u + (((uint)(_33 + (_69 * 20))) * 4)))] = _74.y;
    _global_0[((uint)(2u + (((uint)(_33 + (_69 * 20))) * 4)))] = _74.z;
    _global_0[((uint)(3u + (((uint)(_33 + (_69 * 20))) * 4)))] = _74.w;
  }
  GroupMemoryBarrierWithGroupSync();
  float _100 = gIn_ScaledViewZ.Load(int3((uint)(SV_DispatchThreadID.x), (uint)(SV_DispatchThreadID.y), 0));
  [branch]
  if (!((_100.x * 80.0f) > gInf)) {
    float4 _107 = gIn_Normal_Roughness.Load(int3(((uint)((int)(gRectOrigin.x) + SV_DispatchThreadID.x)), ((uint)((int)(gRectOrigin.y) + SV_DispatchThreadID.y)), 0));
    float3 _109 = gIn_InternalData.Load(int3((uint)(SV_DispatchThreadID.x), (uint)(SV_DispatchThreadID.y), 0));
    float _111 = _109.x * 63.0f;
    float _113 = 1.0f / (_111 + 1.0f);
    float4 _114 = gIn_Spec.Load(int3((uint)(SV_DispatchThreadID.x), (uint)(SV_DispatchThreadID.y), 0));
    if (RENODX_NRD_PASSTHROUGH > 0.5f) { gOut_Spec[int2((uint)(SV_DispatchThreadID.x), (uint)(SV_DispatchThreadID.y))] = _114; return; }
    float _131 = floor(((1.0f - exp2((_107.w * _107.w) * -200.0f)) * max((4.999000072479248f - _111), 0.0f)) * exp2(log2(saturate(_107.w)) * 0.25f));
    if (_131 > 0.0f) {
      _135 = 0.0f;
      _136 = 0.0f;
      _137 = 0.0f;
      _138 = 0.0f;
      _139 = 0.0f;
      _140 = _131;
      while(true) {
        float _145 = exp2(-0.0f - _140);
        float _146 = gScreenSize.x * _145;
        float _147 = gScreenSize.y * _145;
        float _148 = 1.0f / _146;
        float _149 = 1.0f / _147;
        float _156 = (((gInvRectSize.x * (float((int)((uint)(SV_DispatchThreadID.x))) + 0.5f)) - (_148 * 0.5f)) * _146) + -0.5f;
        float _157 = (((gInvRectSize.y * (float((int)((uint)(SV_DispatchThreadID.y))) + 0.5f)) - (_149 * 0.5f)) * _147) + -0.5f;
        float _158 = floor(_156);
        float _159 = floor(_157);
        float _160 = _156 - _158;
        float _161 = _157 - _159;
        float _162 = 1.0f - _160;
        float _163 = 1.0f - _161;
        float _164 = _163 * _162;
        float _165 = _163 * _160;
        float _166 = _162 * _161;
        float _167 = _161 * _160;
        float _170 = (_158 + 0.5f) * _148;
        float _171 = (_159 + 0.5f) * _149;
        float _175 = gResolutionScale.x * _170;
        float _176 = _171 * gResolutionScale.y;
        float _177 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_175, _176), _140);
        float _179 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_175, _176), _140, int2(1, 0));
        float _181 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_175, _176), _140, int2(0, 1));
        float _183 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_175, _176), _140, int2(1, 1));
        float _193 = abs(_100.x);
        float _210 = (1.0f / (min(abs(_177.x), _193) + 0.0010000000474974513f)) * abs(_177.x - _100.x);
        float _211 = (1.0f / (min(abs(_179.x), _193) + 0.0010000000474974513f)) * abs(_179.x - _100.x);
        float _212 = (1.0f / (min(abs(_181.x), _193) + 0.0010000000474974513f)) * abs(_181.x - _100.x);
        float _213 = (1.0f / (min(abs(_183.x), _193) + 0.0010000000474974513f)) * abs(_183.x - _100.x);
        bool _236 = (saturate(_170) == _170);
        bool _237 = (saturate(_171) == _171);
        float _239 = float((bool)((bool)(_236 && _237)));
        float _242 = ((select((_210 > 0.05000000074505806f), 0.0f, 1.0f) * _164) * (1.0f / ((_210 * 100.0f) + 1.0f))) * _239;
        float _245 = ((select((_211 > 0.05000000074505806f), 0.0f, 1.0f) * _165) * (1.0f / ((_211 * 100.0f) + 1.0f))) * _239;
        float _248 = ((select((_212 > 0.05000000074505806f), 0.0f, 1.0f) * _166) * (1.0f / ((_212 * 100.0f) + 1.0f))) * _239;
        float _251 = ((select((_213 > 0.05000000074505806f), 0.0f, 1.0f) * _167) * (1.0f / ((_213 * 100.0f) + 1.0f))) * _239;
        float4 _252 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_175, _176), _140);
        float4 _257 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_175, _176), _140, int2(1, 0));
        float4 _262 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_175, _176), _140, int2(0, 1));
        float4 _267 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_175, _176), _140, int2(1, 1));
        float _290 = _171 + _149;
        float _291 = gResolutionScale.y * _290;
        float _292 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_175, _291), _140);
        float _294 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_175, _291), _140, int2(1, 0));
        float _296 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_175, _291), _140, int2(0, 1));
        float _298 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_175, _291), _140, int2(1, 1));
        float _324 = (1.0f / (min(abs(_292.x), _193) + 0.0010000000474974513f)) * abs(_292.x - _100.x);
        float _325 = (1.0f / (min(abs(_294.x), _193) + 0.0010000000474974513f)) * abs(_294.x - _100.x);
        float _326 = (1.0f / (min(abs(_296.x), _193) + 0.0010000000474974513f)) * abs(_296.x - _100.x);
        float _327 = (1.0f / (min(abs(_298.x), _193) + 0.0010000000474974513f)) * abs(_298.x - _100.x);
        bool _349 = (saturate(_290) == _290);
        float _351 = float((bool)((bool)(_236 && _349)));
        float _354 = ((select((_324 > 0.05000000074505806f), 0.0f, 1.0f) * _164) * (1.0f / ((_324 * 100.0f) + 1.0f))) * _351;
        float _357 = ((select((_325 > 0.05000000074505806f), 0.0f, 1.0f) * _165) * (1.0f / ((_325 * 100.0f) + 1.0f))) * _351;
        float _360 = ((select((_326 > 0.05000000074505806f), 0.0f, 1.0f) * _166) * (1.0f / ((_326 * 100.0f) + 1.0f))) * _351;
        float _363 = ((select((_327 > 0.05000000074505806f), 0.0f, 1.0f) * _167) * (1.0f / ((_327 * 100.0f) + 1.0f))) * _351;
        float4 _364 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_175, _291), _140);
        float4 _369 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_175, _291), _140, int2(1, 0));
        float4 _374 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_175, _291), _140, int2(0, 1));
        float4 _379 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_175, _291), _140, int2(1, 1));
        float _402 = _170 + _148;
        float _403 = gResolutionScale.x * _402;
        float _404 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_403, _176), _140);
        float _406 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_403, _176), _140, int2(1, 0));
        float _408 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_403, _176), _140, int2(0, 1));
        float _410 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_403, _176), _140, int2(1, 1));
        float _436 = (1.0f / (min(abs(_404.x), _193) + 0.0010000000474974513f)) * abs(_404.x - _100.x);
        float _437 = (1.0f / (min(abs(_406.x), _193) + 0.0010000000474974513f)) * abs(_406.x - _100.x);
        float _438 = (1.0f / (min(abs(_408.x), _193) + 0.0010000000474974513f)) * abs(_408.x - _100.x);
        float _439 = (1.0f / (min(abs(_410.x), _193) + 0.0010000000474974513f)) * abs(_410.x - _100.x);
        bool _461 = (saturate(_402) == _402);
        float _463 = float((bool)((bool)(_461 && _237)));
        float _466 = ((select((_436 > 0.05000000074505806f), 0.0f, 1.0f) * _164) * (1.0f / ((_436 * 100.0f) + 1.0f))) * _463;
        float _469 = ((select((_437 > 0.05000000074505806f), 0.0f, 1.0f) * _165) * (1.0f / ((_437 * 100.0f) + 1.0f))) * _463;
        float _472 = ((select((_438 > 0.05000000074505806f), 0.0f, 1.0f) * _166) * (1.0f / ((_438 * 100.0f) + 1.0f))) * _463;
        float _475 = ((select((_439 > 0.05000000074505806f), 0.0f, 1.0f) * _167) * (1.0f / ((_439 * 100.0f) + 1.0f))) * _463;
        float4 _476 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_403, _176), _140);
        float4 _481 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_403, _176), _140, int2(1, 0));
        float4 _486 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_403, _176), _140, int2(0, 1));
        float4 _491 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_403, _176), _140, int2(1, 1));
        float _514 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_403, _291), _140);
        float _516 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_403, _291), _140, int2(1, 0));
        float _518 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_403, _291), _140, int2(0, 1));
        float _520 = gIn_ScaledViewZ.SampleLevel(MaterialSamplers[6u], float2(_403, _291), _140, int2(1, 1));
        float _546 = (1.0f / (min(abs(_514.x), _193) + 0.0010000000474974513f)) * abs(_514.x - _100.x);
        float _547 = (1.0f / (min(abs(_516.x), _193) + 0.0010000000474974513f)) * abs(_516.x - _100.x);
        float _548 = (1.0f / (min(abs(_518.x), _193) + 0.0010000000474974513f)) * abs(_518.x - _100.x);
        float _549 = (1.0f / (min(abs(_520.x), _193) + 0.0010000000474974513f)) * abs(_520.x - _100.x);
        float _571 = float((bool)((bool)(_461 && _349)));
        float _574 = ((select((_546 > 0.05000000074505806f), 0.0f, 1.0f) * _164) * (1.0f / ((_546 * 100.0f) + 1.0f))) * _571;
        float _577 = ((select((_547 > 0.05000000074505806f), 0.0f, 1.0f) * _165) * (1.0f / ((_547 * 100.0f) + 1.0f))) * _571;
        float _580 = ((select((_548 > 0.05000000074505806f), 0.0f, 1.0f) * _166) * (1.0f / ((_548 * 100.0f) + 1.0f))) * _571;
        float _583 = ((select((_549 > 0.05000000074505806f), 0.0f, 1.0f) * _167) * (1.0f / ((_549 * 100.0f) + 1.0f))) * _571;
        float4 _584 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_403, _291), _140);
        float4 _589 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_403, _291), _140, int2(1, 0));
        float4 _594 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_403, _291), _140, int2(0, 1));
        float4 _599 = gIn_Spec.SampleLevel(MaterialSamplers[6u], float2(_403, _291), _140, int2(1, 1));
        float _635 = ((((((((((((((((_252.x * _242) + _135) + (_257.x * _245)) + (_262.x * _248)) + (_267.x * _251)) + (_364.x * _354)) + (_369.x * _357)) + (_374.x * _360)) + (_379.x * _363)) + (_476.x * _466)) + (_481.x * _469)) + (_486.x * _472)) + (_491.x * _475)) + (_584.x * _574)) + (_589.x * _577)) + (_594.x * _580)) + (_599.x * _583);
        float _651 = ((((((((((((((((_252.y * _242) + _136) + (_257.y * _245)) + (_262.y * _248)) + (_267.y * _251)) + (_364.y * _354)) + (_369.y * _357)) + (_374.y * _360)) + (_379.y * _363)) + (_476.y * _466)) + (_481.y * _469)) + (_486.y * _472)) + (_491.y * _475)) + (_584.y * _574)) + (_589.y * _577)) + (_594.y * _580)) + (_599.y * _583);
        float _667 = ((((((((((((((((_252.z * _242) + _137) + (_257.z * _245)) + (_262.z * _248)) + (_267.z * _251)) + (_364.z * _354)) + (_369.z * _357)) + (_374.z * _360)) + (_379.z * _363)) + (_476.z * _466)) + (_481.z * _469)) + (_486.z * _472)) + (_491.z * _475)) + (_584.z * _574)) + (_589.z * _577)) + (_594.z * _580)) + (_599.z * _583);
        float _683 = ((((((((((((((((_252.w * _242) + _138) + (_257.w * _245)) + (_262.w * _248)) + (_267.w * _251)) + (_364.w * _354)) + (_369.w * _357)) + (_374.w * _360)) + (_379.w * _363)) + (_476.w * _466)) + (_481.w * _469)) + (_486.w * _472)) + (_491.w * _475)) + (_584.w * _574)) + (_589.w * _577)) + (_594.w * _580)) + (_599.w * _583);
        float _685 = (((dot(float4(_242, _245, _248, _251), float4(1.0f, 1.0f, 1.0f, 1.0f)) + _139) + dot(float4(_354, _357, _360, _363), float4(1.0f, 1.0f, 1.0f, 1.0f))) + dot(float4(_466, _469, _472, _475), float4(1.0f, 1.0f, 1.0f, 1.0f))) + dot(float4(_574, _577, _580, _583), float4(1.0f, 1.0f, 1.0f, 1.0f));
        float _686 = _140 + -1.0f;
        if ((bool)(_686 > 0.0f) && (bool)(_685 == 0.0f)) {
          _135 = _635;
          _136 = _651;
          _137 = _667;
          _138 = _683;
          _139 = _685;
          _140 = _686;
          continue;
        }
        _692 = _635;
        _693 = _651;
        _694 = _667;
        _695 = _683;
        _696 = _685;
        break;
      }
    } else {
      _692 = 0.0f;
      _693 = 0.0f;
      _694 = 0.0f;
      _695 = 0.0f;
      _696 = 0.0f;
    }
    bool _697 = (_696 == 0.0f);
    float _702 = select(_697, _114.x, (_692 / _696));
    float _703 = select(_697, _114.y, (_693 / _696));
    float _704 = select(_697, _114.z, (_694 / _696));
    float _705 = select(_697, _114.w, (_695 / _696));
    float _711 = _global_0[((uint)(0u + (((uint)(SV_GroupThreadID.x + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _717 = _global_0[((uint)(1u + (((uint)(SV_GroupThreadID.x + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _723 = _global_0[((uint)(2u + (((uint)(SV_GroupThreadID.x + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _729 = _global_0[((uint)(3u + (((uint)(SV_GroupThreadID.x + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    uint _742 = SV_GroupThreadID.x + 1u;
    float _748 = _global_0[((uint)(0u + (((uint)(_742 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _754 = _global_0[((uint)(1u + (((uint)(_742 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _760 = _global_0[((uint)(2u + (((uint)(_742 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _766 = _global_0[((uint)(3u + (((uint)(_742 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    uint _787 = SV_GroupThreadID.x + 2u;
    float _793 = _global_0[((uint)(0u + (((uint)(_787 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _799 = _global_0[((uint)(1u + (((uint)(_787 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _805 = _global_0[((uint)(2u + (((uint)(_787 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _811 = _global_0[((uint)(3u + (((uint)(_787 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    uint _832 = SV_GroupThreadID.x + 3u;
    float _838 = _global_0[((uint)(0u + (((uint)(_832 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _844 = _global_0[((uint)(1u + (((uint)(_832 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _850 = _global_0[((uint)(2u + (((uint)(_832 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _856 = _global_0[((uint)(3u + (((uint)(_832 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    uint _877 = SV_GroupThreadID.x + 4u;
    float _883 = _global_0[((uint)(0u + (((uint)(_877 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _889 = _global_0[((uint)(1u + (((uint)(_877 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _895 = _global_0[((uint)(2u + (((uint)(_877 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    float _901 = _global_0[((uint)(3u + (((uint)(_877 + ((uint)(SV_GroupThreadID.y) * 20))) * 4)))];
    uint _922 = SV_GroupThreadID.y + 1u;
    float _928 = _global_0[((uint)(0u + (((uint)(SV_GroupThreadID.x + (_922 * 20))) * 4)))];
    float _934 = _global_0[((uint)(1u + (((uint)(SV_GroupThreadID.x + (_922 * 20))) * 4)))];
    float _940 = _global_0[((uint)(2u + (((uint)(SV_GroupThreadID.x + (_922 * 20))) * 4)))];
    float _946 = _global_0[((uint)(3u + (((uint)(SV_GroupThreadID.x + (_922 * 20))) * 4)))];
    float _972 = _global_0[((uint)(0u + (((uint)(_742 + (_922 * 20))) * 4)))];
    float _978 = _global_0[((uint)(1u + (((uint)(_742 + (_922 * 20))) * 4)))];
    float _984 = _global_0[((uint)(2u + (((uint)(_742 + (_922 * 20))) * 4)))];
    float _990 = _global_0[((uint)(3u + (((uint)(_742 + (_922 * 20))) * 4)))];
    float _1016 = _global_0[((uint)(0u + (((uint)(_787 + (_922 * 20))) * 4)))];
    float _1022 = _global_0[((uint)(1u + (((uint)(_787 + (_922 * 20))) * 4)))];
    float _1028 = _global_0[((uint)(2u + (((uint)(_787 + (_922 * 20))) * 4)))];
    float _1034 = _global_0[((uint)(3u + (((uint)(_787 + (_922 * 20))) * 4)))];
    float _1060 = _global_0[((uint)(0u + (((uint)(_832 + (_922 * 20))) * 4)))];
    float _1066 = _global_0[((uint)(1u + (((uint)(_832 + (_922 * 20))) * 4)))];
    float _1072 = _global_0[((uint)(2u + (((uint)(_832 + (_922 * 20))) * 4)))];
    float _1078 = _global_0[((uint)(3u + (((uint)(_832 + (_922 * 20))) * 4)))];
    float _1104 = _global_0[((uint)(0u + (((uint)(_877 + (_922 * 20))) * 4)))];
    float _1110 = _global_0[((uint)(1u + (((uint)(_877 + (_922 * 20))) * 4)))];
    float _1116 = _global_0[((uint)(2u + (((uint)(_877 + (_922 * 20))) * 4)))];
    float _1122 = _global_0[((uint)(3u + (((uint)(_877 + (_922 * 20))) * 4)))];
    uint _1143 = SV_GroupThreadID.y + 2u;
    float _1149 = _global_0[((uint)(0u + (((uint)(SV_GroupThreadID.x + (_1143 * 20))) * 4)))];
    float _1155 = _global_0[((uint)(1u + (((uint)(SV_GroupThreadID.x + (_1143 * 20))) * 4)))];
    float _1161 = _global_0[((uint)(2u + (((uint)(SV_GroupThreadID.x + (_1143 * 20))) * 4)))];
    float _1167 = _global_0[((uint)(3u + (((uint)(SV_GroupThreadID.x + (_1143 * 20))) * 4)))];
    float _1193 = _global_0[((uint)(0u + (((uint)(_742 + (_1143 * 20))) * 4)))];
    float _1199 = _global_0[((uint)(1u + (((uint)(_742 + (_1143 * 20))) * 4)))];
    float _1205 = _global_0[((uint)(2u + (((uint)(_742 + (_1143 * 20))) * 4)))];
    float _1211 = _global_0[((uint)(3u + (((uint)(_742 + (_1143 * 20))) * 4)))];
    float _1237 = _global_0[((uint)(0u + (((uint)(_787 + (_1143 * 20))) * 4)))];
    float _1243 = _global_0[((uint)(1u + (((uint)(_787 + (_1143 * 20))) * 4)))];
    float _1249 = _global_0[((uint)(2u + (((uint)(_787 + (_1143 * 20))) * 4)))];
    float _1255 = _global_0[((uint)(3u + (((uint)(_787 + (_1143 * 20))) * 4)))];
    float _1273 = _global_0[((uint)(0u + (((uint)(_832 + (_1143 * 20))) * 4)))];
    float _1279 = _global_0[((uint)(1u + (((uint)(_832 + (_1143 * 20))) * 4)))];
    float _1285 = _global_0[((uint)(2u + (((uint)(_832 + (_1143 * 20))) * 4)))];
    float _1291 = _global_0[((uint)(3u + (((uint)(_832 + (_1143 * 20))) * 4)))];
    float _1317 = _global_0[((uint)(0u + (((uint)(_877 + (_1143 * 20))) * 4)))];
    float _1323 = _global_0[((uint)(1u + (((uint)(_877 + (_1143 * 20))) * 4)))];
    float _1329 = _global_0[((uint)(2u + (((uint)(_877 + (_1143 * 20))) * 4)))];
    float _1335 = _global_0[((uint)(3u + (((uint)(_877 + (_1143 * 20))) * 4)))];
    uint _1356 = SV_GroupThreadID.y + 3u;
    float _1362 = _global_0[((uint)(0u + (((uint)(SV_GroupThreadID.x + (_1356 * 20))) * 4)))];
    float _1368 = _global_0[((uint)(1u + (((uint)(SV_GroupThreadID.x + (_1356 * 20))) * 4)))];
    float _1374 = _global_0[((uint)(2u + (((uint)(SV_GroupThreadID.x + (_1356 * 20))) * 4)))];
    float _1380 = _global_0[((uint)(3u + (((uint)(SV_GroupThreadID.x + (_1356 * 20))) * 4)))];
    float _1406 = _global_0[((uint)(0u + (((uint)(_742 + (_1356 * 20))) * 4)))];
    float _1412 = _global_0[((uint)(1u + (((uint)(_742 + (_1356 * 20))) * 4)))];
    float _1418 = _global_0[((uint)(2u + (((uint)(_742 + (_1356 * 20))) * 4)))];
    float _1424 = _global_0[((uint)(3u + (((uint)(_742 + (_1356 * 20))) * 4)))];
    float _1450 = _global_0[((uint)(0u + (((uint)(_787 + (_1356 * 20))) * 4)))];
    float _1456 = _global_0[((uint)(1u + (((uint)(_787 + (_1356 * 20))) * 4)))];
    float _1462 = _global_0[((uint)(2u + (((uint)(_787 + (_1356 * 20))) * 4)))];
    float _1468 = _global_0[((uint)(3u + (((uint)(_787 + (_1356 * 20))) * 4)))];
    float _1494 = _global_0[((uint)(0u + (((uint)(_832 + (_1356 * 20))) * 4)))];
    float _1500 = _global_0[((uint)(1u + (((uint)(_832 + (_1356 * 20))) * 4)))];
    float _1506 = _global_0[((uint)(2u + (((uint)(_832 + (_1356 * 20))) * 4)))];
    float _1512 = _global_0[((uint)(3u + (((uint)(_832 + (_1356 * 20))) * 4)))];
    float _1538 = _global_0[((uint)(0u + (((uint)(_877 + (_1356 * 20))) * 4)))];
    float _1544 = _global_0[((uint)(1u + (((uint)(_877 + (_1356 * 20))) * 4)))];
    float _1550 = _global_0[((uint)(2u + (((uint)(_877 + (_1356 * 20))) * 4)))];
    float _1556 = _global_0[((uint)(3u + (((uint)(_877 + (_1356 * 20))) * 4)))];
    uint _1577 = SV_GroupThreadID.y + 4u;
    float _1583 = _global_0[((uint)(0u + (((uint)(SV_GroupThreadID.x + (_1577 * 20))) * 4)))];
    float _1589 = _global_0[((uint)(1u + (((uint)(SV_GroupThreadID.x + (_1577 * 20))) * 4)))];
    float _1595 = _global_0[((uint)(2u + (((uint)(SV_GroupThreadID.x + (_1577 * 20))) * 4)))];
    float _1601 = _global_0[((uint)(3u + (((uint)(SV_GroupThreadID.x + (_1577 * 20))) * 4)))];
    float _1627 = _global_0[((uint)(0u + (((uint)(_742 + (_1577 * 20))) * 4)))];
    float _1633 = _global_0[((uint)(1u + (((uint)(_742 + (_1577 * 20))) * 4)))];
    float _1639 = _global_0[((uint)(2u + (((uint)(_742 + (_1577 * 20))) * 4)))];
    float _1645 = _global_0[((uint)(3u + (((uint)(_742 + (_1577 * 20))) * 4)))];
    float _1671 = _global_0[((uint)(0u + (((uint)(_787 + (_1577 * 20))) * 4)))];
    float _1677 = _global_0[((uint)(1u + (((uint)(_787 + (_1577 * 20))) * 4)))];
    float _1683 = _global_0[((uint)(2u + (((uint)(_787 + (_1577 * 20))) * 4)))];
    float _1689 = _global_0[((uint)(3u + (((uint)(_787 + (_1577 * 20))) * 4)))];
    float _1715 = _global_0[((uint)(0u + (((uint)(_832 + (_1577 * 20))) * 4)))];
    float _1721 = _global_0[((uint)(1u + (((uint)(_832 + (_1577 * 20))) * 4)))];
    float _1727 = _global_0[((uint)(2u + (((uint)(_832 + (_1577 * 20))) * 4)))];
    float _1733 = _global_0[((uint)(3u + (((uint)(_832 + (_1577 * 20))) * 4)))];
    float _1759 = _global_0[((uint)(0u + (((uint)(_877 + (_1577 * 20))) * 4)))];
    float _1765 = _global_0[((uint)(1u + (((uint)(_877 + (_1577 * 20))) * 4)))];
    float _1771 = _global_0[((uint)(2u + (((uint)(_877 + (_1577 * 20))) * 4)))];
    float _1777 = _global_0[((uint)(3u + (((uint)(_877 + (_1577 * 20))) * 4)))];
    float _1798 = ((((((((((((((((((((((((_748 + _711) + _793) + _838) + _883) + _928) + _972) + _1016) + _1060) + _1104) + _1149) + _1193) + _1237) + _1273) + _1317) + _1362) + _1406) + _1450) + _1494) + _1538) + _1583) + _1627) + _1671) + _1715) + _1759) * 0.03999999910593033f;
    float _1799 = ((((((((((((((((((((((((_754 + _717) + _799) + _844) + _889) + _934) + _978) + _1022) + _1066) + _1110) + _1155) + _1199) + _1243) + _1279) + _1323) + _1368) + _1412) + _1456) + _1500) + _1544) + _1589) + _1633) + _1677) + _1721) + _1765) * 0.03999999910593033f;
    float _1800 = ((((((((((((((((((((((((_760 + _723) + _805) + _850) + _895) + _940) + _984) + _1028) + _1072) + _1116) + _1161) + _1205) + _1249) + _1285) + _1329) + _1374) + _1418) + _1462) + _1506) + _1550) + _1595) + _1639) + _1683) + _1727) + _1771) * 0.03999999910593033f;
    float _1801 = ((((((((((((((((((((((((_766 + _729) + _811) + _856) + _901) + _946) + _990) + _1034) + _1078) + _1122) + _1167) + _1211) + _1255) + _1291) + _1335) + _1380) + _1424) + _1468) + _1512) + _1556) + _1601) + _1645) + _1689) + _1733) + _1777) * 0.03999999910593033f;
    float _1824 = gSpecFastHistoryClampingColorBoxSigmaScale * sqrt(abs(((((((((((((((((((((((((((_748 * _748) + (_711 * _711)) + (_793 * _793)) + (_838 * _838)) + (_883 * _883)) + (_928 * _928)) + (_972 * _972)) + (_1016 * _1016)) + (_1060 * _1060)) + (_1104 * _1104)) + (_1149 * _1149)) + (_1193 * _1193)) + (_1237 * _1237)) + (_1273 * _1273)) + (_1317 * _1317)) + (_1362 * _1362)) + (_1406 * _1406)) + (_1450 * _1450)) + (_1494 * _1494)) + (_1538 * _1538)) + (_1583 * _1583)) + (_1627 * _1627)) + (_1671 * _1671)) + (_1715 * _1715)) + (_1759 * _1759)) * 0.03999999910593033f) - (_1798 * _1798)));
    float _1825 = gSpecFastHistoryClampingColorBoxSigmaScale * sqrt(abs(((((((((((((((((((((((((((_754 * _754) + (_717 * _717)) + (_799 * _799)) + (_844 * _844)) + (_889 * _889)) + (_934 * _934)) + (_978 * _978)) + (_1022 * _1022)) + (_1066 * _1066)) + (_1110 * _1110)) + (_1155 * _1155)) + (_1199 * _1199)) + (_1243 * _1243)) + (_1279 * _1279)) + (_1323 * _1323)) + (_1368 * _1368)) + (_1412 * _1412)) + (_1456 * _1456)) + (_1500 * _1500)) + (_1544 * _1544)) + (_1589 * _1589)) + (_1633 * _1633)) + (_1677 * _1677)) + (_1721 * _1721)) + (_1765 * _1765)) * 0.03999999910593033f) - (_1799 * _1799)));
    float _1826 = gSpecFastHistoryClampingColorBoxSigmaScale * sqrt(abs(((((((((((((((((((((((((((_760 * _760) + (_723 * _723)) + (_805 * _805)) + (_850 * _850)) + (_895 * _895)) + (_940 * _940)) + (_984 * _984)) + (_1028 * _1028)) + (_1072 * _1072)) + (_1116 * _1116)) + (_1161 * _1161)) + (_1205 * _1205)) + (_1249 * _1249)) + (_1285 * _1285)) + (_1329 * _1329)) + (_1374 * _1374)) + (_1418 * _1418)) + (_1462 * _1462)) + (_1506 * _1506)) + (_1550 * _1550)) + (_1595 * _1595)) + (_1639 * _1639)) + (_1683 * _1683)) + (_1727 * _1727)) + (_1771 * _1771)) * 0.03999999910593033f) - (_1800 * _1800)));
    float _1827 = gSpecFastHistoryClampingColorBoxSigmaScale * sqrt(abs(((((((((((((((((((((((((((_766 * _766) + (_729 * _729)) + (_811 * _811)) + (_856 * _856)) + (_901 * _901)) + (_946 * _946)) + (_990 * _990)) + (_1034 * _1034)) + (_1078 * _1078)) + (_1122 * _1122)) + (_1167 * _1167)) + (_1211 * _1211)) + (_1255 * _1255)) + (_1291 * _1291)) + (_1335 * _1335)) + (_1380 * _1380)) + (_1424 * _1424)) + (_1468 * _1468)) + (_1512 * _1512)) + (_1556 * _1556)) + (_1601 * _1601)) + (_1645 * _1645)) + (_1689 * _1689)) + (_1733 * _1733)) + (_1777 * _1777)) * 0.03999999910593033f) - (_1801 * _1801)));
    float _1848 = min(max(_702, min((_1798 - _1824), _1237)), max((_1824 + _1798), _1237));
    float _1849 = min(max(_703, min((_1799 - _1825), _1243)), max((_1825 + _1799), _1243));
    float _1850 = min(max(_704, min((_1800 - _1826), _1249)), max((_1826 + _1800), _1249));
    float _1851 = min(max(_705, min((_1801 - _1827), _1255)), max((_1827 + _1801), _1255));
    [branch]
    if (gSpecMaxFastAccumulatedFrameNum < gSpecMaxAccumulatedFrameNum) {
      _1870 = (lerp(_1848, _702, _113));
      _1871 = (lerp(_1849, _703, _113));
      _1872 = (lerp(_1850, _704, _113));
      _1873 = (lerp(_1851, _705, _113));
    } else {
      _1870 = _702;
      _1871 = _703;
      _1872 = _704;
      _1873 = _705;
    }
    [branch]
    if (!(gSpecAntiFirefly == 0)) {
      float _1882 = min(max(_1870, min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(1e+06f, _711), _748), _793), _838), _883), _928), _972), _1016), _1060), _1104), _1149), _1193), _1273), _1317), _1362), _1406), _1450), _1494), _1538), _1583), _1627), _1671), _1715), _1759)), max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(-1e+06f, _711), _748), _793), _838), _883), _928), _972), _1016), _1060), _1104), _1149), _1193), _1273), _1317), _1362), _1406), _1450), _1494), _1538), _1583), _1627), _1671), _1715), _1759));
      float _1883 = min(max(_1871, min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(1e+06f, _717), _754), _799), _844), _889), _934), _978), _1022), _1066), _1110), _1155), _1199), _1279), _1323), _1368), _1412), _1456), _1500), _1544), _1589), _1633), _1677), _1721), _1765)), max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(-1e+06f, _717), _754), _799), _844), _889), _934), _978), _1022), _1066), _1110), _1155), _1199), _1279), _1323), _1368), _1412), _1456), _1500), _1544), _1589), _1633), _1677), _1721), _1765));
      float _1884 = min(max(_1872, min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(1e+06f, _723), _760), _805), _850), _895), _940), _984), _1028), _1072), _1116), _1161), _1205), _1285), _1329), _1374), _1418), _1462), _1506), _1550), _1595), _1639), _1683), _1727), _1771)), max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(-1e+06f, _723), _760), _805), _850), _895), _940), _984), _1028), _1072), _1116), _1161), _1205), _1285), _1329), _1374), _1418), _1462), _1506), _1550), _1595), _1639), _1683), _1727), _1771));
      float _1885 = min(max(_1873, min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(min(1e+06f, _729), _766), _811), _856), _901), _946), _990), _1034), _1078), _1122), _1167), _1211), _1291), _1335), _1380), _1424), _1468), _1512), _1556), _1601), _1645), _1689), _1733), _1777)), max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(max(-1e+06f, _729), _766), _811), _856), _901), _946), _990), _1034), _1078), _1122), _1167), _1211), _1291), _1335), _1380), _1424), _1468), _1512), _1556), _1601), _1645), _1689), _1733), _1777));
      _1899 = (lerp(_1882, _1870, _113));
      _1900 = (lerp(_1883, _1871, _113));
      _1901 = (lerp(_1884, _1872, _113));
      _1902 = (lerp(_1885, _1873, _113));
    } else {
      _1899 = _1870;
      _1900 = _1871;
      _1901 = _1872;
      _1902 = _1873;
    }
    gOut_Spec[int2((uint)(SV_DispatchThreadID.x), (uint)(SV_DispatchThreadID.y))] = float4(_1899, _1900, _1901, _1902);
  }
}
