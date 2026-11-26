#include "./aa_luma.hlsli"

cbuffer CBScreen : register(b0)
{
  float2 fScreenOffset : packoffset(c0);
  float2 fScreenScale : packoffset(c0.z);
  float2 fScreenSize : packoffset(c1);
  float2 fScreenInverseSize : packoffset(c1.z);
  float2 fScreenHalfPixelOffset : packoffset(c2);
}

SamplerState SSLinear_s : register(s0);
Texture2D<float4> tBaseMap : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  // Luma lives in alpha; the edge tests use it saturated, the output stays unclamped.
  float4 sampleN = tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0, int2(0, -1));
  float4 sampleW = tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0, int2(-1, 0));
  float4 sampleM = tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0);
  float4 sampleE = tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0, int2(1, 0));
  float4 sampleS = tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0, int2(0, 1));
  float lumaN = AAEdgeValue(sampleN.w);
  float lumaW = AAEdgeValue(sampleW.w);
  float lumaM = AAEdgeValue(sampleM.w);
  float lumaE = AAEdgeValue(sampleE.w);
  float lumaS = AAEdgeValue(sampleS.w);

  float range = min(lumaM, min(min(lumaN, lumaW), min(lumaE, lumaS)));
  float lumaMax = max(lumaM, max(max(lumaN, lumaW), max(lumaE, lumaS)));
  range = lumaMax - range;

  if (range >= max(lumaMax * 0.166667, 0.083333)) {
    float lumaNW = AAEdgeValue(tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0, int2(-1, -1)).w);
    float lumaNE = AAEdgeValue(tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0, int2(1, -1)).w);
    float lumaSW = AAEdgeValue(tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0, int2(-1, 1)).w);
    float lumaSE = AAEdgeValue(tBaseMap.SampleLevel(SSLinear_s, v1.xy, 0, int2(1, 1)).w);

    float lumaAvg = (((lumaN + lumaW) + lumaE) + lumaS);
    float blend = min(saturate(abs(lumaAvg * 0.25 - lumaM) / range - 0.25) * 1.333333, 0.75);

    float edgeH = abs(((lumaN * -2.0 + lumaNW) + lumaNE)) + (abs((lumaM * -2.0 + lumaW) + lumaE) * 2.0);
    edgeH = edgeH + abs((lumaS * -2.0 + lumaSW) + lumaSE);
    float edgeV = abs((lumaM * -2.0 + lumaN) + lumaS) * 2.0 + abs((lumaW * -2.0 + lumaNW) + lumaSW);
    edgeV = edgeV + abs((lumaE * -2.0 + lumaNE) + lumaSE);
    bool isHorz = edgeV >= edgeH;

    float lengthSign = isHorz ? -fScreenInverseSize.y : -fScreenInverseSize.x;
    float luma1 = isHorz ? lumaN : lumaW;
    float luma2 = isHorz ? lumaS : lumaE;
    float grad1 = luma1 - lumaM;
    float grad2 = luma2 - lumaM;
    float avg1 = 0.5 * (luma1 + lumaM);
    float avg2 = 0.5 * (lumaM + luma2);
    bool is1Steepest = abs(grad1) >= abs(grad2);
    float gradientAvg = is1Steepest ? avg1 : avg2;
    float gradientScaled = is1Steepest ? abs(grad1) : abs(grad2);
    lengthSign = is1Steepest ? lengthSign : -lengthSign;

    float2 posOffset = float2(isHorz ? 0 : 0.5 * lengthSign, isHorz ? 0.5 * lengthSign : 0);
    float2 posB = v1.xy + posOffset;
    gradientScaled = 0.25 * gradientScaled;
    float2 off = isHorz ? float2(fScreenInverseSize.x, 0) : float2(0, fScreenInverseSize.y);
    float2 posN = posB - off * 1.5;
    float2 posP = posB + off * 1.5;

    float lumaEndN = 0;
    float lumaEndP = 0;
    float blueP = 0;
    bool doneN = false;
    bool doneP = false;
    for (int i = 0; i < 6; i++) {
      float4 endN = tBaseMap.SampleLevel(SSLinear_s, posN, 0);
      float4 endP = tBaseMap.SampleLevel(SSLinear_s, posP, 0);
      lumaEndN = AAEdgeValue(endN.w);
      lumaEndP = AAEdgeValue(endP.w);
      blueP = endP.z;  // the original asm reads this sample's .z after the loop
      bool newDoneN = abs(lumaEndN - gradientAvg) >= gradientScaled;
      bool newDoneP = abs(lumaEndP - gradientAvg) >= gradientScaled;
      float2 stepN = (newDoneN && !doneN) ? posN + off : posN;
      float2 stepP = (newDoneP && !doneP) ? posP - off : posP;
      if (newDoneN && newDoneP) {
        posN = stepN;
        posP = stepP;
        break;
      }
      posN = newDoneN ? stepN : (stepN - off * 2.0);
      posP = newDoneP ? stepP : (stepP + off * 2.0);
      doneN = newDoneN;
      doneP = newDoneP;
    }

    float dstN = isHorz ? (v1.x - posN.x) : (v1.y - posN.y);
    float dstP = isHorz ? (posP.x - v1.x) : (posP.y - v1.y);
    bool isDirN = dstN < dstP;
    float lumaEnd = isDirN ? lumaEndN : lumaEndP;
    bool centerSmaller = (lumaM - gradientAvg) < 0;
    bool endSmaller = (lumaEnd - gradientAvg) < 0;
    float offsetGood = ((int)centerSmaller == (int)endSmaller) ? 0 : blueP;
    float spanLength = dstP + dstN;
    float dstMin = isDirN ? dstN : dstP;
    float pixelOffset = dstMin * (-1.0 / spanLength) + 0.5;
    pixelOffset = blend * 0.125 + pixelOffset;
    offsetGood = pixelOffset * offsetGood;

    float2 posM = float2(v1.x + (isHorz ? 0 : offsetGood), v1.y + (isHorz ? offsetGood : 0));
    float4 result = tBaseMap.SampleLevel(SSLinear_s, posM, 0);
    float lumaResult = AAColorLuma(result.xyz) + 5.96046448e-8;
    float ratio = (blend * (lumaAvg * 0.25 - lumaResult) + lumaResult) / lumaResult;
    o0.xyz = result.xyz * min(4.0, ratio);
    o0.w = sampleM.w;
  } else {
    o0 = sampleM;
  }
}
