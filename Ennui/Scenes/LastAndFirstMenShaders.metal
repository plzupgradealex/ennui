// LastAndFirstMenShaders.metal
// Deferred PBR rendering pipeline for the Last and First Men 3D scene.
//
// Pass 1 — G-buffer geometry  : albedo+metalness | encoded-normal+roughness | worldPos+emissive
// Pass 2 — Deferred lighting  : Cook-Torrance BRDF (GGX NDF, Smith masking, Fresnel-Schlick)
// Pass 3 — Bloom threshold    : compute kernel, soft-knee threshold
// Pass 3b — Gaussian blur H/V : separable 9-tap Gaussian blur (compute)
// Pass 4 — Composite          : Reinhard tone-mapping + bloom additive blend + gamma

#include <metal_stdlib>
using namespace metal;

// ── Vertex layout: 10 packed floats, stride = 40 bytes ──────────────────────
struct LFMVertex {
    float px, py, pz;   // position  (offset  0, 12 bytes)
    float nx, ny, nz;   // normal    (offset 12, 12 bytes)
    float r,  g,  b, a; // color     (offset 24, 16 bytes)
};

// ── Per-draw uniforms (176 bytes) ────────────────────────────────────────────
struct LFMUniforms {
    float4x4 modelMatrix;   //  64 bytes
    float4x4 vpMatrix;      //  64 bytes
    float4   cameraPos;     //  16 bytes  (xyz=pos,    w=time)
    float4   emissive;      //  16 bytes  (xyz=color,  w=intensity)
    float4   material;      //  16 bytes  (x=metalness, y=roughness, z=isEmissive)
};

// ── Point light (32 bytes) ───────────────────────────────────────────────────
struct LFMLight {
    float4 position;    // xyz=world-pos, w=radius
    float4 color;       // xyz=color,     w=intensity
};

// ── Deferred lighting uniforms (224 bytes) ───────────────────────────────────
struct LFMDeferredUniforms {
    float4   cameraPos;         //  16 bytes
    LFMLight lights[6];         // 192 bytes
    int      lightCount;        //   4 bytes
    float    ambientIntensity;  //   4 bytes
    float2   _pad;              //   8 bytes
};

// ── G-Buffer: 3 render targets ───────────────────────────────────────────────
struct GBufferOut {
    float4 albedoMetal  [[color(0)]];  // rgb=albedo,         a=metalness
    float4 normalRough  [[color(1)]];  // rgb=normal*0.5+0.5, a=roughness
    float4 positionEmit [[color(2)]];  // rgb=worldPos,       a=emissive_intensity
};

// ── G-buffer geometry varyings ───────────────────────────────────────────────
struct GeomVaryings {
    float4 clipPos     [[position]];
    float3 worldPos;
    float3 worldNormal;
    float4 color;
};

// ── Full-screen quad varyings ────────────────────────────────────────────────
struct QuadVaryings {
    float4 clipPos [[position]];
    float2 uv;
};

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: G-Buffer Geometry Pass
// ═══════════════════════════════════════════════════════════════════════════════

vertex GeomVaryings lfm_geom_vertex(
    device const LFMVertex* verts [[buffer(0)]],
    constant LFMUniforms&   uni   [[buffer(1)]],
    uint vid                      [[vertex_id]])
{
    LFMVertex v = verts[vid];
    float4 wp4 = uni.modelMatrix * float4(v.px, v.py, v.pz, 1.0);

    // Upper-left 3×3 of model matrix — valid for uniform-scale objects;
    // for emissive geometry (rings, filaments, spokes) lighting accuracy is secondary.
    float3x3 mRot = float3x3(uni.modelMatrix[0].xyz,
                              uni.modelMatrix[1].xyz,
                              uni.modelMatrix[2].xyz);
    float3 wn = normalize(mRot * float3(v.nx, v.ny, v.nz));

    GeomVaryings out;
    out.clipPos     = uni.vpMatrix * wp4;
    out.worldPos    = wp4.xyz;
    out.worldNormal = wn;
    out.color       = float4(v.r, v.g, v.b, v.a);
    return out;
}

