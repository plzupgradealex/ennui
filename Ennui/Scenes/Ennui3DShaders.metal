// Ennui3DShaders.metal — Shared Metal shaders for all Ennui 3D scenes.
// Implements Blinn-Phong shading with fog, emissive surfaces, and soft
// additive point-sprite particles.

#include <metal_stdlib>
using namespace metal;

// MARK: - Data structures

// Vertex fed from Swift vertex buffer
struct VertexIn3D {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float4 color    [[attribute(2)]];
};

// Interpolated data passed to fragment shader
struct VertexOut3D {
    float4 clipPosition  [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float4 color;
    float  emissiveMix;  // 0 = fully shaded, 1 = fully emissive
};

// Per-frame scene uniforms (all float3 fields padded to float4 to avoid
// alignment surprises between Swift/SIMD and MSL)
struct SceneUniforms3D {
    float4x4 viewProjection;
    float4   sunDirection;     // xyz = direction (world), w unused
    float4   sunColor;         // xyz = color
    float4   ambientColor;     // xyz = color, w = time (seconds)
    float4   fogParams;        // x = start, y = end
    float4   fogColor;         // xyz = color
    float4   cameraWorldPos;   // xyz = eye position
};

// Per-draw-call uniforms
struct DrawUniforms3D {
    float4x4 modelMatrix;
    float4x4 normalMatrix;
    float4   emissive;         // xyz = emissive color, w = mix (0..1)
    float4   params;           // x = opacity, y = specular power
};

// MARK: - Main vertex shader

vertex VertexOut3D vertexShader3D(VertexIn3D         in    [[stage_in]],
                                  constant SceneUniforms3D& scene [[buffer(1)]],
                                  constant DrawUniforms3D&  draw  [[buffer(2)]]) {
    float4 worldPos4      = draw.modelMatrix * float4(in.position, 1.0);
    float3 worldNormal    = normalize((draw.normalMatrix * float4(in.normal, 0.0)).xyz);

    VertexOut3D out;
    out.clipPosition  = scene.viewProjection * worldPos4;
    out.worldPosition = worldPos4.xyz;
    out.worldNormal   = worldNormal;
    out.color         = in.color;
    out.emissiveMix   = draw.emissive.w;
    return out;
}

// MARK: - Main fragment shader (Blinn-Phong + fog + emissive)

fragment float4 fragmentShader3D(VertexOut3D            in    [[stage_in]],
                                  constant SceneUniforms3D& scene [[buffer(1)]],
                                  constant DrawUniforms3D&  draw  [[buffer(2)]]) {
    float3 N = normalize(in.worldNormal);
    float3 L = normalize(-scene.sunDirection.xyz);
    float3 V = normalize(scene.cameraWorldPos.xyz - in.worldPosition);
    float3 H = normalize(L + V);

    // Diffuse (Lambert)
    float  diff   = max(dot(N, L), 0.0);
    float3 diffuse = diff * scene.sunColor.xyz * in.color.rgb;

    // Specular (Blinn-Phong, subtle)
    float  spPow  = max(draw.params.y, 1.0);
    float  spec   = pow(max(dot(N, H), 0.0), spPow);
    float3 specular = spec * scene.sunColor.xyz * 0.12;

    // Ambient
    float3 ambient = scene.ambientColor.xyz * in.color.rgb;

    // Shaded result
    float3 shaded = ambient + diffuse + specular;

    // Emissive blend
    float3 finalColor = mix(shaded, draw.emissive.xyz, in.emissiveMix);

    // Linear fog
    float dist      = length(in.worldPosition - scene.cameraWorldPos.xyz);
    float fogFactor = clamp((dist - scene.fogParams.x) / (scene.fogParams.y - scene.fogParams.x),
                            0.0, 1.0);
    finalColor = mix(finalColor, scene.fogColor.xyz, fogFactor);

    return float4(finalColor, in.color.a * draw.params.x);
}

// MARK: - Transparent / blended objects use the same shaders but with
//         alpha blending enabled in the pipeline state; no separate shader needed.

// MARK: - Particle vertex

struct ParticleIn3D {
    float3 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
    float  size     [[attribute(2)]];
};

struct ParticleOut3D {
    float4 clipPos [[position]];
    float4 color;
    float  ptSize  [[point_size]];
};

vertex ParticleOut3D particleVertexShader3D(ParticleIn3D         in    [[stage_in]],
                                             constant SceneUniforms3D& scene [[buffer(1)]]) {
    ParticleOut3D out;
    out.clipPos = scene.viewProjection * float4(in.position, 1.0);
    out.color   = in.color;
    out.ptSize  = in.size;
    return out;
}

// MARK: - Particle fragment (soft additive disc)

fragment float4 particleFragmentShader3D(ParticleOut3D in          [[stage_in]],
                                          float2        pointCoord [[point_coord]]) {
    float d     = length(pointCoord - float2(0.5));
    float alpha = max(0.0, 1.0 - d * 2.2) * in.color.a;
    return float4(in.color.rgb * alpha, alpha);  // pre-multiplied for additive blend
}
