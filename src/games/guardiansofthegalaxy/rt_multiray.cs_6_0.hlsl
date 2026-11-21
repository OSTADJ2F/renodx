// Averages the multi-ray trace samples before NRD PreBlur. Custom named shader (not a 0xHASH replacement).
// Averages the game's compressed values c = rgb / (dot(rgb, 1/3) + 0.5) directly, with no decode. This damps rays
// far brighter than the others at that pixel.

Texture2D<float4> t0 : register(t0); // sample 0
Texture2D<float4> t1 : register(t1); // sample 1 (padded with sample 0 when unused)
Texture2D<float4> t2 : register(t2); // sample 2 (padded with sample 0 when unused)

RWTexture2D<float4> u0 : register(u0); // output: last ray in, average out

cbuffer MultiRayParams : register(b0)
{
  // x = ray count, y = width, z = height, w = unused
  float4 rayParams;
}

[numthreads(8, 8, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
  uint2 px = id.xy;
  if (px.x >= (uint)rayParams.y || px.y >= (uint)rayParams.z) return;

  uint count = max((uint)rayParams.x, 1u);
  float4 samples[3] = {t0.Load(int3(px, 0)), t1.Load(int3(px, 0)), t2.Load(int3(px, 0))};
  float4 total = u0[px];
  for (uint i = 0; i + 1 < count; ++i)
  {
    total += samples[i];
  }

  u0[px] = total / (float)count;
}
