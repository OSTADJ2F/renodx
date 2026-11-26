#include "./shared.h"
#include "./effects_hdr.hlsli"


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

cbuffer CBROPTest : register(b2)
{
  float fAlphaRef : packoffset(c0);
  float fStencilRef : packoffset(c0.y);
  float fDepthBias : packoffset(c0.z);
  float fAlphaToCoverageScale : packoffset(c0.w);
  float fGlobalTransparency : packoffset(c1);
}

cbuffer CBViewProjection : register(b3)
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

cbuffer CBMaterial : register(b4)
{
  float3 fDiffuseColor : packoffset(c0);
  float fTransparency : packoffset(c0.w);
  float3 fReflectiveColor : packoffset(c1);
  float fTransparencyVolume : packoffset(c1.w);
  row_major float2x4 fUVTransform : packoffset(c2);
  row_major float2x4 fUVTransform2 : packoffset(c4);
  row_major float2x4 fUVTransform3 : packoffset(c6);
}

cbuffer CBDynamicLighting : register(b5)
{

  struct
  {
    float3 fLightPos;
    float fLightMask0;
    float3 fLightDir;
    float fLightMask1;
    float3 fLightColor;
    float fLightBalance;
    float4 fAttenuation;
    float4 fAttenuation2;
    row_major float3x4 fLightRangeMat;
    row_major float4x4 fLightProjMat;
  } sLightParam0 : packoffset(c0);


  struct
  {
    float3 fLightPos;
    float fLightMask0;
    float3 fLightDir;
    float fLightMask1;
    float3 fLightColor;
    float fLightBalance;
    float4 fAttenuation;
    float4 fAttenuation2;
    row_major float3x4 fLightRangeMat;
    row_major float4x4 fLightProjMat;
  } sLightParam1 : packoffset(c12);


  struct
  {
    float3 fLightPos;
    float fLightMask0;
    float3 fLightDir;
    float fLightMask1;
    float3 fLightColor;
    float fLightBalance;
    float4 fAttenuation;
    float4 fAttenuation2;
    row_major float3x4 fLightRangeMat;
    row_major float4x4 fLightProjMat;
  } sLightParam2 : packoffset(c24);


  struct
  {
    float3 fLightPos;
    float fLightMask0;
    float3 fLightDir;
    float fLightMask1;
    float3 fLightColor;
    float fLightBalance;
    float4 fAttenuation;
    float4 fAttenuation2;
    row_major float3x4 fLightRangeMat;
    row_major float4x4 fLightProjMat;
  } sLightParam3 : packoffset(c36);


  struct
  {
    float3 fLightPos;
    float fLightMask0;
    float3 fLightDir;
    float fLightMask1;
    float3 fLightColor;
    float fLightBalance;
    float4 fAttenuation;
    float4 fAttenuation2;
    row_major float3x4 fLightRangeMat;
    row_major float4x4 fLightProjMat;
  } sLightParam4 : packoffset(c48);


  struct
  {
    float3 fLightPos;
    float fLightMask0;
    float3 fLightDir;
    float fLightMask1;
    float3 fLightColor;
    float fLightBalance;
    float4 fAttenuation;
    float4 fAttenuation2;
    row_major float3x4 fLightRangeMat;
    row_major float4x4 fLightProjMat;
  } sLightParam5 : packoffset(c60);


  struct
  {
    float3 fLightPos;
    float fLightMask0;
    float3 fLightDir;
    float fLightMask1;
    float3 fLightColor;
    float fLightBalance;
    float4 fAttenuation;
    float4 fAttenuation2;
    row_major float3x4 fLightRangeMat;
    row_major float4x4 fLightProjMat;
  } sLightParam6 : packoffset(c72);


  struct
  {
    float3 fLightPos;
    float fLightMask0;
    float3 fLightDir;
    float fLightMask1;
    float3 fLightColor;
    float fLightBalance;
    float4 fAttenuation;
    float4 fAttenuation2;
    row_major float3x4 fLightRangeMat;
    row_major float4x4 fLightProjMat;
  } sLightParam7 : packoffset(c84);

}

cbuffer CBAmbient : register(b6)
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

