// Specular hit distance for DLSS Ray Reconstruction, built from the NRD PreBlur inputs.
// Custom named shader (not a 0xHASH replacement).

Texture2D<float4> t0 : register(t0); // PreBlur t2: trace radiance, w = normalized hit distance
Texture2D<float> t1 : register(t1); // PreBlur t1: view-space Z (R16F)
Texture2D<float4> t2 : register(t2); // PreBlur t0: normal + roughness, w = roughness

RWTexture2D<float> u0 : register(u0); // specular hit distance out (R16F)

cbuffer HitDistParams : register(b0)
{
  // gSpecHitDistParams: x, y, z = scale terms (roughness-weighted blend), w = roughness exponent
  float4 hitDistParams;
  // x = width, y = height, z = checkerboard (1 when the trace is half width), w = gInf (max valid view Z)
  float4 guideSize;
}

[numthreads(8, 8, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
  uint2 px = id.xy;
  if (px.x >= (uint)guideSize.x || px.y >= (uint)guideSize.y) return;

  int sx = (guideSize.z != 0.0 ? (int)(px.x >> 1) : (int)px.x);
  float4 trace = t0.Load(int3(sx, px.y, 0));
  float viewZ = abs(t1.Load(int3(px, 0)));

  float hitDistance = 0.0;
  if (viewZ <= guideSize.w && trace.w > 0.0)
  {
    float roughness = t2.Load(int3(px, 0)).w;
    float blend = lerp(1.0, hitDistParams.z, saturate(exp2(hitDistParams.w * roughness * roughness)));
    hitDistance = trace.w * (hitDistParams.x + viewZ * hitDistParams.y) * blend;
  }
  u0[px] = hitDistance;
}