fragment GBufferOut lfm_geom_fragment(
    GeomVaryings          in  [[stage_in]],
    constant LFMUniforms& uni [[buffer(1)]])
{
    GBufferOut g;
    g.albedoMetal  = float4(in.color.rgb, uni.material.x);
    g.normalRough  = float4(in.worldNormal * 0.5 + 0.5, uni.material.y);
    float emitInt  = (uni.material.z > 0.5) ? uni.emissive.w : 0.0;
    g.positionEmit = float4(in.worldPos, emitInt);
    return g;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: Full-Screen Triangle (no vertex buffer required)
// ═══════════════════════════════════════════════════════════════════════════════

vertex QuadVaryings lfm_quad_vertex(uint vid [[vertex_id]])
{
    // Three vertices forming a triangle that covers the entire [-1,1]² NDC region.
    // UV (0,0) = top-left, matching Metal texture coordinate convention.
    const float2 pos[3] = { float2(-1.0, 1.0), float2(3.0, 1.0), float2(-1.0, -3.0) };
    const float2 uvs[3] = { float2( 0.0, 0.0), float2(2.0, 0.0), float2( 0.0,  2.0) };
    QuadVaryings out;
    out.clipPos = float4(pos[vid], 0.0, 1.0);
    out.uv      = uvs[vid];
    return out;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: Cook-Torrance PBR Helper Functions
// ═══════════════════════════════════════════════════════════════════════════════

// GGX / Trowbridge-Reitz Normal Distribution Function
static float ggxNDF(float NdotH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float d  = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (M_PI_F * d * d + 1e-6);  // epsilon guards denominator from zero
}

// Smith-GGX Geometry Masking-Shadowing
static float smithGGX(float NdotV, float NdotL, float roughness)
{
    float r = roughness + 1.0;
    float k = (r * r) * 0.125;          // Disney remapping
    float gv = NdotV / (NdotV * (1.0 - k) + k);
    float gl = NdotL / (NdotL * (1.0 - k) + k);
    return gv * gl;
}

// Fresnel-Schlick Approximation
static float3 fresnelSchlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: Deferred Lighting Pass — Cook-Torrance BRDF
// ═══════════════════════════════════════════════════════════════════════════════

fragment float4 lfm_deferred_lighting(
    QuadVaryings                  in           [[stage_in]],
    texture2d<float>              gAlbedoMetal [[texture(0)]],
    texture2d<float>              gNormalRough [[texture(1)]],
    texture2d<float>              gPosEmit     [[texture(2)]],
    constant LFMDeferredUniforms& uni          [[buffer(0)]])
{
    constexpr sampler s(filter::nearest, address::clamp_to_edge);
    float4 am  = gAlbedoMetal.sample(s, in.uv);
    float4 nr  = gNormalRough.sample(s, in.uv);
    float4 pe  = gPosEmit.sample(s, in.uv);

    float3 albedo    = am.rgb;
    float  metalness = am.a;
    float3 N         = normalize(nr.rgb * 2.0 - 1.0);
    float  roughness = max(nr.a, 0.04);
    float3 worldPos  = pe.rgb;
    float  emitInt   = pe.a;

    float3 V    = normalize(uni.cameraPos.xyz - worldPos);
    float  NdotV = max(dot(N, V), 1e-4);

    // Fresnel base reflectance: dialectric 0.04, metal uses albedo
    float3 F0 = mix(float3(0.04), albedo, metalness);

    // Simple ambient — hemisphere approximation, attenuated for metals
    float3 Lo = albedo * uni.ambientIntensity * (1.0 - metalness * 0.6);

    // Accumulate Cook-Torrance contribution from each point light
    for (int i = 0; i < uni.lightCount; i++) {
        float3 lpos  = uni.lights[i].position.xyz;
        float  lrad  = uni.lights[i].position.w;
        float3 lcol  = uni.lights[i].color.xyz;
        float  lint  = uni.lights[i].color.w;

        float3 toL = lpos - worldPos;
        float  dist = length(toL);
        float3 L    = toL / max(dist, 1e-6);

        // Smooth quadratic falloff within radius
        float atten = max(1.0 - (dist * dist) / (lrad * lrad), 0.0);
        atten = atten * atten;

        float  NdotL = max(dot(N, L), 0.0);
        if (NdotL < 1e-5) continue;

        float3 H    = normalize(V + L);
        float  NdotH = max(dot(N, H), 0.0);
        float  HdotV = max(dot(H, V), 0.0);

        // Specular BRDF — GGX NDF × Smith masking × Fresnel
        float  D    = ggxNDF(NdotH, roughness);
        float  G    = smithGGX(NdotV, NdotL, roughness);
        float3 F    = fresnelSchlick(HdotV, F0);
        float3 spec = (D * G * F) / (4.0 * NdotV * NdotL + 1e-6);

        // Energy-conserving Lambertian diffuse
        float3 kD = (1.0 - F) * (1.0 - metalness);
        Lo += (kD * albedo / M_PI_F + spec) * NdotL * lcol * lint * atten;
    }

    // Emissive term bypasses all lighting
    Lo += albedo * emitInt;

    return float4(Lo, 1.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: Bloom — Threshold Compute Kernel
// ═══════════════════════════════════════════════════════════════════════════════

kernel void lfm_bloom_threshold(
    texture2d<float, access::read>  hdrIn    [[texture(0)]],
    texture2d<float, access::write> bloomOut [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint W = hdrIn.get_width(), H = hdrIn.get_height();
    if (gid.x >= W || gid.y >= H) return;
    float3 c    = hdrIn.read(gid).rgb;
    float  luma = dot(c, float3(0.2126, 0.7152, 0.0722));
    // Soft-knee threshold centred at luma = 1.1
    float  knee = smoothstep(0.8, 1.8, luma);
    bloomOut.write(float4(c * knee, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: Bloom — Separable Gaussian Blur (9-tap)
// ═══════════════════════════════════════════════════════════════════════════════

constant float kGW[5] = { 0.22702703, 0.19459459, 0.12162162,
                           0.05405405, 0.01621622 };

kernel void lfm_bloom_blur_h(
    texture2d<float, access::read>  src [[texture(0)]],
    texture2d<float, access::write> dst [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint W = src.get_width(), H = src.get_height();
    if (gid.x >= W || gid.y >= H) return;
    float3 acc = src.read(gid).rgb * kGW[0];
    for (int k = 1; k < 5; k++) {
        uint r = min(gid.x + uint(k), W - 1);
        uint l = (gid.x >= uint(k)) ? (gid.x - uint(k)) : 0u;
        acc += (src.read(uint2(r, gid.y)).rgb +
                src.read(uint2(l, gid.y)).rgb) * kGW[k];
    }
    dst.write(float4(acc, 1.0), gid);
}

kernel void lfm_bloom_blur_v(
    texture2d<float, access::read>  src [[texture(0)]],
    texture2d<float, access::write> dst [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint W = src.get_width(), H = src.get_height();
    if (gid.x >= W || gid.y >= H) return;
    float3 acc = src.read(gid).rgb * kGW[0];
    for (int k = 1; k < 5; k++) {
        uint d = min(gid.y + uint(k), H - 1);
        uint u = (gid.y >= uint(k)) ? (gid.y - uint(k)) : 0u;
        acc += (src.read(uint2(gid.x, d)).rgb +
                src.read(uint2(gid.x, u)).rgb) * kGW[k];
    }
    dst.write(float4(acc, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: Composite — Reinhard Tone-Mapping + Bloom
// ═══════════════════════════════════════════════════════════════════════════════

fragment float4 lfm_composite(
    QuadVaryings     in    [[stage_in]],
    texture2d<float> hdr   [[texture(0)]],
    texture2d<float> bloom [[texture(1)]])
{
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float3 hdrCol   = hdr.sample(s, in.uv).rgb;
    float3 bloomCol = bloom.sample(s, in.uv).rgb;
    // Additive bloom blend
    float3 combined = hdrCol + bloomCol * 0.65;
    // Reinhard extended tone-mapping
    float3 mapped = combined / (combined + 1.0);
    // Approximate gamma-2.2 correction
    return float4(pow(max(mapped, 0.0), float3(1.0 / 2.2)), 1.0);
}
