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

cbuffer CBCustomOcclusion : register(b4)
{
  float fShadowLightPowerI : packoffset(c0);
}

cbuffer CBFog : register(b5)
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

SamplerState SSAlbedoMap_s : register(s0);
SamplerState SSLightMap_s : register(s1);
Texture2D<float4> tAlbedoMap : register(t0);
Texture2D<float4> tLightMap : register(t1);


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
  float4 r0,r1,r2,r3;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = tLightMap.Sample(SSLightMap_s, v4.xy);
  r0.xyz = fLightMapScale.xyz * r0.xyz;
  r0.w = -1 + v1.w;
  r0.w = r0.w * 0.5 + 1;
  r0.xyz = r0.www * r0.xyz;
  r0.xyz = fShadowLightPowerI * r0.xyz;
  r1.xyzw = tAlbedoMap.Sample(SSAlbedoMap_s, v3.xy);
  r1.xyz = fAlbedoColor.xyz * r1.xyz;
  r1.xyz = r1.xyz * r0.xyz;
  r0.xyz = fFogDiffuseBlend * r0.xyz;
  r2.xyz = -fCameraPos.xyz + v2.xyz;
  r0.w = dot(r2.xyz, r2.xyz);
  r0.w = sqrt(r0.w);
  r0.w = -fFogStart + r0.w;
  r0.w = saturate(fFogInvRange * r0.w);
  r1.w = fFogDensity * r0.w;
  r0.w = -r0.w * fFogDensity + 1;
  r2.xyz = fFogColor.xyz * r1.www;
  r1.w = -fFogHStart + v2.y;
  r1.w = saturate(fFogHInvRange * r1.w);
  r2.w = fFogHDensity * r1.w;
  r1.w = -r1.w * fFogHDensity + 1;
  r3.xyz = fFogHColor.xyz * r2.www;
  r2.xyz = r2.xyz * r1.www + r3.xyz;
  r0.xyz = r0.www * r1.www + r0.xyz;
  r0.xyz = ClampVertexColorHDR(r0.xyz);
  r0.xyz = r1.xyz * r0.xyz + r2.xyz;
  o0.xyz = fHDRCompressEncode * r0.xyz;
  o0.w = fGlobalTransparency;
  return;
}