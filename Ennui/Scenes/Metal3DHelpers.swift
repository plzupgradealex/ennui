// Metal3DHelpers.swift — Shared Swift infrastructure for Ennui Metal 3D scenes.
// Vertex/uniform structs, geometry builders, matrix helpers, and pipeline setup.

import Metal
import MetalKit
import simd

// MARK: - Vertex types

/// Main 3D vertex. Packed as 10 floats (no SIMD3 padding surprises).
struct Vertex3D {
    var px, py, pz: Float   // position  (offset 0,  12 bytes)
    var nx, ny, nz: Float   // normal    (offset 12, 12 bytes)
    var r,  g,  b,  a: Float // color   (offset 24, 16 bytes)
    // MemoryLayout<Vertex3D>.stride == 40

    init(position p: SIMD3<Float>, normal n: SIMD3<Float>, color c: SIMD4<Float>) {
        px = p.x; py = p.y; pz = p.z
        nx = n.x; ny = n.y; nz = n.z
        r  = c.x; g  = c.y; b  = c.z; a = c.w
    }

    static func p(_ p: SIMD3<Float>, n: SIMD3<Float>, c: SIMD4<Float>) -> Vertex3D {
        Vertex3D(position: p, normal: n, color: c)
    }
}

/// Point-sprite particle vertex. Packed as 8 floats + 1 float.
struct ParticleVertex3D {
    var px, py, pz: Float   // position (offset 0,  12 bytes)
    var r,  g,  b,  a: Float // color  (offset 12, 16 bytes)
    var size: Float          // size    (offset 28,  4 bytes)
    // MemoryLayout<ParticleVertex3D>.stride == 32

    init(position p: SIMD3<Float>, color c: SIMD4<Float>, size s: Float) {
        px = p.x; py = p.y; pz = p.z
        r  = c.x; g  = c.y; b  = c.z; a = c.w
        size = s
    }
}

// MARK: - Uniform structs
// All 3-component fields are stored as float4 so Swift SIMD4<Float> stride
// matches MSL float4 layout exactly.

struct SceneUniforms3D {
    var viewProjection:  simd_float4x4
    var sunDirection:    SIMD4<Float>   // xyz = dir (world-space), w unused
    var sunColor:        SIMD4<Float>
    var ambientColor:    SIMD4<Float>   // xyz = color, w = time (seconds)
    var fogParams:       SIMD4<Float>   // x = start, y = end
    var fogColor:        SIMD4<Float>
    var cameraWorldPos:  SIMD4<Float>   // xyz = eye, w unused
}

struct DrawUniforms3D {
    var modelMatrix:   simd_float4x4
    var normalMatrix:  simd_float4x4
    var emissive:      SIMD4<Float>   // xyz = emissive color, w = mix (0..1)
    var params:        SIMD4<Float>   // x = opacity, y = specular power
}

// MARK: - Matrix helpers

func m4Translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4<Float>(x, y, z, 1)
    return m
}

func m4Scale(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
    simd_float4x4(diagonal: SIMD4<Float>(x, y, z, 1))
}

func m4RotY(_ a: Float) -> simd_float4x4 {
    let c = cos(a), s = sin(a)
    return simd_float4x4(columns: (
        SIMD4<Float>( c, 0, s, 0),
        SIMD4<Float>( 0, 1, 0, 0),
        SIMD4<Float>(-s, 0, c, 0),
        SIMD4<Float>( 0, 0, 0, 1)
    ))
}

func m4RotX(_ a: Float) -> simd_float4x4 {
    let c = cos(a), s = sin(a)
    return simd_float4x4(columns: (
        SIMD4<Float>(1,  0,  0, 0),
        SIMD4<Float>(0,  c, -s, 0),
        SIMD4<Float>(0,  s,  c, 0),
        SIMD4<Float>(0,  0,  0, 1)
    ))
}

