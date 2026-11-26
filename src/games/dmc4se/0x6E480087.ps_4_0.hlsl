#include "./shared.h"


cbuffer _Globals : register(b0)
{
  float4 fSphericalSectioningCenter : packoffset(c0);
  float4 fSphericalSectioningRadius : packoffset(c1);
  float fNormalBias : packoffset(c2);
  float fNormalWrap : packoffset(c2.y);
  float fAlphaClipThreshold : packoffset(c2.z);
  float3 fAlbedoColor : packoffset(c3);
  float4 fAlbedoBlendColor : packoffset(c4);
  float fNormalMapFlip : packoffset(c5);
  float fDetailNormalPower : packoffset(c5.y);
  float fDetailNormalUVScale : packoffset(c5.z);
  float fDetailNormal2Power : packoffset(c5.w);
  float fDetailNormal2UVScale : packoffset(c6);
  float fPrimaryShift : packoffset(c6.y);
  float fSecondaryShift : packoffset(c6.z);
  float fParallaxFactor : packoffset(c6.w);
  float fParallaxSelfOcclusion : packoffset(c7);
  float fParallaxMinSample : packoffset(c7.y);
  float fParallaxMaxSample : packoffset(c7.z);
  float3 fLightMapColor : packoffset(c8);
  float3 fThinMapColor : packoffset(c9);
  float fThinScattering : packoffset(c9.w);
  float2 fScreenUVScale : packoffset(c10);
  float2 fScreenUVOffset : packoffset(c10.z);
  float2 fIndirectOffset : packoffset(c11);
  float2 fIndirectScale : packoffset(c11.z);
  float fFresnelSchlick : packoffset(c12);
  float3 fFresnelSchlickRGB : packoffset(c12.y);
  float3 fSpecularColor : packoffset(c13);
  float fShininess : packoffset(c13.w);
  float3 fEmissionColor : packoffset(c14);
  float4 fShadowColor : packoffset(c15);
  float4 fConstantColor : packoffset(c16);
  float fRoughness : packoffset(c17);
  float3 fRoughnessRGB : packoffset(c17.y);
  float3 fAnisotoropicDirection : packoffset(c18);
  float fSmoothness : packoffset(c18.w);
  float2 fAnistropicUV : packoffset(c19);
  float fPrimaryExpo : packoffset(c19.z);
  float fSecondaryExpo : packoffset(c19.w);
  float3 fPrimaryColor : packoffset(c20);
  float3 fSecondaryColor : packoffset(c21);
  float4 fLightMapScale : packoffset(c22);
  float fShadowMapScale : packoffset(c23);
}

cbuffer CBHDRFactor : register(b1)
{
  float fHDRCompressEncode : packoffset(c0);
  float fHDRCompressDecode : packoffset(c0.y);
  float fHDRRelativeEncode : packoffset(c0.z);
  float fHDRRelativeDecode : packoffset(c0.w);
}

cbuffer CBScreen : register(b2)
{
  float2 fScreenOffset : packoffset(c0);
  float2 fScreenScale : packoffset(c0.z);
  float2 fScreenSize : packoffset(c1);
  float2 fScreenInverseSize : packoffset(c1.z);
  float2 fScreenHalfPixelOffset : packoffset(c2);
}

cbuffer CBROPTest : register(b3)
{
  float fAlphaRef : packoffset(c0);
  float fStencilRef : packoffset(c0.y);
  float fDepthBias : packoffset(c0.z);
  float fAlphaToCoverageScale : packoffset(c0.w);
  float fGlobalTransparency : packoffset(c1);
}

cbuffer CBViewProjection : register(b4)
{
  row_major float4x4 fViewProj : packoffset(c0);
  float3 fCameraPos : packoffset(c4);
  float fCameraNearClip : packoffset(c4.w);
  float3 fCameraDir : packoffset(c5);
  float fCameraTargetDist : packoffset(c5.w);
  float fCameraFarClipLog2 : packoffset(c6);
  float fCameraFarClipLog2Inv : packoffset(c6.y);
  row_major float4x4 fView : packoffset(c7);
  row_major float4x4 fViewI : packoffset(c11);
  row_major float4x4 fProj : packoffset(c15);
  row_major float4x4 fProjI : packoffset(c19);
  row_major float4x4 fViewProjI : packoffset(c23);
}

cbuffer CBMaterial : register(b5)
{
  float3 fDiffuseColor : packoffset(c0);
  float fTransparency : packoffset(c0.w);
  float3 fReflectiveColor : packoffset(c1);
  float fTransparencyVolume : packoffset(c1.w);
  row_major float2x4 fUVTransform : packoffset(c2);
  row_major float2x4 fUVTransform2 : packoffset(c4);
  row_major float2x4 fUVTransform3 : packoffset(c6);
}

