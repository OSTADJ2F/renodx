#include "./shared.h"

cbuffer CBHSVFilter : register(b0)
{
  float4 fShiftHSV : packoffset(c0);
}

SamplerState SSPoint_s : register(s0);
Texture2D<float4> tFilterPoint0 : register(t0);

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 c = tFilterPoint0.Sample(SSPoint_s, v1.xy);
  // RenoDX: in HDR, run the HSV math on rgb/scale (0-1) and multiply the result back by scale.
  float scale = 1.f;
  if (RENODX_PEAK_WHITE_NITS == 0 || RENODX_TONE_MAP_TYPE == 0) {
    c.xyz = saturate(c.xyz);
  } else {
    scale = max(max(c.x, max(c.z, c.y)), 1.f);
    c.xyz = saturate(c.xyz / scale);
  }

  float mx = max(c.x, max(c.z, c.y));
  float mn = min(c.x, min(c.z, c.y));
  float d = mx - mn;
  float s = mx != 0 ? d / mx : 0;
  float h;
  [branch] if (s == 0) {
    h = 0;
  } else {
    float hr = (c.y - c.z) / d;
    float hg = (c.z - c.x) / d + 2;
    float hb = (c.x - c.y) / d + 4;
    float hh0 = c.y == mx ? hg : hb;
    hh0 = c.x == mx ? hr : hh0;
    hh0 = hh0 / 6.0;
    h = hh0 < 0 ? hh0 + 1 : hh0;
  }
  float2 hs = saturate(float2(h, s));
  float3 hvs = float3(hs.x, mx, hs.y) + float3(fShiftHSV.x, fShiftHSV.z, fShiftHSV.y);
  float hue = hvs.x >= 1 ? hvs.x - 1 : hvs.x;
  float sat = saturate(hvs.z);
  float val = saturate(hvs.y);
  float sector = floor(hue * 6);
  float f = hue * 6 - sector;
  float p = val * (1 - sat);
  float t = val * (1 - sat * (1 - f));
  [branch] if (sector - 1 < 0) {
    c.xyz = float3(val, t, p);
  } else {
    float q = val * (1 - sat * f);
    [branch] if (sector - 2 < 0) {
      c.xyz = float3(q, val, p);
    } else {
      float3 s2 = float3(p, val, t);
      float3 s3 = float3(p, q, val);
      float3 s4 = float3(t, p, val);
      float3 s5 = float3(val, p, q);
      float3 r = sector < 5 ? s4 : s5;
      r = sector < 4 ? s3 : r;
      c.xyz = sector < 3 ? s2 : r;
    }
  }
  c.xyz *= scale;
  o0 = c;
}