func m4RotZ(_ a: Float) -> simd_float4x4 {
    let c = cos(a), s = sin(a)
    return simd_float4x4(columns: (
        SIMD4<Float>( c, -s, 0, 0),
        SIMD4<Float>( s,  c, 0, 0),
        SIMD4<Float>( 0,  0, 1, 0),
        SIMD4<Float>( 0,  0, 0, 1)
    ))
}

func m4Perspective(fovyRad: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let y = 1 / tan(fovyRad * 0.5)
    let x = y / aspect
    let z = far / (near - far)
    return simd_float4x4(columns: (
        SIMD4<Float>(x,     0,      0,  0),
        SIMD4<Float>(0,     y,      0,  0),
        SIMD4<Float>(0,     0,      z, -1),
        SIMD4<Float>(0,     0, z*near,  0)
    ))
}

func m4LookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let f = simd_normalize(center - eye)
    let r = simd_normalize(simd_cross(f, up))
    let u = simd_cross(r, f)
    return simd_float4x4(columns: (
        SIMD4<Float>( r.x,  u.x, -f.x, 0),
        SIMD4<Float>( r.y,  u.y, -f.y, 0),
        SIMD4<Float>( r.z,  u.z, -f.z, 0),
        SIMD4<Float>(-simd_dot(r, eye), -simd_dot(u, eye), simd_dot(f, eye), 1)
    ))
}