cbuffer CBCustomOcclusion : register(b7)
{
  float fShadowLightPowerI : packoffset(c0);
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

SamplerState SSNormalMap_s : register(s0);
SamplerState SSAlbedoMap_s : register(s1);
SamplerState SSEnvMap_s : register(s2);
SamplerState SSSpecularMap_s : register(s3);
Texture2D<float4> tNormalMap : register(t0);
Texture2D<float4> tAlbedoMap : register(t1);
TextureCube<float4> tGlobalEnvMap : register(t2);
Texture2D<float4> tSpecularMap : register(t3);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  float4 v3 : TEXCOORD2,
  float4 v4 : TEXCOORD3,
  float4 v5 : TEXCOORD4,
  uint v6 : SV_IsFrontFace0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1,r2,r3,r4,r5;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyz = sLightParam1.fLightPos.xyz + -v2.xyz;
  r0.w = dot(r0.xyz, r0.xyz);
  r1.x = sqrt(r0.w);
  r0.w = rsqrt(r0.w);
  r1.x = -sLightParam1.fAttenuation.x + r1.x;
  r1.x = saturate(sLightParam1.fAttenuation.y * r1.x);
  r1.x = 1 + -r1.x;
  r1.xyz = sLightParam1.fLightColor.xyz * r1.xxx;
  r0.xyz = r0.www * r0.xyz;
  r2.xyz = v6.xxx ? v1.xyz : -v1.xyz;
  r0.w = dot(r2.xyz, r2.xyz);
  r0.w = sqrt(r0.w);
  r0.w = max(9.99999997e-007, r0.w);
  r2.xyz = r2.xyz / r0.www;
  r0.w = dot(v3.xyz, v3.xyz);
  r0.w = sqrt(r0.w);
  r0.w = max(9.99999997e-007, r0.w);
  r3.xyz = v3.xyz / r0.www;
  r0.w = dot(v4.xyz, v4.xyz);
  r0.w = sqrt(r0.w);
  r0.w = max(9.99999997e-007, r0.w);
  r4.xyz = v4.xyz / r0.www;
  r5.xyzw = tNormalMap.Sample(SSNormalMap_s, v5.xy);
  r0.w = -0.498039216 + r5.y;
  r1.w = -0.498039216 + r5.x;
  r0.w = r0.w + r0.w;
  r4.xyz = r0.www * r4.xyz;
  r4.xyz = fNormalMapFlip * r4.xyz;
  r1.w = r1.w + r1.w;
  r3.xyz = r3.xyz * r1.www + r4.xyz;
  r1.w = -r1.w * r1.w + 1;
  r0.w = -r0.w * r0.w + r1.w;
  r0.w = max(9.99999975e-005, r0.w);
  r0.w = sqrt(r0.w);
  r2.xyz = r2.xyz * r0.www + r3.xyz;
  r0.w = dot(r2.xyz, r2.xyz);
  r0.w = rsqrt(r0.w);
  r2.xyz = r0.www * r2.xyz;
  r0.x = dot(r2.xyz, r0.xyz);
  r0.x = max(0, r0.x);
  r0.xyz = r0.xxx * r1.xyz;
  r1.xyz = sLightParam0.fLightPos.xyz + -v2.xyz;
  r0.w = dot(r1.xyz, r1.xyz);
  r1.w = sqrt(r0.w);
  r0.w = rsqrt(r0.w);
  r1.w = -sLightParam0.fAttenuation.x + r1.w;
  r1.w = saturate(sLightParam0.fAttenuation.y * r1.w);
  r1.w = 1 + -r1.w;
  r3.xyz = sLightParam0.fLightColor.xyz * r1.www;
  r1.xyz = r0.www * r1.xyz;
  r0.w = dot(r2.xyz, r1.xyz);
  r0.w = max(0, r0.w);
  r0.xyz = r3.xyz * r0.www + r0.xyz;
  r1.xyz = sLightParam2.fLightPos.xyz + -v2.xyz;
  r0.w = dot(r1.xyz, r1.xyz);
  r1.w = sqrt(r0.w);
  r0.w = rsqrt(r0.w);
  r1.w = -sLightParam2.fAttenuation.x + r1.w;
  r1.w = saturate(sLightParam2.fAttenuation.y * r1.w);
  r1.w = 1 + -r1.w;
  r3.xyz = sLightParam2.fLightColor.xyz * r1.www;
  r1.xyz = r0.www * r1.xyz;
  r0.w = dot(r2.xyz, r1.xyz);
  r0.w = max(0, r0.w);
  r0.xyz = r3.xyz * r0.www + r0.xyz;
  r1.xyz = sLightParam3.fLightPos.xyz + -v2.xyz;
  r0.w = dot(r1.xyz, r1.xyz);
  r1.w = sqrt(r0.w);
  r0.w = rsqrt(r0.w);
  r1.w = -sLightParam3.fAttenuation.x + r1.w;
  r1.w = saturate(sLightParam3.fAttenuation.y * r1.w);
  r1.w = 1 + -r1.w;
  r3.xyz = sLightParam3.fLightColor.xyz * r1.www;
  r1.xyz = r0.www * r1.xyz;
  r0.w = dot(r2.xyz, r1.xyz);
  r0.w = max(0, r0.w);
  r0.xyz = r3.xyz * r0.www + r0.xyz;
  r1.xyz = sLightParam4.fLightPos.xyz + -v2.xyz;
  r0.w = dot(r1.xyz, r1.xyz);
  r1.w = sqrt(r0.w);
  r0.w = rsqrt(r0.w);
  r1.w = -sLightParam4.fAttenuation.x + r1.w;
  r1.w = saturate(sLightParam4.fAttenuation.y * r1.w);
  r1.w = 1 + -r1.w;
  r3.xyz = sLightParam4.fLightColor.xyz * r1.www;
  r1.xyz = r0.www * r1.xyz;
  r0.w = dot(r2.xyz, r1.xyz);
  r0.w = max(0, r0.w);
  r0.xyz = r3.xyz * r0.www + r0.xyz;
  r1.xyz = sLightParam5.fLightPos.xyz + -v2.xyz;
  r0.w = dot(r1.xyz, r1.xyz);
  r1.w = sqrt(r0.w);
  r0.w = rsqrt(r0.w);
  r1.w = -sLightParam5.fAttenuation.x + r1.w;
  r1.w = saturate(sLightParam5.fAttenuation.y * r1.w);
  r1.w = 1 + -r1.w;
  r3.xyz = sLightParam5.fLightColor.xyz * r1.www;
  r1.xyz = r0.www * r1.xyz;
  r0.w = dot(r2.xyz, r1.xyz);
  r0.w = max(0, r0.w);
  r0.xyz = r3.xyz * r0.www + r0.xyz;
  r2.w = 1;
  r1.x = dot(fSHCoef[0].xyzw, r2.xyzw);
  r1.y = dot(fSHCoef[1].xyzw, r2.xyzw);
  r1.z = dot(fSHCoef[2].xyzw, r2.xyzw);
  r3.xyzw = r2.xyzz * r2.yzzx;
  r4.x = dot(fSHCoef[3].xyzw, r3.xyzw);
  r4.y = dot(fSHCoef[4].xyzw, r3.xyzw);
  r4.z = dot(fSHCoef[5].xyzw, r3.xyzw);
  r1.xyz = r4.xyz + r1.xyz;
  r0.w = r2.y * r2.y;
  r0.w = r2.x * r2.x + -r0.w;
  r1.xyz = fSHCoef[6].xyz * r0.www + r1.xyz;
  r0.xyz = r0.xyz * v1.www + r1.xyz;
  r0.xyz = fAmbientColor.xyz + r0.xyz;
  r0.xyz = fDiffuseColor.xyz * r0.xyz;
  r0.xyz = fShadowLightPowerI * r0.xyz;
  r1.xyz = -fCameraPos.xyz + v2.xyz;
  r0.w = dot(r1.xyz, r1.xyz);
  r0.w = rsqrt(r0.w);
  r1.xyz = r0.www * r1.xyz;
  r0.w = dot(r1.xyz, r2.xyz);
  r1.w = r0.w + r0.w;
  r0.w = 1 + -r0.w;
  r1.xyz = r2.xyz * -r1.www + r1.xyz;
  r1.xyzw = tGlobalEnvMap.SampleLevel(SSEnvMap_s, r1.xyz, fEnvMapBias);
  r1.xyz = fReflectiveColor.xyz * r1.xyz;
  r1.xyz = fEnvMapPower * r1.xyz;
  r2.xyzw = tSpecularMap.Sample(SSSpecularMap_s, v5.xy);
  r1.xyz = r2.xxx * r1.xyz;
  r1.xyz = v1.www * r1.xyz;
  r1.w = r0.w * r0.w;
  r1.w = r1.w * r1.w;
  r0.w = r1.w * r0.w;
  r0.w = saturate(fFresnelSchlick * r0.w + fFresnelBias);
  r0.w = 1 + -r0.w;
  r1.xyz = r0.www * r1.xyz;
  r2.xyzw = tAlbedoMap.Sample(SSAlbedoMap_s, v5.xy);
  r2.xyz = fAlbedoColor.xyz * r2.xyz;
  r0.xyz = r2.xyz * r0.xyz + r1.xyz;
  r1.xyz = fFogHColor.xyz + -r0.xyz;
  r2.xyz = fFogColor.xyz;
  r2.w = fFogHUVScale;
  r3.xyz = v2.xyz;
  r3.w = 1;
  r0.w = dot(r2.xyzw, r3.xyzw);
  r0.w = fFogHSlopeBias * r0.w;
  r2.xyz = fCameraPos.xyz + -v2.xyz;
  r1.w = dot(r2.xyz, r2.xyz);
  r1.w = sqrt(r1.w);
  r1.w = -fFogHStart + r1.w;
  r1.w = fFogHInvRange * r1.w;
  r0.w = max(r1.w, r0.w);
  r0.w = min(fFogHDensity, r0.w);
  r0.w = max(0, r0.w);
  r0.xyz = r0.www * r1.xyz + r0.xyz;
  r0.w = fGlobalTransparency;
  r0.xyz = ClampVertexColorHDR(r0.xyz);
  r0.w = min(1, r0.w);
  o0.xyz = fHDRCompressEncode * r0.xyz;
  o0.w = r0.w;
  return;
}