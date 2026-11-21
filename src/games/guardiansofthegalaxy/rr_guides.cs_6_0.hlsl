// DLSS Ray Reconstruction guide buffer builder for Guardians of the Galaxy.
// Custom named shader (not a 0xHASH replacement).

Texture2D<float4> t0 : register(t0); // NRD normal + roughness (RGBA8 unorm, n*0.5+0.5)
Texture2D<float4> t1 : register(t1); // G-buffer normal (octahedral 12-bit, view space)
Texture2D<float4> t2 : register(t2); // base colour (sRGB view, linear on load)
Texture2D<float4> t3 : register(t3); // material: x = metalness, y = roughness

RWTexture2D<float4> u0 : register(u0); // normal + roughness out
RWTexture2D<float4> u1 : register(u1); // diffuse albedo out
RWTexture2D<float4> u2 : register(u2); // specular albedo out

cbuffer RRGuideParams : register(b0)
{
  // x = width, y = height, z and w = unused
  float4 params;
  // x = non-metal roughness reduction, y = metal roughness reduction (the game's values, or the slider's)
  float4 smoothing;
  // x = view-space x/z per NDC x (m[11] / m[0] of view-to-clip), y = view-space y/z per NDC y (m[11] / m[5]); 0 until seen
  float4 view_scale;
}

[numthreads(8, 8, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
  if (id.x >= (uint)params.x || id.y >= (uint)params.y) return;

  int3 pos = int3(id.xy, 0);

  // World-space normal from NRD.
  float3 nw = t0.Load(pos).xyz * 2.0 - 1.0;
  nw = dot(nw, nw) > 1e-6 ? normalize(nw) : float3(0, 0, 1);

  // Same roughness reduction as GenerateNRDBuffers: metalness selects between the non-metal and metal fractions.
  float metal_flag = t3.Load(pos).x;
  float rough = max(t3.Load(pos).y, 0.01) * ((1.0 - smoothing.x) - metal_flag * (smoothing.y - smoothing.x));
  float metal = saturate(metal_flag);
  float3 base = t2.Load(pos).rgb;

  float3 diffuse = base * (1.0 - metal);
  float3 F0 = lerp(0.04.xxx, base, metal);

  // Decode view-space octahedral normal from t1.
  float3 g1 = t1.Load(pos).xyz;
  float u = clamp((floor(15.9375 * g1.y) + 4080.0 * g1.x) / 2047.0 - 1.0, -1.0, 1.0);
  float v = clamp((frac(15.9375 * g1.y) * 4096.0 + 255.0 * g1.z) / 2047.0 - 1.0, -1.0, 1.0);
  float z = 1.0 - abs(u) - abs(v);
  if (z < 0.0)
  {
    float2 o = (1.0 - abs(float2(v, u))) * float2(u >= 0.0 ? 1.0 : -1.0, v >= 0.0 ? 1.0 : -1.0);
    u = o.x;
    v = o.y;
  }
  float3 nv = normalize(float3(u, v, z));

  // View direction through this pixel centre, from the projection scale.
  float2 ndc = float2((id.x + 0.5) / params.x * 2.0 - 1.0, 1.0 - (id.y + 0.5) / params.y * 2.0);
  float3 view_dir = normalize(float3(ndc.x * view_scale.x, ndc.y * view_scale.y, 1.0));
  float NoV = abs(dot(nv, view_dir));

  // Specular albedo: NVIDIA EnvBRDFApprox2.
  float alpha = rough * rough;
  float4 X = float4(1.0, NoV, NoV * NoV, NoV * NoV * NoV);
  float4 Y = float4(1.0, alpha, alpha * alpha, alpha * alpha * alpha);
  float2x2 M1 = float2x2(0.99044, -1.28514, 1.29678, -0.755907);
  float3x3 M2 = float3x3(1.0, 2.92338, 59.4188, 20.3225, -27.0302, 222.592, 121.563, 626.13, 316.627);
  float2x2 M3 = float2x2(0.0365463, 3.32707, 9.0632, -9.04756);
  float3x3 M4 = float3x3(1.0, 3.59685, -1.36772, 9.04401, -16.3174, 9.22949, 5.56589, 19.7886, -20.2123);
  float bias = dot(mul(M1, X.xy), Y.xy) * rcp(dot(mul(M2, X.xyw), Y.xyw));
  float scale = dot(mul(M3, X.xy), Y.xy) * rcp(dot(mul(M4, X.xzw), Y.xyw));
  bias *= saturate(F0.g * 50.0);
  float3 spec = F0 * max(0.0, scale) + max(0.0, bias);

  u0[id.xy] = float4(nw, rough);
  u1[id.xy] = float4(diffuse, 1.0);
  u2[id.xy] = float4(spec, 1.0);
}