/// Inverse-transpose of the model matrix upper-left 3×3 (for correct normal transform).
func m4NormalMatrix(from m: simd_float4x4) -> simd_float4x4 {
    let c0 = m.columns.0; let c1 = m.columns.1; let c2 = m.columns.2
    let m3 = simd_float3x3(SIMD3<Float>(c0.x, c0.y, c0.z),
                            SIMD3<Float>(c1.x, c1.y, c1.z),
                            SIMD3<Float>(c2.x, c2.y, c2.z))
    let inv = m3.inverse.transpose
    return simd_float4x4(
        SIMD4<Float>(inv.columns.0, 0),
        SIMD4<Float>(inv.columns.1, 0),
        SIMD4<Float>(inv.columns.2, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

/// Convenience: build DrawUniforms3D from a model matrix, emissive, and parameters.
func drawUniforms(model: simd_float4x4,
                  emissiveColor: SIMD3<Float> = .zero,
                  emissiveMix: Float = 0,
                  opacity: Float = 1,
                  specularPower: Float = 32) -> DrawUniforms3D {
    DrawUniforms3D(
        modelMatrix:  model,
        normalMatrix: m4NormalMatrix(from: model),
        emissive:     SIMD4<Float>(emissiveColor, emissiveMix),
        params:       SIMD4<Float>(opacity, specularPower, 0, 0)
    )
}

// MARK: - Geometry builders
// All helpers return flat triangle-list arrays (no index buffer needed).

/// Axis-aligned box centred at origin. 36 vertices (6 faces × 2 tris × 3 verts).
func buildBox(w: Float, h: Float, d: Float, color: SIMD4<Float>) -> [Vertex3D] {
    let hw = w/2, hh = h/2, hd = d/2
    typealias V = Vertex3D
    let c = color
    func v(_ p: SIMD3<Float>, _ n: SIMD3<Float>) -> V { V.p(p, n: n, c: c) }
    let nx: SIMD3<Float> = [ 1,  0,  0], px: SIMD3<Float> = [-1,  0,  0]
    let py: SIMD3<Float> = [ 0,  1,  0], ny: SIMD3<Float> = [ 0, -1,  0]
    let pz: SIMD3<Float> = [ 0,  0,  1], nz: SIMD3<Float> = [ 0,  0, -1]
    return [
        v([ hw,  hh,  hd], nx), v([ hw, -hh,  hd], nx), v([ hw,  hh, -hd], nx),
        v([ hw, -hh,  hd], nx), v([ hw, -hh, -hd], nx), v([ hw,  hh, -hd], nx),
        v([-hw,  hh, -hd], px), v([-hw, -hh, -hd], px), v([-hw,  hh,  hd], px),
        v([-hw, -hh, -hd], px), v([-hw, -hh,  hd], px), v([-hw,  hh,  hd], px),
        v([-hw,  hh, -hd], py), v([-hw,  hh,  hd], py), v([ hw,  hh, -hd], py),
        v([-hw,  hh,  hd], py), v([ hw,  hh,  hd], py), v([ hw,  hh, -hd], py),
        v([-hw, -hh,  hd], ny), v([-hw, -hh, -hd], ny), v([ hw, -hh,  hd], ny),
        v([-hw, -hh, -hd], ny), v([ hw, -hh, -hd], ny), v([ hw, -hh,  hd], ny),
        v([-hw,  hh,  hd], pz), v([-hw, -hh,  hd], pz), v([ hw,  hh,  hd], pz),
        v([-hw, -hh,  hd], pz), v([ hw, -hh,  hd], pz), v([ hw,  hh,  hd], pz),
        v([ hw,  hh, -hd], nz), v([ hw, -hh, -hd], nz), v([-hw,  hh, -hd], nz),
        v([ hw, -hh, -hd], nz), v([-hw, -hh, -hd], nz), v([-hw,  hh, -hd], nz),
    ]
}

/// Flat horizontal ground plane (XZ, centred at origin, normal = +Y). 6 vertices.
func buildPlane(w: Float, d: Float, color: SIMD4<Float>) -> [Vertex3D] {
    let hw = w/2, hd = d/2
    let n: SIMD3<Float> = [0, 1, 0], c = color
    return [
        Vertex3D(position: [-hw, 0, -hd], normal: n, color: c),
        Vertex3D(position: [-hw, 0,  hd], normal: n, color: c),
        Vertex3D(position: [ hw, 0, -hd], normal: n, color: c),
        Vertex3D(position: [-hw, 0,  hd], normal: n, color: c),
        Vertex3D(position: [ hw, 0,  hd], normal: n, color: c),
        Vertex3D(position: [ hw, 0, -hd], normal: n, color: c),
    ]
}

/// Vertical quad in XY plane, facing +Z, centred at origin. 6 vertices.
func buildQuad(w: Float, h: Float, color: SIMD4<Float>,
               normal: SIMD3<Float> = [0, 0, 1]) -> [Vertex3D] {
    let hw = w/2, hh = h/2, n = normal, c = color
    return [
        Vertex3D(position: [-hw, -hh, 0], normal: n, color: c),
        Vertex3D(position: [ hw, -hh, 0], normal: n, color: c),
        Vertex3D(position: [-hw,  hh, 0], normal: n, color: c),
        Vertex3D(position: [ hw, -hh, 0], normal: n, color: c),
        Vertex3D(position: [ hw,  hh, 0], normal: n, color: c),
        Vertex3D(position: [-hw,  hh, 0], normal: n, color: c),
    ]
}

/// Upright cylinder centred at origin, axis = Y.
func buildCylinder(radius r: Float, height h: Float, segments s: Int,
                   color: SIMD4<Float>) -> [Vertex3D] {
    var v: [Vertex3D] = []; let hh = h/2
    let step = 2 * Float.pi / Float(s)
    for i in 0..<s {
        let a0 = Float(i) * step, a1 = Float(i+1) * step
        let c0 = cos(a0), s0 = sin(a0), c1 = cos(a1), s1 = sin(a1)
        let p00: SIMD3<Float> = [r*c0, -hh, r*s0], p10: SIMD3<Float> = [r*c1, -hh, r*s1]
        let p01: SIMD3<Float> = [r*c0,  hh, r*s0], p11: SIMD3<Float> = [r*c1,  hh, r*s1]
        let n0: SIMD3<Float>  = [c0, 0, s0],        n1: SIMD3<Float>  = [c1, 0, s1]
        v += [Vertex3D(position: p00, normal: n0, color: color),
              Vertex3D(position: p10, normal: n1, color: color),
              Vertex3D(position: p01, normal: n0, color: color),
              Vertex3D(position: p10, normal: n1, color: color),
              Vertex3D(position: p11, normal: n1, color: color),
              Vertex3D(position: p01, normal: n0, color: color)]
        let ty: SIMD3<Float> = [0, 1, 0], by: SIMD3<Float> = [0, -1, 0]
        let tc: SIMD3<Float> = [0, hh, 0], bc: SIMD3<Float> = [0, -hh, 0]
        v += [Vertex3D(position: tc, normal: ty, color: color),
              Vertex3D(position: p01, normal: ty, color: color),
              Vertex3D(position: p11, normal: ty, color: color),
              Vertex3D(position: bc, normal: by, color: color),
              Vertex3D(position: p10, normal: by, color: color),
              Vertex3D(position: p00, normal: by, color: color)]
    }
    return v
}

/// Cone: apex at +Y (hh), base at -Y (-hh), centred at origin.
func buildCone(radius r: Float, height h: Float, segments s: Int,
               color: SIMD4<Float>) -> [Vertex3D] {
    var v: [Vertex3D] = []; let hh = h/2
    let step = 2 * Float.pi / Float(s)
    let apex: SIMD3<Float> = [0, hh, 0]
    for i in 0..<s {
        let a0 = Float(i) * step, a1 = Float(i+1) * step
        let c0 = cos(a0), s0 = sin(a0), c1 = cos(a1), s1 = sin(a1)
        let p0: SIMD3<Float> = [r*c0, -hh, r*s0], p1: SIMD3<Float> = [r*c1, -hh, r*s1]
        let midN = simd_normalize(SIMD3<Float>(c0+c1, 0, s0+s1))
        let slant = simd_normalize(SIMD3<Float>(midN.x, r/h, midN.z))
        v += [Vertex3D(position: apex, normal: slant, color: color),
              Vertex3D(position: p0,   normal: slant, color: color),
              Vertex3D(position: p1,   normal: slant, color: color)]
        let by: SIMD3<Float> = [0, -1, 0], bc: SIMD3<Float> = [0, -hh, 0]
        v += [Vertex3D(position: bc, normal: by, color: color),
              Vertex3D(position: p1, normal: by, color: color),
              Vertex3D(position: p0, normal: by, color: color)]
    }
    return v
}

/// Pyramid with flat rectangular base (used for rooftops). 18 vertices.
func buildPyramid(bw: Float, bd: Float, h: Float, color: SIMD4<Float>) -> [Vertex3D] {
    let hw = bw/2, hd = bd/2
    let apex: SIMD3<Float> = [0, h, 0]
    let bl: SIMD3<Float> = [-hw, 0, -hd], br: SIMD3<Float> = [ hw, 0, -hd]
    let fl: SIMD3<Float> = [-hw, 0,  hd], fr: SIMD3<Float> = [ hw, 0,  hd]
    func faceN(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> SIMD3<Float> {
        simd_normalize(simd_cross(b-a, c-a))
    }
    let nF = faceN(fl, fr, apex), nB = faceN(br, bl, apex)
    let nL = faceN(bl, fl, apex), nR = faceN(fr, br, apex)
    let nD: SIMD3<Float> = [0, -1, 0]
    return [
        Vertex3D(position: fl,   normal: nF, color: color),
        Vertex3D(position: fr,   normal: nF, color: color),
        Vertex3D(position: apex, normal: nF, color: color),
        Vertex3D(position: br,   normal: nB, color: color),
        Vertex3D(position: bl,   normal: nB, color: color),
        Vertex3D(position: apex, normal: nB, color: color),
        Vertex3D(position: bl,   normal: nL, color: color),
        Vertex3D(position: fl,   normal: nL, color: color),
        Vertex3D(position: apex, normal: nL, color: color),
        Vertex3D(position: fr,   normal: nR, color: color),
        Vertex3D(position: br,   normal: nR, color: color),
        Vertex3D(position: apex, normal: nR, color: color),
        Vertex3D(position: bl, normal: nD, color: color),
        Vertex3D(position: br, normal: nD, color: color),
        Vertex3D(position: fr, normal: nD, color: color),
        Vertex3D(position: bl, normal: nD, color: color),
        Vertex3D(position: fr, normal: nD, color: color),
        Vertex3D(position: fl, normal: nD, color: color),
    ]
}

/// Sphere centred at origin.
func buildSphere(radius r: Float, rings: Int, segments: Int,
                 color: SIMD4<Float>) -> [Vertex3D] {
    var v: [Vertex3D] = []
    for i in 0..<rings {
        let phi0 = Float.pi * Float(i)   / Float(rings)
        let phi1 = Float.pi * Float(i+1) / Float(rings)
        for j in 0..<segments {
            let th0 = 2*Float.pi * Float(j)   / Float(segments)
            let th1 = 2*Float.pi * Float(j+1) / Float(segments)
            func sp(_ phi: Float, _ th: Float) -> SIMD3<Float> {
                [r * sin(phi)*cos(th), r * cos(phi), r * sin(phi)*sin(th)]
            }
            let p = [sp(phi0,th0), sp(phi1,th0), sp(phi0,th1), sp(phi1,th1)]
            v += [Vertex3D(position: p[0], normal: simd_normalize(p[0]), color: color),
                  Vertex3D(position: p[1], normal: simd_normalize(p[1]), color: color),
                  Vertex3D(position: p[2], normal: simd_normalize(p[2]), color: color),
                  Vertex3D(position: p[1], normal: simd_normalize(p[1]), color: color),
                  Vertex3D(position: p[3], normal: simd_normalize(p[3]), color: color),
                  Vertex3D(position: p[2], normal: simd_normalize(p[2]), color: color)]
        }
    }
    return v
}

// MARK: - Pipeline state factory

/// Creates the main opaque render pipeline state.
func makeOpaquePipeline(device: MTLDevice) throws -> MTLRenderPipelineState {
    try makeScene3DPipeline(device: device, blendEnabled: false)
}

/// Creates a blended (alpha) pipeline state (used for emissive windows, transparent geo).
func makeAlphaBlendPipeline(device: MTLDevice) throws -> MTLRenderPipelineState {
    try makeScene3DPipeline(device: device, blendEnabled: true)
}

private func makeScene3DPipeline(device: MTLDevice,
                                  blendEnabled: Bool) throws -> MTLRenderPipelineState {
    guard let library = device.makeDefaultLibrary() else {
        throw NSError(domain: "Metal3D", code: 1, userInfo: nil)
    }
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction   = library.makeFunction(name: "vertexShader3D")
    desc.fragmentFunction = library.makeFunction(name: "fragmentShader3D")
    desc.depthAttachmentPixelFormat          = .depth32Float
    desc.colorAttachments[0].pixelFormat     = .bgra8Unorm

    let vd = MTLVertexDescriptor()
    vd.attributes[0].format = .float3; vd.attributes[0].offset = 0;  vd.attributes[0].bufferIndex = 0
    vd.attributes[1].format = .float3; vd.attributes[1].offset = 12; vd.attributes[1].bufferIndex = 0
    vd.attributes[2].format = .float4; vd.attributes[2].offset = 24; vd.attributes[2].bufferIndex = 0
    vd.layouts[0].stride = MemoryLayout<Vertex3D>.stride
    desc.vertexDescriptor = vd

    if blendEnabled {
        let ca = desc.colorAttachments[0]!
        ca.isBlendingEnabled             = true
        ca.rgbBlendOperation             = .add
        ca.alphaBlendOperation           = .add
        ca.sourceRGBBlendFactor          = .sourceAlpha
        ca.sourceAlphaBlendFactor        = .sourceAlpha
        ca.destinationRGBBlendFactor     = .oneMinusSourceAlpha
        ca.destinationAlphaBlendFactor   = .oneMinusSourceAlpha
    }
    return try device.makeRenderPipelineState(descriptor: desc)
}

/// Creates the additive particle pipeline state.
func makeParticlePipeline(device: MTLDevice) throws -> MTLRenderPipelineState {
    guard let library = device.makeDefaultLibrary() else {
        throw NSError(domain: "Metal3D", code: 1, userInfo: nil)
    }
    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction   = library.makeFunction(name: "particleVertexShader3D")
    desc.fragmentFunction = library.makeFunction(name: "particleFragmentShader3D")
    desc.depthAttachmentPixelFormat          = .depth32Float
    desc.colorAttachments[0].pixelFormat     = .bgra8Unorm
    let ca = desc.colorAttachments[0]!
    ca.isBlendingEnabled           = true
    ca.rgbBlendOperation           = .add; ca.alphaBlendOperation           = .add
    ca.sourceRGBBlendFactor        = .one; ca.sourceAlphaBlendFactor        = .one
    ca.destinationRGBBlendFactor   = .one; ca.destinationAlphaBlendFactor   = .one

    let vd = MTLVertexDescriptor()
    vd.attributes[0].format = .float3; vd.attributes[0].offset = 0;  vd.attributes[0].bufferIndex = 0
    vd.attributes[1].format = .float4; vd.attributes[1].offset = 12; vd.attributes[1].bufferIndex = 0
    vd.attributes[2].format = .float;  vd.attributes[2].offset = 28; vd.attributes[2].bufferIndex = 0
    vd.layouts[0].stride = MemoryLayout<ParticleVertex3D>.stride
    desc.vertexDescriptor = vd
    return try device.makeRenderPipelineState(descriptor: desc)
}

/// Standard depth-test-and-write state.
func makeDepthState(device: MTLDevice) -> MTLDepthStencilState? {
    let d = MTLDepthStencilDescriptor()
    d.depthCompareFunction = .less
    d.isDepthWriteEnabled  = true
    return device.makeDepthStencilState(descriptor: d)
}

/// Depth-test but no write (for transparent objects drawn after opaques).
func makeDepthReadOnlyState(device: MTLDevice) -> MTLDepthStencilState? {
    let d = MTLDepthStencilDescriptor()
    d.depthCompareFunction = .less
    d.isDepthWriteEnabled  = false
    return device.makeDepthStencilState(descriptor: d)
}

// MARK: - Render helper

/// Uploads `vertices` to a managed Metal buffer and returns it.
func makeVertexBuffer(_ vertices: [Vertex3D], device: MTLDevice) -> MTLBuffer? {
    guard !vertices.isEmpty else { return nil }
    return device.makeBuffer(bytes: vertices,
                             length: vertices.count * MemoryLayout<Vertex3D>.stride,
                             options: .storageModeShared)
}

func makeParticleBuffer(_ particles: [ParticleVertex3D], device: MTLDevice) -> MTLBuffer? {
    guard !particles.isEmpty else { return nil }
    return device.makeBuffer(bytes: particles,
                             length: particles.count * MemoryLayout<ParticleVertex3D>.stride,
                             options: .storageModeShared)
}

/// Encode one draw call: set model uniforms, bind vertex buffer, draw primitives.
func encodeDraw(encoder: MTLRenderCommandEncoder,
                vertexBuffer: MTLBuffer,
                vertexCount: Int,
                model: simd_float4x4,
                emissiveColor: SIMD3<Float> = .zero,
                emissiveMix: Float = 0,
                opacity: Float = 1,
                specularPower: Float = 32) {
    var du = drawUniforms(model: model,
                         emissiveColor: emissiveColor,
                         emissiveMix: emissiveMix,
                         opacity: opacity,
                         specularPower: specularPower)
    encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    encoder.setVertexBytes(&du, length: MemoryLayout<DrawUniforms3D>.size, index: 2)
    encoder.setFragmentBytes(&du, length: MemoryLayout<DrawUniforms3D>.size, index: 2)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
}