cbuffer CBShadowReceive0 : register(b6)
{

  struct
  {
    float3 fShadowLightPos;
    float fShadowLightRangeInverse;
    float fShadowDistanceBias;
    float3 fShadowLightDir;
    float4 fShadowRange;
    row_major float4x4 fShadowProjectNear;
    row_major float4x4 fShadowProjectMiddle;
    row_major float4x4 fShadowProjectFar;
    float2 fShadowDistanceAttn;
    float2 fShadowAngularAttn;
    float2 fShadowCubeFaceOffset;
    float2 fShadowCubeFaceScale;
    float4 fShadowMapSize;
    row_major float3x4 fShadowRangeMat;
    float fShadowFaceIncreaseAttn;
    float fShadowFaceDecreaseAttn;
    float fShadowDistanceScaledDepthBias;
    float fShadowVarianceEpsilon;
    float fShadowPmaxPower;
    float fShadowNearPlane;
    float fShadowAttn;
  } sShadowReceiveParam0 : packoffset(c0);

}

cbuffer CBAmbient : register(b7)
{
  float3 fAmbientColor : packoffset(c0);
  float fLightMapMask : packoffset(c0.w);
  float fEnvMapMask : packoffset(c1);
  float2 fLightMask : packoffset(c1.y);
  float fDeferredLightingDiffuseLuminanceThreshold : packoffset(c1.w);
  float4 fSHCoef[7] : packoffset(c2);
  float fDeferredLightingLogRangeCoeffDec : packoffset(c9);
  float fHalfLambertBlendCoeff : packoffset(c9.y);
}

cbuffer CBAppReflect : register(b8)
{
  float fEnvMapPower : packoffset(c0);
  float fEnvMapBias : packoffset(c0.y);
}

cbuffer CBFresnelSchlick : register(b9)
{
  float fFresnelBias : packoffset(c0);
}

cbuffer CBFog : register(b10)
{
  float3 fFogColor : packoffset(c0);
  float fFogDensity : packoffset(c0.w);
  float fFogHStart : packoffset(c1);
  float fFogHInvRange : packoffset(c1.y);
  float fFogStart : packoffset(c1.z);
  float fFogInvRange : packoffset(c1.w);
  float3 fFogHColor : packoffset(c2);
  float fFogHDensity : packoffset(c2.w);
  float fFogHUVScale : packoffset(c3);
  float fFogHSlopeBias : packoffset(c3.y);
  float2 fFogHUVOffset : packoffset(c3.z);
  float fFogDiffuseBlend : packoffset(c4);
}

