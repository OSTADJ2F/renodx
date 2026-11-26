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

cbuffer CBLightMask : register(b6)
{
  float3 fLightMaskSelector : packoffset(c0);
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

cbuffer CBCustomOcclusion : register(b8)
{
  float fShadowLightPowerI : packoffset(c0);
}

cbuffer CBAppReflect : register(b9)
{
  float fEnvMapPower : packoffset(c0);
  float fEnvMapBias : packoffset(c0.y);
}

cbuffer CBFresnelSchlick : register(b10)
{
  float fFresnelBias : packoffset(c0);
}

cbuffer CBFog : register(b11)
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

SamplerState SSPoint_s : register(s0);
SamplerState SSAlbedoMap_s : register(s1);
SamplerState SSLightMap_s : register(s2);
SamplerState SSEnvMap_s : register(s3);
SamplerState SSSpecularMap_s : register(s4);
Texture2D<float4> tLightMaskMap : register(t0);
Texture2D<float4> tAlbedoMap : register(t1);
Texture2D<float4> tLightMap : register(t2);
TextureCube<float4> tGlobalEnvMap : register(t3);
Texture2D<float4> tSpecularMap : register(t4);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  float4 v3 : TEXCOORD2,
  float4 v4 : TEXCOORD3,
  uint v5 : SV_IsFrontFace0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1,r2,r3,r4;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyz = v5.xxx ? v1.xyz : -v1.xyz;
  r0.w = dot(r0.xyz, r0.xyz);
  r0.w = sqrt(r0.w);
  r0.w = max(9.99999997e-007, r0.w);
  r0.xyz = r0.xyz / r0.www;
  r1.xyz = -fCameraPos.xyz + v2.xyz;
  r0.w = dot(r1.xyz, r1.xyz);
  r0.w = rsqrt(r0.w);
  r1.xyz = r0.www * r1.xyz;
  r0.w = dot(r1.xyz, r0.xyz);
  r1.w = r0.w + r0.w;
  r0.w = 1 + -r0.w;
  r0.xyz = r0.xyz * -r1.www + r1.xyz;
  r1.xyzw = tGlobalEnvMap.SampleLevel(SSEnvMap_s, r0.xyz, fEnvMapBias);
  r0.xyz = fReflectiveColor.xyz * r1.xyz;
  r0.xyz = fEnvMapPower * r0.xyz;
  r1.xy = fScreenInverseSize.xy * v0.xy;
  r1.xyzw = tLightMaskMap.Sample(SSPoint_s, r1.xy);
  r1.xyzw = max(fLightMask.xyxy, r1.zwxy);
  r1.xyzw = fLightMaskSelector.xyxy * r1.xyzw;
  r2.x = cmp(0 < fLightMaskSelector.z);
  r1.xy = r2.xx ? r1.zw : r1.xy;
  r1.x = max(r1.x, r1.y);
  r1.y = fEnvMapMask * -r1.x + 1;
  r1.x = fShadowColor.w * r1.x;
  r0.xyz = r1.yyy * r0.xyz;
  r2.xyzw = tSpecularMap.Sample(SSSpecularMap_s, v3.xy);
  r0.xyz = r2.xxx * r0.xyz;
  r0.xyz = v1.www * r0.xyz;
  r1.y = r0.w * r0.w;
  r1.y = r1.y * r1.y;
  r0.w = r1.y * r0.w;
  r0.w = saturate(fFresnelSchlick * r0.w + fFresnelBias);
  r0.w = 1 + -r0.w;
  r0.xyz = r0.www * r0.xyz;
  r2.xyzw = tLightMap.Sample(SSLightMap_s, v4.xy);
  r2.xyz = fLightMapScale.xyz * r2.xyz;
  r0.w = -1 + v1.w;
  r0.w = r0.w * 0.5 + 1;
  r3.xyz = r0.www * r2.xyz;
  r2.xyz = -r2.xyz * r0.www + fShadowColor.xyz;
  r1.xyz = r1.xxx * r2.xyz + r3.xyz;
  r1.xyz = fShadowLightPowerI * r1.xyz;
  r2.xyzw = tAlbedoMap.Sample(SSAlbedoMap_s, v3.xy);
  r2.xyz = fAlbedoColor.xyz * r2.xyz;
  r0.xyz = r2.xyz * r1.xyz + r0.xyz;
  r1.xyz = fFogDiffuseBlend * r1.xyz;
  r0.w = -fFogStart + v0.w;
  r0.w = saturate(fFogInvRange * r0.w);
  r1.w = -r0.w * fFogDensity + 1;
  r0.w = fFogDensity * r0.w;
  r2.x = -fFogHStart + v2.y;
  r2.x = saturate(fFogHInvRange * r2.x);
  r2.y = -r2.x * fFogHDensity + 1;
  r2.x = fFogHDensity * r2.x;
  r1.xyz = r1.www * r2.yyy + r1.xyz;
  r1.xyz = ClampVertexColorHDR(r1.xyz);
  r3.xyz = fFogColor.xyz * r0.www;
  r4.xyz = fFogHColor.xyz * r2.xxx;
  r2.xyz = r3.xyz * r2.yyy + r4.xyz;
  r0.xyz = r0.xyz * r1.xyz + r2.xyz;
  o0.xyz = fHDRCompressEncode * r0.xyz;
  o0.w = fGlobalTransparency;
  return;
}