// White noise refill for the ray-tracing noise texture (64x64x64 r16g16_unorm) in Guardians of the Galaxy.
// Custom named shader (not a 0xHASH replacement).

RWTexture3D<float2> u0 : register(u0); // two independent uniform values per texel

cbuffer RTNoiseParams : register(b0)
{
  // x = frame seed, stored as the bit pattern of a uint counter. The rest is unused.
  float4 params;
}

// PCG3D hash (Jarzynski and Olano, 2020).
uint3 Pcg3d(uint3 v)
{
  v = v * 1664525u + 1013904223u;
  v.x += v.y * v.z;
  v.y += v.z * v.x;
  v.z += v.x * v.y;
  v ^= v >> 16u;
  v.x += v.y * v.z;
  v.y += v.z * v.x;
  v.z += v.x * v.y;
  return v;
}

[numthreads(4, 4, 4)]
void main(uint3 id : SV_DispatchThreadID)
{
  uint seed = asuint(params.x);
  uint3 h = Pcg3d(id ^ seed);
  // High 16 bits of x and y are independent; the texture is unorm so they map to [0, 1].
  float2 uniform_pair = float2(h.xy >> 16u) * (1.0 / 65535.0);
  u0[id] = uniform_pair;
}
