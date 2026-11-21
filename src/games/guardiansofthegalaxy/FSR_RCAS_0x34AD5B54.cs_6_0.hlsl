#include "./shared.h"

Texture2D<float4> InputTexture : register(t0);

RWTexture2D<float4> OutputTexture : register(u0);

cbuffer _FSR_root : register(b0) {
  uint4 Const0 : packoffset(c000.x);
  uint4 Const1 : packoffset(c001.x);
  uint4 Const2 : packoffset(c002.x);
  uint4 Const3 : packoffset(c003.x);
  uint4 Sample : packoffset(c004.x);
};

// Passthrough: sharpening now runs in ApplyDisplayMapping.
float4 PassthroughTexel(int2 p) {
  return float4(InputTexture.Load(int3(p, 0)).rgb, 1.f);
}

[numthreads(64, 1, 1)]
void main(
  uint3 SV_DispatchThreadID : SV_DispatchThreadID,
  uint3 SV_GroupID : SV_GroupID,
  uint3 SV_GroupThreadID : SV_GroupThreadID,
  uint SV_GroupIndex : SV_GroupIndex
) {
  int _15 = (((uint)(SV_GroupThreadID.x) >> 1) & 7) | ((uint)((uint)(SV_GroupID.x) << 4));
  int _16 = ((((uint)(SV_GroupThreadID.x) >> 3) & 6) | ((uint)(SV_GroupThreadID.x) & 1)) | ((uint)((uint)(SV_GroupID.y) << 4));
  int _160 = _15 | 8;
  int _298 = _16 | 8;

  OutputTexture[int2(_15, _16)] = PassthroughTexel(int2(_15, _16));
  OutputTexture[int2(_160, _16)] = PassthroughTexel(int2(_160, _16));
  OutputTexture[int2(_15, _298)] = PassthroughTexel(int2(_15, _298));
  OutputTexture[int2(_160, _298)] = PassthroughTexel(int2(_160, _298));
}
