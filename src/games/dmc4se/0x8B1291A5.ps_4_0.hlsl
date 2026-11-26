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

SamplerState SSShadowDepth_s : register(s0);
SamplerState SSNormalMap_s : register(s1);
SamplerState SSAlbedoMap_s : register(s2);
SamplerState SSLinear_s : register(s3);
Texture2D<float4> tShadowMapCombine0 : register(t0);
Texture2D<float4> tNormalMap : register(t1);
Texture2D<float4> tAlbedoMap : register(t2);
Texture2D<float4> tDistortionMap : register(t3);


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
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r21,r22,r23;
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
  r0.w = dot(-sShadowReceiveParam0.fShadowLightDir.xyz, r0.xyz);
  r1.w = cmp(r0.w < 0);
  if (r1.w != 0) {
    r1.w = 1;
  } else {
    r2.w = cmp(v0.w < sShadowReceiveParam0.fShadowRange.z);
    if (r2.w != 0) {
      r5.xyz = sShadowReceiveParam0.fShadowProjectNear._m10_m11_m12 * v3.yyy;
      r5.xyz = v3.xxx * sShadowReceiveParam0.fShadowProjectNear._m00_m01_m02 + r5.xyz;
      r5.xyz = v3.zzz * sShadowReceiveParam0.fShadowProjectNear._m20_m21_m22 + r5.xyz;
      r5.xyz = sShadowReceiveParam0.fShadowProjectNear._m30_m31_m32 + r5.xyz;
      r6.xyz = sShadowReceiveParam0.fShadowProjectMiddle._m10_m11_m12 * v3.yyy;
      r6.xyz = v3.xxx * sShadowReceiveParam0.fShadowProjectMiddle._m00_m01_m02 + r6.xyz;
      r6.xyz = v3.zzz * sShadowReceiveParam0.fShadowProjectMiddle._m20_m21_m22 + r6.xyz;
      r6.xyz = sShadowReceiveParam0.fShadowProjectMiddle._m30_m31_m32 + r6.xyz;
      r7.xyz = sShadowReceiveParam0.fShadowProjectFar._m10_m11_m12 * v3.yyy;
      r7.xyz = v3.xxx * sShadowReceiveParam0.fShadowProjectFar._m00_m01_m02 + r7.xyz;
      r7.xyz = v3.zzz * sShadowReceiveParam0.fShadowProjectFar._m20_m21_m22 + r7.xyz;
      r7.xyz = sShadowReceiveParam0.fShadowProjectFar._m30_m31_m32 + r7.xyz;
      r8.xy = r5.xy * float2(1,3) + float2(-0.5,-0.5);
      r9.xy = r6.xy * float2(1,3) + float2(-0.5,-1.5);
      r10.xy = r7.xy * float2(1,3) + float2(-0.5,-2.5);
      r11.xy = cmp(abs(r8.xy) < float2(0.497500002,0.497500002));
      r11.xy = cmp((int2)r11.xy != int2(0,0));
      r2.w = r11.x ? r11.y : 0;
      r11.xy = cmp(abs(r9.xy) < float2(0.497500002,0.497500002));
      r11.xy = cmp((int2)r11.xy != int2(0,0));
      r3.w = r11.x ? r11.y : 0;
      r9.xy = r3.ww ? abs(r9.xy) : abs(r10.xy);
      r8.xy = r2.ww ? abs(r8.xy) : r9.xy;
      r9.xyz = r3.www ? r6.xyz : r7.xyz;
      r5.xyz = r2.www ? r5.xyz : r9.xyz;
      r6.xyz = r2.www ? r6.xyz : r7.xyz;
      r7.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-2, -2));
      r9.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-2, -1));
      r10.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-2, 0));
      r11.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-2, 1)).yzwx;
      r12.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-1, -2));
      r13.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-1, -1));
      r14.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-1, 0));
      r15.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(-1, 1)).yzwx;
      r16.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(0, -2));
      r17.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(0, -1));
      r18.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(0, 0));
      r19.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(0, 1)).yzwx;
      r20.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(1, -2));
      r21.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(1, -1));
      r22.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(1, 0));
      r23.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r5.xy, 0, int2(1, 1)).yzwx;
      r11.x = r7.x;
      r11.y = r9.x;
      r11.z = r10.x;
      r7.xyzw = cmp(r5.zzzz >= r11.xyzw);
      r7.xyzw = r7.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
      r15.x = r12.x;
      r15.y = r13.x;
      r15.z = r14.x;
      r9.xyzw = cmp(r5.zzzz >= r15.xyzw);
      r9.xyzw = r9.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
      r19.x = r16.x;
      r19.y = r17.x;
      r19.z = r18.x;
      r10.xyzw = cmp(r5.zzzz >= r19.xyzw);
      r10.xyzw = r10.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
      r23.x = r20.x;
      r23.y = r21.x;
      r23.z = r22.x;
      r11.xyzw = cmp(r5.zzzz >= r23.xyzw);
      r11.xyzw = r11.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
      r5.xy = sShadowReceiveParam0.fShadowMapSize.xy * r5.xy;
      r5.xy = frac(r5.xy);
      r9.xyzw = r9.xyzw + r7.xyzw;
      r9.xyzw = r9.xyzw + r10.xyzw;
      r7.xyzw = r11.xyzw + -r7.xyzw;
      r7.xyzw = r7.xyzw * r5.xxxx + r9.xyzw;
      r2.w = r7.x + r7.y;
      r2.w = r2.w + r7.z;
      r3.w = r7.w + -r7.x;
      r2.w = r3.w * r5.y + r2.w;
      r2.w = r2.w / 9;
      r5.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(-2, -2));
      r7.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(-2, -1));
      r9.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(-2, 0));
      r10.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(-2, 1)).yzwx;
      r11.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(-1, -2));
      r12.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(-1, -1));
      r13.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(-1, 0));
      r14.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(-1, 1)).yzwx;
      r15.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(0, -2));
      r16.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(0, -1));
      r17.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(0, 0));
      r18.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(0, 1)).yzwx;
      r19.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(1, -2));
      r20.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(1, -1));
      r21.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(1, 0));
      r22.xyzw = tShadowMapCombine0.SampleLevel(SSShadowDepth_s, r6.xy, 0, int2(1, 1)).yzwx;
      r10.x = r5.x;
      r10.y = r7.x;
      r10.z = r9.x;
      r5.xyzw = cmp(r6.zzzz >= r10.xyzw);
      r5.xyzw = r5.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
      r14.x = r11.x;
      r14.y = r12.x;
      r14.z = r13.x;
      r7.xyzw = cmp(r6.zzzz >= r14.xyzw);
      r7.xyzw = r7.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
      r18.x = r15.x;
      r18.y = r16.x;
      r18.z = r17.x;
      r9.xyzw = cmp(r6.zzzz >= r18.xyzw);
      r9.xyzw = r9.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
      r22.x = r19.x;
      r22.y = r20.x;
      r22.z = r21.x;
      r10.xyzw = cmp(r6.zzzz >= r22.xyzw);
      r10.xyzw = r10.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
      r6.xy = sShadowReceiveParam0.fShadowMapSize.xy * r6.xy;
      r6.xy = frac(r6.xy);
      r7.xyzw = r7.xyzw + r5.xyzw;
      r7.xyzw = r7.xyzw + r9.xyzw;
      r5.xyzw = r10.xyzw + -r5.xyzw;
      r5.xyzw = r5.xyzw * r6.xxxx + r7.xyzw;
      r3.w = r5.x + r5.y;
      r3.w = r3.w + r5.z;
      r4.z = r5.w + -r5.x;
      r3.w = r4.z * r6.y + r3.w;
      r3.w = r3.w / 9;
      r4.z = max(r8.x, r8.y);
      r4.z = saturate(-r4.z * 16.0804024 + 8);
      r2.w = -r3.w + r2.w;
      r2.w = r4.z * r2.w + r3.w;
    } else {
      r2.w = 0;
    }
    r0.w = saturate(sShadowReceiveParam0.fShadowFaceIncreaseAttn * r0.w);
    r0.w = 1 + -r0.w;
    r1.w = max(r0.w, r2.w);
  }
  r0.w = sShadowReceiveParam0.fShadowRange.w * v0.w;
  r0.w = cmp(r0.w < sShadowReceiveParam0.fShadowNearPlane);
  r2.w = v0.w * sShadowReceiveParam0.fShadowRange.w + -1;
  r2.w = saturate(-5 * r2.w);
  r3.w = r2.w * -2 + 3;
  r2.w = r2.w * r2.w;
  r2.w = r2.w * r3.w;
  r0.w = r0.w ? 0 : r2.w;
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
  r1.xyz = r1.xxx * r0.xyz;
  r2.xyzw = tAlbedoMap.Sample(SSAlbedoMap_s, v6.xy);
  r0.xyz = fAlbedoColor.xyz * r2.xyz;
  r2.x = v1.w * r2.w;
  r2.y = fTransparency * r2.x;
  r6.xyz = fLightMapScale.xyz * v1.xyz;
  r1.w = 1;
  r7.x = dot(fSHCoef[0].xyzw, r1.xyzw);
  r7.y = dot(fSHCoef[1].xyzw, r1.xyzw);
  r7.z = dot(fSHCoef[2].xyzw, r1.xyzw);
  r8.xyzw = r1.xyzz * r1.yzzx;
  r9.x = dot(fSHCoef[3].xyzw, r8.xyzw);
  r9.y = dot(fSHCoef[4].xyzw, r8.xyzw);
  r9.z = dot(fSHCoef[5].xyzw, r8.xyzw);
  r1.w = r1.y * r1.y;
  r1.w = r1.x * r1.x + -r1.w;
  r7.xyz = r9.xyz + r7.xyz;
  r7.xyz = fSHCoef[6].xyz * r1.www + r7.xyz;
  r6.xyz = fDiffuseColor.xyz * r6.xyz;
  r1.w = -1 + v2.w;
  r1.w = r1.w * 0.5 + 1;
  r6.xyz = r6.xyz * r1.www + r7.xyz;
  r0.w = fShadowColor.w * r0.w;
  r7.xyz = fShadowColor.xyz + -r6.xyz;
  r6.xyz = r0.www * r7.xyz + r6.xyz;
  r4.xy = r4.xy * fScreenUVScale.xy + fScreenUVOffset.xy;
  r5.xy = float2(-0.498039216,-0.498039216) + r5.xy;
  r5.xy = fNormalWrap * r5.xy;
  r5.xy = float2(0.00249999994,0.00249999994) * r5.xy;
  r0.w = -r2.x * fTransparency + 1;
  r4.xy = -r5.xy * r0.ww + r4.xy;
  r4.xyzw = tDistortionMap.Sample(SSLinear_s, r4.xy);
  r4.xyz = fHDRCompressDecode * r4.xyz;
  r0.xyz = r6.xyz * r0.xyz + -r4.xyz;
  r0.xyz = r2.yyy * r0.xyz + r4.xyz;
  r0.w = fDiffuseColor.y * 2 + -1;
  r1.x = dot(-r3.xyz, r1.xyz);
  r1.x = max(0, r1.x);
  r0.w = r1.x + r0.w;
  r0.w = min(1, r0.w);
  o0.w = fGlobalTransparency * r0.w;
  o0.xyz = fHDRCompressEncode * r0.xyz;
  o0.w = saturate(o0.w);
  return;
}