SamplerState SSShadowDepth_s : register(s0);
SamplerState SSNormalMap_s : register(s1);
SamplerState SSAlbedoMap_s : register(s2);
SamplerState SSEnvMap_s : register(s3);
SamplerState SSSpecularMap_s : register(s4);
SamplerState SSLinear_s : register(s5);
Texture2D<float4> tShadowMapCombine0 : register(t0);
Texture2D<float4> tNormalMap : register(t1);
Texture2D<float4> tAlbedoMap : register(t2);
TextureCube<float4> tGlobalEnvMap : register(t3);
Texture2D<float4> tSpecularMap : register(t4);
Texture2D<float4> tDistortionMap : register(t5);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  float4 v3 : TEXCOORD2,
  float4 v4 : TEXCOORD3,
  float4 v5 : TEXCOORD4,
  float4 v6 : TEXCOORD5,
  uint v7 : SV_IsFrontFace0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyz = v7.xxx ? v2.xyz : -v2.xyz;
  r0.w = dot(r0.xyz, r0.xyz);
  r0.w = sqrt(r0.w);
  r0.w = max(9.99999997e-007, r0.w);
  r1.x = dot(v4.xyz, v4.xyz);
  r1.x = sqrt(r1.x);
  r1.x = max(9.99999997e-007, r1.x);
  r1.y = dot(v5.xyz, v5.xyz);
  r1.y = sqrt(r1.y);
  r1.y = max(9.99999997e-007, r1.y);
  r0.xyz = r0.xyz / r0.www;
  r2.xyz = v4.xyz / r1.xxx;
  r1.xyz = v5.xyz / r1.yyy;
  r3.xyz = -fCameraPos.xyz + v3.xyz;
  r0.w = dot(r3.xyz, r3.xyz);
  r0.w = rsqrt(r0.w);
  r3.xyz = r0.www * r3.xyz;
  r4.xy = fScreenInverseSize.xy * v0.xy;
  r5.xyz = sShadowReceiveParam0.fShadowLightPos.xyz + -v3.xyz;
  r0.w = dot(r5.xyz, r5.xyz);
  r0.w = rsqrt(r0.w);
  r5.xyz = r0.www * r5.xyz;
  r0.w = dot(r5.xyz, r0.xyz);
  r1.w = cmp(r0.w < 0);
  if (r1.w != 0) {
    r1.w = 1;
  } else {
    r5.xyzw = sShadowReceiveParam0.fShadowProjectNear._m10_m11_m12_m13 * v3.yyyy;
    r5.xyzw = v3.xxxx * sShadowReceiveParam0.fShadowProjectNear._m00_m01_m02_m03 + r5.xyzw;
    r5.xyzw = v3.zzzz * sShadowReceiveParam0.fShadowProjectNear._m20_m21_m22_m23 + r5.xyzw;
    r5.xyzw = sShadowReceiveParam0.fShadowProjectNear._m30_m31_m32_m33 + r5.xyzw;
    r5.xyz = r5.xyz / r5.www;
    r6.xyz = cmp(float3(0,0,0) < r5.xyz);
    r6.xyz = cmp((int3)r6.xyz != int3(0,0,0));
    r2.w = r6.x ? r6.y : 0;
    r2.w = r6.z ? r2.w : 0;
    r6.xyz = cmp(r5.xyz < float3(1,1,1));
    r6.xyz = cmp((int3)r6.xyz != int3(0,0,0));
    r3.w = r6.x ? r6.y : 0;
    r3.w = r6.z ? r3.w : 0;
    r2.w = (int)r2.w & (int)r3.w;
    if (r2.w != 0) {
      r6.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-1, -1));
      r7.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-1, 0));
      r8.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-1, 1)).yzxw;
      r9.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(0, -1));
      r10.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(0, 0));
      r11.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(0, 1)).yzxw;
      r12.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(1, -1));
      r13.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(1, 0));
      r14.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(1, 1)).yzxw;
      r8.x = r6.x;
      r8.y = r7.x;
      r6.xyz = cmp(r5.zzz >= r8.xyz);
      r6.xyz = r6.xyz ? float3(1,1,1) : float3(0,0,0);
      r11.x = r9.x;
      r11.y = r10.x;
      r7.xyz = cmp(r5.zzz >= r11.xyz);
      r7.xyz = r7.xyz ? float3(1,1,1) : float3(0,0,0);
      r14.x = r12.x;
      r14.y = r13.x;
      r8.xyz = cmp(r5.zzz >= r14.xyz);
      r8.xyz = r8.xyz ? float3(1,1,1) : float3(0,0,0);
      r5.xy = sShadowReceiveParam0.fShadowMapSize.xy * r5.xy;
      r5.xy = frac(r5.xy);
      r7.xyz = r7.xyz + r6.xyz;
      r6.xyz = r8.xyz + -r6.xyz;
      r6.xyz = r6.xyz * r5.xxx + r7.xyz;
      r2.w = r6.x + r6.y;
      r3.w = r6.z + -r6.x;
      r2.w = r3.w * r5.y + r2.w;
      r2.w = 0.25 * r2.w;
    } else {
      r2.w = 0;
    }
    r0.w = saturate(sShadowReceiveParam0.fShadowFaceIncreaseAttn * r0.w);
    r0.w = 1 + -r0.w;
    r1.w = max(r0.w, r2.w);
  }
  r5.xyz = -sShadowReceiveParam0.fShadowLightPos.xyz + v3.xyz;
  r0.w = dot(r5.xyz, r5.xyz);
  r0.w = sqrt(r0.w);
  r5.xyz = r5.xyz / r0.www;
  r2.w = sShadowReceiveParam0.fShadowDistanceAttn.x + -sShadowReceiveParam0.fShadowDistanceAttn.y;
  r0.w = -sShadowReceiveParam0.fShadowDistanceAttn.y + r0.w;
  r2.w = 1 / r2.w;
  r0.w = saturate(r2.w * r0.w);
  r2.w = r0.w * -2 + 3;
  r0.w = r0.w * r0.w;
  r0.w = r0.w * r2.w;
  r2.w = dot(r5.xyz, sShadowReceiveParam0.fShadowLightDir.xyz);
  r3.w = sShadowReceiveParam0.fShadowAngularAttn.x + -sShadowReceiveParam0.fShadowAngularAttn.y;
  r2.w = -sShadowReceiveParam0.fShadowAngularAttn.y + r2.w;
  r3.w = 1 / r3.w;
  r2.w = saturate(r3.w * r2.w);
  r3.w = r2.w * -2 + 3;
  r2.w = r2.w * r2.w;
  r2.w = r2.w * r3.w;
  r0.w = r2.w * r0.w;
  r0.w = r0.w * r1.w;
  r0.w = fShadowColor.w * r0.w;
  r0.w = max(0, r0.w);
  r0.w = max(fLightMask.x, r0.w);
  r5.xyzw = tNormalMap.Sample(SSNormalMap_s, v6.xy);
  r1.w = -0.498039216 + r5.x;
  r1.w = r1.w + r1.w;
  r2.w = -0.498039216 + r5.y;
  r2.w = r2.w + r2.w;
  r3.w = -r1.w * r1.w + 1;
  r3.w = -r2.w * r2.w + r3.w;
  r3.w = max(9.99999975e-005, r3.w);
  r3.w = sqrt(r3.w);
  r1.xyz = r2.www * r1.xyz;
  r1.xyz = fNormalMapFlip * r1.xyz;
  r1.xyz = r2.xyz * r1.www + r1.xyz;
  r0.xyz = r0.xyz * r3.www + r1.xyz;
  r1.x = dot(r0.xyz, r0.xyz);
  r1.x = rsqrt(r1.x);
  r0.xyz = r1.xxx * r0.xyz;
  r1.x = dot(r3.xyz, r0.xyz);
  r1.y = r1.x + r1.x;
  r2.xyz = r0.xyz * -r1.yyy + r3.xyz;
  r6.xyzw = tAlbedoMap.Sample(SSAlbedoMap_s, v6.xy);
  r6.xyz = fAlbedoColor.xyz * r6.xyz;
  r1.y = v1.w * r6.w;
  r1.z = fTransparency * r1.y;
  r7.xyz = fDiffuseColor.xyz * v2.www;
  r2.xyzw = tGlobalEnvMap.SampleLevel(SSEnvMap_s, r2.xyz, fEnvMapBias);
  r2.xyz = fReflectiveColor.xyz * r2.xyz;
  r2.xyz = fEnvMapPower * r2.xyz;
  r0.w = fEnvMapMask * -r0.w + 1;
  r2.xyz = r0.www * r2.xyz;
  r8.xyzw = tSpecularMap.Sample(SSSpecularMap_s, v6.xy);
  r2.xyz = r8.xxx * r2.xyz;
  r2.xyz = v2.www * r2.xyz;
  r0.w = 1 + -r1.x;
  r1.x = r0.w * r0.w;
  r1.x = r1.x * r1.x;
  r0.w = r1.x * r0.w;
  r0.w = saturate(fFresnelSchlick * r0.w + fFresnelBias);
  r0.w = 1 + -r0.w;
  r4.xy = r4.xy * fScreenUVScale.xy + fScreenUVOffset.xy;
  r5.xy = float2(-0.498039216,-0.498039216) + r5.xy;
  r5.xy = fNormalWrap * r5.xy;
  r5.xy = float2(0.00249999994,0.00249999994) * r5.xy;
  r1.x = -r1.y * fTransparency + 1;
  r1.xy = -r5.xy * r1.xx + r4.xy;
  r4.xyzw = tDistortionMap.Sample(SSLinear_s, r1.xy);
  r4.xyz = fHDRCompressDecode * r4.xyz;
  r5.xyz = r7.xyz * r6.xyz + -r4.xyz;
  r1.xyz = r1.zzz * r5.xyz + r4.xyz;
  r1.w = fDiffuseColor.y * 2 + -1;
  r0.x = dot(-r3.xyz, r0.xyz);
  r0.x = max(0, r0.x);
  r0.x = r0.x + r1.w;
  r0.x = min(1, r0.x);
  r1.xyz = r2.xyz * r0.www + r1.xyz;
  o0.w = fGlobalTransparency * r0.x;
  r0.xyz = fCameraPos.xyz + -v3.xyz;
  r0.x = dot(r0.xyz, r0.xyz);
  r0.x = sqrt(r0.x);
  r0.x = -fFogHStart + r0.x;
  r0.x = fFogHInvRange * r0.x;
  r2.xyz = fFogColor.xyz;
  r2.w = fFogHUVScale;
  r3.xyz = v3.xyz;
  r3.w = 1;
  r0.y = dot(r2.xyzw, r3.xyzw);
  r0.y = fFogHSlopeBias * r0.y;
  r0.x = max(r0.y, r0.x);
  r0.x = min(fFogHDensity, r0.x);
  r0.x = max(0, r0.x);
  r2.xyz = fFogHColor.xyz + -r1.xyz;
  r0.xyz = r0.xxx * r2.xyz + r1.xyz;
  o0.xyz = fHDRCompressEncode * r0.xyz;
  o0.w = saturate(o0.w);
  return;
}