// LastAndFirstMen3DScene — Metal PBR retelling of Olaf Stapledon's
// Last and First Men (1930). Eighteen human species across two billion years,
// migrating from Earth to Venus to Neptune, ascending through the Kardashev
// scale from a single world to the stars. Peaceful, contemplative, eternal.
//
// Rendering: deferred PBR (Cook-Torrance BRDF + GGX), HDR bloom (compute),
//            Reinhard tone-mapping. Five-phase cinematic 120-second camera loop.
// Tap: awakens the next human species — brightness pulse ripples outward
//      through all three Kardashev scale rings.

import SwiftUI
import MetalKit
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - GPU Data Structures (layouts must match LastAndFirstMenShaders.metal)
// ═══════════════════════════════════════════════════════════════════════════════

// 10 packed floats, stride = 40 bytes — no SIMD3 padding issues
private struct LFMVertex {
    var px, py, pz: Float   // offset  0, 12 bytes
    var nx, ny, nz: Float   // offset 12, 12 bytes
    var r,  g,  b, a: Float // offset 24, 16 bytes
}

// 176 bytes — SIMD4<Float> for all 3-component vectors (matches MSL float4)
private struct LFMUniforms {
    var modelMatrix: simd_float4x4  // 64 bytes
    var vpMatrix:    simd_float4x4  // 64 bytes
    var cameraPos:   SIMD4<Float>   // 16 bytes (xyz=pos, w=time)
    var emissive:    SIMD4<Float>   // 16 bytes (xyz=color, w=intensity)
    var material:    SIMD4<Float>   // 16 bytes (x=metalness, y=roughness, z=isEmissive)
}

// 32 bytes
private struct LFMLight {
    var position: SIMD4<Float>  // xyz=world-pos, w=radius
    var color:    SIMD4<Float>  // xyz=color,     w=intensity
}

// 224 bytes — tuple used for fixed-size array to guarantee layout
private struct LFMDeferredUniforms {
    var cameraPos:        SIMD4<Float>                                              // 16
    var lights: (LFMLight, LFMLight, LFMLight, LFMLight, LFMLight, LFMLight)       // 192
    var lightCount:       Int32                                                     //  4
    var ambientIntensity: Float                                                     //  4
    var _pad:             SIMD2<Float>                                              //  8
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Draw Call
// ═══════════════════════════════════════════════════════════════════════════════

private struct LFMDrawCall {
    let vtxBuf:     MTLBuffer
    let idxBuf:     MTLBuffer
    let indexCount: Int
    var albedo:            SIMD3<Float>
    var emissive:          SIMD3<Float>
    var emissiveIntensity: Float
    var metalness:         Float
    var roughness:         Float
    var isEmissive:        Bool
    var modelMatrix:       simd_float4x4
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - View Layer
// ═══════════════════════════════════════════════════════════════════════════════

struct LastAndFirstMen3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        LastAndFirstMen3DRepresentable(interaction: interaction)
    }
}

private struct LastAndFirstMen3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject {
        var renderer: LastAndFirstMen3DRenderer?
        var lastTapCount = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .invalid  // we manage depth ourselves
        view.clearColor = MTLClearColor(red: 0.02, green: 0.01, blue: 0.06, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        let r = LastAndFirstMen3DRenderer(view: view)
        context.coordinator.renderer = r
        view.delegate = r
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.renderer?.handleTap()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Renderer
// ═══════════════════════════════════════════════════════════════════════════════

final class LastAndFirstMen3DRenderer: NSObject, MTKViewDelegate {

    // MARK: Metal core
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var gBufferPSO:    MTLRenderPipelineState!
    private var lightingPSO:   MTLRenderPipelineState!
    private var compositePSO:  MTLRenderPipelineState!
    private var bloomThreshPSO: MTLComputePipelineState!
    private var bloomBlurHPSO:  MTLComputePipelineState!
    private var bloomBlurVPSO:  MTLComputePipelineState!
    private var dss: MTLDepthStencilState!  // for G-buffer geometry pass

    // MARK: Intermediate textures (rebuilt on resize)
    private var gbAlbedoMetal: MTLTexture?
    private var gbNormalRough: MTLTexture?
    private var gbPosEmit:     MTLTexture?
    private var depthTex:      MTLTexture?
    private var hdrTex:        MTLTexture?
    private var bloom0:        MTLTexture?
    private var bloom1:        MTLTexture?

    // MARK: Scene draw list
    private var draws: [LFMDrawCall] = []
    private var lights: [LFMLight] = []

    // Index ranges into draws[] for each object category
    private var worldRange:         Range<Int> = 0..<0
    private var civRingRange:       Range<Int> = 0..<0
    private var sunRingRange:       Range<Int> = 0..<0  // sunburst tori
    private var sunSpokeRange:      Range<Int> = 0..<0  // sunburst spokes
    private var obeliskRange:       Range<Int> = 0..<0
    private var kardashevRange:     Range<Int> = 0..<0
    private var speciesRange:       Range<Int> = 0..<0
    private var filamentRange:      Range<Int> = 0..<0
    private var starRange:          Range<Int> = 0..<0

    // MARK: Per-category animation state
    private struct WorldInfo { var pos: SIMD3<Float>; var radius: Float; var rotSpeed: Float }
    private var worldInfo: [WorldInfo] = []

    private var speciesBaseY: [Float] = []         // bobbing base Y
    private var speciesBobPhases: [Float] = []
    private var speciesBasePos: [SIMD3<Float>] = []

    private var kardashevBasePos:  [SIMD3<Float>] = []
    private var kardashevTilt:     [simd_float4x4] = []
    private var kardashevRotSpeed: [Float] = []

    private var civRingRotSpeed: [Float] = []
    private var civRingTilt:     [simd_float4x4] = []

    private var sunPos:   [SIMD3<Float>] = []
    private var sunScale: [Float] = []

    // MARK: Tap interaction
    private var speciesIndex  = 0
    private var speciesTapBoosts = [Float](repeating: 0, count: 18)
    private var prevTime: Double = 0

    // MARK: Camera / timing
    private var aspectRatio: Float = 1.0
    private var viewSize: CGSize = .zero
    private var startTime: Double = 0

    // ── Init ──────────────────────────────────────────────────────────────────

    init?(view: MTKView) {
        guard let dev = view.device,
              let cq  = dev.makeCommandQueue() else { return nil }
        device = dev
        commandQueue = cq
        super.init()
        buildPipelines(colorFormat: view.colorPixelFormat)
        buildScene()
        buildLights()
        startTime = CACurrentMediaTime()
        prevTime  = startTime
    }

    // ── MTKViewDelegate ───────────────────────────────────────────────────────

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspectRatio = Float(size.width / max(size.height, 1))
        viewSize    = size
        buildTextures(size: size)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let cmdBuf   = commandQueue.makeCommandBuffer(),
              let gA = gbAlbedoMetal, let gN = gbNormalRough,
              let gP = gbPosEmit,     let dt = depthTex,
              let ht = hdrTex,        let b0 = bloom0, let b1 = bloom1
        else { return }

        let now  = CACurrentMediaTime()
        let t    = now - startTime
        let dt_s = Float(now - prevTime)
        prevTime = now

        // Decay tap boosts
        for i in 0..<18 {
            speciesTapBoosts[i] = max(0, speciesTapBoosts[i] - dt_s * 1.6)
        }

        update(time: t)
        let (vp, camPos4) = cameraState(time: t)

        gBufferPass(cmdBuf: cmdBuf,  vp: vp, camPos: camPos4, depth: dt,
                    albedo: gA, normal: gN, position: gP)
        lightingPass(cmdBuf: cmdBuf, hdr: ht, camPos: camPos4,
                     albedo: gA, normal: gN, position: gP)
        bloomPass(cmdBuf: cmdBuf, hdr: ht, b0: b0, b1: b1)
        compositePass(cmdBuf: cmdBuf, drawable: drawable, hdr: ht, bloom: b0)

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    func handleTap() {
        let idx = speciesIndex % 18
        speciesTapBoosts[idx] = 4.0
        speciesIndex += 1
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Pipeline Setup
    // ═══════════════════════════════════════════════════════════════════════════

    private func buildPipelines(colorFormat: MTLPixelFormat) {
        guard let lib = device.makeDefaultLibrary() else { return }

        // G-buffer PSO: 3 HDR colour attachments + depth
        let gbd = MTLRenderPipelineDescriptor()
        gbd.label            = "LFM_GBuffer"
        gbd.vertexFunction   = lib.makeFunction(name: "lfm_geom_vertex")
        gbd.fragmentFunction = lib.makeFunction(name: "lfm_geom_fragment")
        gbd.colorAttachments[0].pixelFormat = .rgba16Float
        gbd.colorAttachments[1].pixelFormat = .rgba16Float
        gbd.colorAttachments[2].pixelFormat = .rgba16Float
        gbd.depthAttachmentPixelFormat      = .depth32Float
        gBufferPSO = try? device.makeRenderPipelineState(descriptor: gbd)

        // Deferred lighting PSO: full-screen quad → HDR texture
        let ld = MTLRenderPipelineDescriptor()
        ld.label            = "LFM_Lighting"
        ld.vertexFunction   = lib.makeFunction(name: "lfm_quad_vertex")
        ld.fragmentFunction = lib.makeFunction(name: "lfm_deferred_lighting")
        ld.colorAttachments[0].pixelFormat = .rgba16Float
        lightingPSO = try? device.makeRenderPipelineState(descriptor: ld)

        // Composite PSO: full-screen quad → drawable
        let cd = MTLRenderPipelineDescriptor()
        cd.label            = "LFM_Composite"
        cd.vertexFunction   = lib.makeFunction(name: "lfm_quad_vertex")
        cd.fragmentFunction = lib.makeFunction(name: "lfm_composite")
        cd.colorAttachments[0].pixelFormat = colorFormat
        compositePSO = try? device.makeRenderPipelineState(descriptor: cd)

        // Bloom compute PSOs
        if let f = lib.makeFunction(name: "lfm_bloom_threshold") {
            bloomThreshPSO = try? device.makeComputePipelineState(function: f)
        }
        if let f = lib.makeFunction(name: "lfm_bloom_blur_h") {
            bloomBlurHPSO = try? device.makeComputePipelineState(function: f)
        }
        if let f = lib.makeFunction(name: "lfm_bloom_blur_v") {
            bloomBlurVPSO = try? device.makeComputePipelineState(function: f)
        }

        // Depth stencil state: less-than with write
        let dd = MTLDepthStencilDescriptor()
        dd.depthCompareFunction = .less
        dd.isDepthWriteEnabled  = true
        dss = device.makeDepthStencilState(descriptor: dd)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Texture Management
    // ═══════════════════════════════════════════════════════════════════════════

    private func buildTextures(size: CGSize) {
        let w = max(Int(size.width), 1), h = max(Int(size.height), 1)

        func tex(_ fmt: MTLPixelFormat, _ usage: MTLTextureUsage) -> MTLTexture? {
            let d = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: fmt, width: w, height: h, mipmapped: false)
            d.usage       = usage
            d.storageMode = .private
            return device.makeTexture(descriptor: d)
        }

        gbAlbedoMetal = tex(.rgba16Float, [.renderTarget, .shaderRead])
        gbNormalRough = tex(.rgba16Float, [.renderTarget, .shaderRead])
        gbPosEmit     = tex(.rgba16Float, [.renderTarget, .shaderRead])
        depthTex      = tex(.depth32Float, .renderTarget)
        hdrTex        = tex(.rgba16Float, [.renderTarget, .shaderRead, .shaderWrite])
        bloom0        = tex(.rgba16Float, [.shaderRead, .shaderWrite])
        bloom1        = tex(.rgba16Float, [.shaderRead, .shaderWrite])
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Scene Construction
    // ═══════════════════════════════════════════════════════════════════════════

    private func buildScene() {
        let gold  = SIMD3<Float>(0.88, 0.70, 0.25)
        // (background colour set on MTKView in makeNSView)

        // ── Stars ────────────────────────────────────────────────────────────
        let starStart = draws.count
        var rng = SplitMix64(seed: 2030)
        let (qv, qi) = makeQuad(size: 1)
        for _ in 0..<200 {
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            let phi   = Double.random(in: 0...(.pi), using: &rng)
            let r     = Double.random(in: 45...70, using: &rng)
            let x = Float(r * sin(phi) * cos(theta))
            let y = Float(r * cos(phi))
            let z = Float(r * sin(phi) * sin(theta))
            let s = Float(Double.random(in: 0.04...0.18, using: &rng))
            let b = Float(Double.random(in: 0.5...1.0, using: &rng))
            let sc = SIMD3<Float>(b, b, b * 0.95)
            addDraw(verts: qv, indices: qi, albedo: sc, emissive: sc,
                    emissiveIntensity: b * 2.5, metalness: 0, roughness: 1,
                    isEmissive: true,
                    model: translMtx(SIMD3(x, y, z)) * scaleMtx(SIMD3(s, s, s)))
        }
        starRange = starStart..<draws.count

        // ── Three worlds: Earth, Venus, Neptune ──────────────────────────────
        let worldStart = draws.count
        let worldDefs: [(pos: SIMD3<Float>, r: Float, speed: Float,
                          col: SIMD3<Float>, emit: SIMD3<Float>)] = [
            (SIMD3(-9, 1, -5),  1.4, 0.15,
             SIMD3(0.15, 0.45, 0.75), SIMD3(0.10, 0.30, 0.55)),
            (SIMD3(0, 2, -9),   1.2, 0.12,
             SIMD3(0.90, 0.70, 0.20), SIMD3(0.70, 0.48, 0.10)),
            (SIMD3(9, 0, -4),   1.6, 0.08,
             SIMD3(0.22, 0.48, 0.82), SIMD3(0.12, 0.28, 0.62)),
        ]
        let (sv, si) = makeSphere(rings: 20, sectors: 28)
        for wd in worldDefs {
            worldInfo.append(WorldInfo(pos: wd.pos, radius: wd.r, rotSpeed: wd.speed))
            addDraw(verts: sv, indices: si, albedo: wd.col, emissive: wd.emit,
                    emissiveIntensity: 0.45, metalness: 0.05, roughness: 0.55,
                    isEmissive: false,
                    model: translMtx(wd.pos) * scaleMtx(SIMD3(wd.r, wd.r, wd.r)))
        }
        worldRange = worldStart..<draws.count

        // ── Civilisation rings (tori orbiting each world) ────────────────────
        let civStart = draws.count
        let civParams: [(Float, Float, Float, simd_float4x4)] = [
            (3.64, 0.06, 0.28, rotXMtx(0.40) * rotZMtx(0.16)),  // Earth
            (3.12, 0.06, 0.32, rotXMtx(0.32) * rotZMtx(0.10)),  // Venus
            (4.16, 0.06, 0.20, rotXMtx(0.25) * rotZMtx(0.08)),  // Neptune
        ]
        let civColors: [SIMD3<Float>] = [
            SIMD3(0.55, 0.80, 0.30), SIMD3(0.95, 0.75, 0.30), SIMD3(0.58, 0.80, 1.0),
        ]
        for (i, cp) in civParams.enumerated() {
            let (ringR, pipeR, speed, tilt) = cp
            let (tv, ti) = makeTorus(ringR: ringR, pipeR: pipeR, ringSegs: 36, pipeSegs: 10)
            civRingRotSpeed.append(speed)
            civRingTilt.append(tilt)
            addDraw(verts: tv, indices: ti, albedo: civColors[i], emissive: civColors[i],
                    emissiveIntensity: 0.65, metalness: 0, roughness: 1,
                    isEmissive: true, model: translMtx(worldDefs[i].pos) * tilt)
        }
        civRingRange = civStart..<draws.count

        // ── Sunburst rings + spokes (art deco: 3 worlds + obelisk top) ───────
        let sunRingStart = draws.count
        let sunPositions: [SIMD3<Float>] = [
            SIMD3(-9, 1, -5), SIMD3(0, 2, -9), SIMD3(9, 0, -4),
            SIMD3(0, 6.75, 0),  // obelisk cap
        ]
        let sunRadii: [Float] = [3.36, 2.88, 3.84, 2.20]
        for (i, spos) in sunPositions.enumerated() {
            sunPos.append(spos)
            sunScale.append(sunRadii[i])
            let (rv, ri) = makeTorus(ringR: sunRadii[i], pipeR: 0.042,
                                     ringSegs: 40, pipeSegs: 6)
            addDraw(verts: rv, indices: ri, albedo: gold, emissive: gold,
                    emissiveIntensity: 0.45, metalness: 0, roughness: 1,
                    isEmissive: true, model: translMtx(spos))
        }
        sunRingRange = sunRingStart..<draws.count

        let sunSpokeStart = draws.count
        for (i, spos) in sunPositions.enumerated() {
            let (spv, spi) = makeSunburstSpokes(outerR: sunRadii[i] * 0.96,
                                                 innerR: sunRadii[i] * 0.18, spokes: 12)
            addDraw(verts: spv, indices: spi, albedo: gold, emissive: gold,
                    emissiveIntensity: 0.28, metalness: 0, roughness: 1,
                    isEmissive: true, model: translMtx(spos))
        }
        sunSpokeRange = sunSpokeStart..<draws.count

        // ── Art deco obelisk (stepped plinth + shaft + pyramid cap) ─────────
        let obeliskStart = draws.count
        let steps: [(CGFloat, CGFloat, Float)] = [(3.2, 0.28, -4.86),
                                                   (2.3, 0.28, -4.58),
                                                   (1.5, 0.28, -4.30)]
        for (w, h, y) in steps {
            let (bv, bi) = makeBox(w: Float(w), h: Float(h), d: Float(w))
            addDraw(verts: bv, indices: bi, albedo: gold, emissive: gold,
                    emissiveIntensity: 0.22, metalness: 0.6, roughness: 0.35,
                    model: translMtx(SIMD3(0, y + Float(h) / 2, 0)))
        }
        let (shv, shi) = makeBox(w: 0.55, h: 11.5, d: 0.55)
        addDraw(verts: shv, indices: shi,
                albedo: SIMD3(0.72, 0.58, 0.18), emissive: gold,
                emissiveIntensity: 0.35, metalness: 0.7, roughness: 0.28,
                model: translMtx(SIMD3(0, -4.02 + 11.5 / 2, 0)))
        let (pv, pi2) = makePyramid(base: 0.85, height: 1.6)
        addDraw(verts: pv, indices: pi2, albedo: gold, emissive: gold,
                emissiveIntensity: 0.65, metalness: 0.7, roughness: 0.20,
                model: translMtx(SIMD3(0, 6.75, 0)))
        obeliskRange = obeliskStart..<draws.count

        // ── Kardashev scale rings (Type I, II, III) ──────────────────────────
        let kStart = draws.count
        let kDefs: [(Float, Float, SIMD3<Float>, Float, SIMD3<Float>, simd_float4x4)] = [
            (6.5, 0.12, SIMD3(0.90, 0.70, 0.20), 0.55,
             SIMD3(0, -2, -5), rotXMtx(0.20) * rotZMtx(0.10)),
            (14,  0.10, SIMD3(1.0,  0.82, 0.35), 0.42,
             SIMD3(0, -1, -5), rotXMtx(0.15) * rotZMtx(0.05)),
            (24,  0.08, SIMD3(0.68, 0.84, 1.0),  0.30,
             SIMD3(0,  0, -5), rotXMtx(0.10) * rotZMtx(0.08)),
        ]
        let kSpeeds: [Float] = [0.032, 0.020, 0.012]
        for (i, kd) in kDefs.enumerated() {
            let (ringR, pipeR, col, emitInt, center, tilt) = kd
            let (ktv, kti) = makeTorus(ringR: ringR, pipeR: pipeR, ringSegs: 48, pipeSegs: 8)
            kardashevBasePos.append(center)
            kardashevTilt.append(tilt)
            kardashevRotSpeed.append(kSpeeds[i])
            addDraw(verts: ktv, indices: kti, albedo: col, emissive: col,
                    emissiveIntensity: emitInt, metalness: 0, roughness: 1,
                    isEmissive: true, model: translMtx(center) * tilt)
        }
        kardashevRange = kStart..<draws.count

        // ── 18 species nodes along a quadratic Bézier arc ────────────────────
        let speciesStart = draws.count
        let p0 = SIMD3<Float>(-9, 1, -5)
        let p1 = SIMD3<Float>(0,  6, -12)
        let p2 = SIMD3<Float>(9,  0, -4)
        var rngS = SplitMix64(seed: 777)
        let speciesColors: [SIMD3<Float>] = [
            SIMD3(0.38, 0.72, 0.95), SIMD3(0.48, 0.76, 0.88), SIMD3(0.60, 0.80, 0.76),
            SIMD3(0.70, 0.82, 0.60), SIMD3(0.80, 0.84, 0.48), SIMD3(0.90, 0.82, 0.38),
            SIMD3(0.96, 0.76, 0.30), SIMD3(0.97, 0.70, 0.26), SIMD3(0.95, 0.62, 0.26),
            SIMD3(0.92, 0.54, 0.30), SIMD3(0.88, 0.48, 0.38), SIMD3(0.80, 0.46, 0.52),
            SIMD3(0.70, 0.50, 0.68), SIMD3(0.60, 0.52, 0.82), SIMD3(0.52, 0.60, 0.92),
            SIMD3(0.48, 0.68, 0.97), SIMD3(0.44, 0.74, 1.00), SIMD3(0.40, 0.80, 1.00),
        ]
        let (spv, spi) = makeSphere(rings: 6, sectors: 8)   // low-poly, faceted feel
        for i in 0..<18 {
            let t = Float(i) / 17.0
            let pos = bezier3(t: t, p0: p0, p1: p1, p2: p2)
            speciesBasePos.append(pos)
            speciesBaseY.append(pos.y)
            speciesBobPhases.append(Float(Double.random(in: 0...(2 * .pi), using: &rngS)))
            let col = speciesColors[i]
            addDraw(verts: spv, indices: spi, albedo: col, emissive: col,
                    emissiveIntensity: 0.8, metalness: 0, roughness: 1,
                    isEmissive: true,
                    model: translMtx(pos) * scaleMtx(SIMD3(0.24, 0.24, 0.24)))
        }
        speciesRange = speciesStart..<draws.count

        // ── 17 luminous filaments connecting adjacent species nodes ──────────
        let filStart = draws.count
        let (cv, ci) = makeCylinder(radius: 1, height: 1, segments: 10)
        for i in 0..<17 {
            let a = speciesBasePos[i]
            let b = speciesBasePos[i + 1]
            let blended = mix(speciesColors[i], speciesColors[i + 1], t: 0.5)
        let (model, _) = cylinderModelMatrix(from: a, to: b)
            addDraw(verts: cv, indices: ci, albedo: blended, emissive: blended,
                    emissiveIntensity: 0.32, metalness: 0, roughness: 1,
                    isEmissive: true, model: model)
        }
        filamentRange = filStart..<draws.count

        // ── Seed particles from Neptune (small emissive spheres) ─────────────
        var rngP = SplitMix64(seed: 3131)
        let neptune = worldDefs[2].pos
        let (ptsv, ptsi) = makeSphere(rings: 4, sectors: 6)
        for _ in 0..<30 {
            let r  = Float(Double.random(in: 1.5...4.0, using: &rngP))
            let th = Float(Double.random(in: 0...(2 * Float.pi), using: &rngP))
            let ph = Float(Double.random(in: -0.8...0.8, using: &rngP))
            let x  = neptune.x + r * cos(ph) * cos(th)
            let y  = neptune.y + r * sin(ph)
            let z  = neptune.z + r * cos(ph) * sin(th)
            let sc = Float(Double.random(in: 0.04...0.12, using: &rngP))
            let ic = SIMD3<Float>(0.52, 0.74, 1.0)
            addDraw(verts: ptsv, indices: ptsi, albedo: ic, emissive: ic,
                    emissiveIntensity: 1.4, metalness: 0, roughness: 1,
                    isEmissive: true,
                    model: translMtx(SIMD3(x, y, z)) * scaleMtx(SIMD3(sc, sc, sc)))
        }
    }

    // ── Lights ────────────────────────────────────────────────────────────────

    private func buildLights() {
        // 0: warm sun — bright overhead omni
        lights.append(LFMLight(
            position: SIMD4(0, 22, 8, 55),
            color:    SIMD4(1.0, 0.95, 0.80, 1.8)))
        // 1: Earth fill
        lights.append(LFMLight(
            position: SIMD4(-9, 1, -5, 14),
            color:    SIMD4(0.40, 0.75, 0.95, 0.7)))
        // 2: Venus fill
        lights.append(LFMLight(
            position: SIMD4(0, 2, -9, 18),
            color:    SIMD4(1.0, 0.85, 0.45, 0.6)))
        // 3: Neptune fill
        lights.append(LFMLight(
            position: SIMD4(9, 0, -4, 16),
            color:    SIMD4(0.55, 0.78, 1.0, 0.7)))
        // 4: obelisk top
        lights.append(LFMLight(
            position: SIMD4(0, 8, 0, 9),
            color:    SIMD4(0.90, 0.70, 0.25, 0.9)))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Animation
    // ═══════════════════════════════════════════════════════════════════════════

    private func update(time t: Double) {
        let tf = Float(t)

        // Worlds — slow Y rotation
        for i in 0..<3 {
            let wi = worldInfo[i]
            let angle = tf * wi.rotSpeed
            let s = wi.radius
            draws[worldRange.startIndex + i].modelMatrix =
                translMtx(wi.pos) * rotYMtx(angle) * scaleMtx(SIMD3(s, s, s))
        }

        // Civilisation rings — orbit around their world
        for i in 0..<3 {
            let angle = tf * civRingRotSpeed[i]
            draws[civRingRange.startIndex + i].modelMatrix =
                translMtx(worldInfo[i].pos) * rotYMtx(angle) * civRingTilt[i]
        }

        // Sunburst rings + spokes — slow drift
        for i in 0..<4 {
            let drift = tf * 0.04
            let m = translMtx(sunPos[i]) * rotYMtx(drift) *
                    scaleMtx(SIMD3(1, 1, 1))
            draws[sunRingRange.startIndex + i].modelMatrix   = m
            draws[sunSpokeRange.startIndex + i].modelMatrix  = m
        }

        // Obelisk cap — gentle emissive pulse
        let capIdx = obeliskRange.startIndex + 4
        let capPulse = 0.65 + 0.28 * sin(Double(t) * 1.05)
        draws[capIdx].emissiveIntensity = Float(capPulse)

        // Kardashev rings — rotate around their centre + tilt
        for i in 0..<3 {
            let angle = tf * kardashevRotSpeed[i]
            draws[kardashevRange.startIndex + i].modelMatrix =
                translMtx(kardashevBasePos[i]) * rotYMtx(angle) * kardashevTilt[i]
            // Gentle pulse
            let pulse = Float(kardashevRotSpeed[i] > 0.025
                ? 0.55 + 0.20 * sin(Double(t) * 0.95)
                : (kardashevRotSpeed[i] > 0.018
                   ? 0.42 + 0.15 * sin(Double(t) * 0.70)
                   : 0.30 + 0.10 * sin(Double(t) * 0.55)))
            draws[kardashevRange.startIndex + i].emissiveIntensity = pulse
        }

        // Species nodes — bob + rotate + tap boost
        for i in 0..<18 {
            let bob   = 0.20 * sin(Double(t) * 0.63 + Double(speciesBobPhases[i]))
            let angle = tf * (0.38 + Float(i) * 0.018)
            let pos   = speciesBasePos[i]
            let s: Float = 0.24
            draws[speciesRange.startIndex + i].modelMatrix =
                translMtx(SIMD3(pos.x, speciesBaseY[i] + Float(bob), pos.z)) *
                rotYMtx(angle) * scaleMtx(SIMD3(s, s, s))
            draws[speciesRange.startIndex + i].emissiveIntensity =
                0.8 + speciesTapBoosts[i]
        }

        // Kardashev ring boost on tap
        for i in 0..<3 {
            let boost = speciesTapBoosts.max() ?? 0
            if boost > 0.1 {
                let base: Float = [0.55, 0.42, 0.30][i]
                draws[kardashevRange.startIndex + i].emissiveIntensity =
                    base + boost * 0.6
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Camera — 5-phase 120-second art film loop
    // ═══════════════════════════════════════════════════════════════════════════

    private func cameraState(time t: Double) -> (simd_float4x4, SIMD4<Float>) {
        let loop = t.truncatingRemainder(dividingBy: 120.0)

        func ss(_ raw: Double) -> Double {
            let x = max(0, min(1, raw)); return x * x * (3 - 2 * x)
        }

        let eye: SIMD3<Float>
        let tgt: SIMD3<Float>
        let fovY: Float

        if loop < 25 {
            // Phase 1: intimate close-up on Earth — the First Men
            let f = ss(loop / 25.0)
            eye  = SIMD3(Float(-9.0 + f * 2.5), Float(3.5 - f * 1.0), Float(4.5 - f * 2.5))
            tgt  = SIMD3(-9, 1, -5)
            fovY = Float((54 + f * 2) * .pi / 180)
        } else if loop < 50 {
            // Phase 2: grand pull-back — all three worlds revealed
            let f = ss((loop - 25) / 25.0)
            eye  = SIMD3(Float(-6.5 + f * 6.5), Float(2.5 + f * 5.5), Float(2.0 + f * 9.0))
            tgt  = SIMD3(0, 1, -6)
            fovY = Float((54 + f * 10) * .pi / 180)
        } else if loop < 75 {
            // Phase 3: slow orbit — the arc of 18 species
            let f = ss((loop - 50) / 25.0)
            let angle = f * .pi * 1.4
            eye  = SIMD3(Float(15 * sin(angle)), Float(8 + 2 * sin(angle * 0.35)),
                          Float(11 + 4 * cos(angle)))
            tgt  = SIMD3(0, 2, -6)
            fovY = Float(62 * .pi / 180)
        } else if loop < 100 {
            // Phase 4: drift toward Neptune — the Last Men, long farewell
            let f = ss((loop - 75) / 25.0)
            let orbitX = Float(15 * sin(.pi * 1.4))
            let orbitZ = Float(11 + 4 * cos(.pi * 1.4))
            eye  = SIMD3(orbitX * Float(1 - f) + 3.0 * Float(f),
                          Float(10 * (1 - f) + 2.5 * f),
                          orbitZ * Float(1 - f) + 2.0 * Float(f))
            tgt  = SIMD3(9, 0, -4)
            fovY = Float((62 - f * 10) * .pi / 180)
        } else {
            // Phase 5: ascend to cosmic — all three Kardashev rings visible
            let f = ss((loop - 100) / 20.0)
            eye  = SIMD3(Float(3 * (1 - f)), Float(2.5 * (1 - f) + 22 * f),
                          Float(2 * (1 - f) + 24 * f))
            tgt  = SIMD3(0, 0, -5)
            fovY = Float((52 + f * 22) * .pi / 180)
        }

        let view = lookAtMtx(eye: eye, center: tgt, up: SIMD3(0, 1, 0))
        let proj = perspectiveMtx(fovY: fovY, aspect: aspectRatio, near: 0.1, far: 120)
        return (proj * view, SIMD4(eye.x, eye.y, eye.z, Float(t)))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Render Passes
    // ═══════════════════════════════════════════════════════════════════════════

    private func gBufferPass(cmdBuf: MTLCommandBuffer,
                              vp: simd_float4x4, camPos: SIMD4<Float>,
                              depth: MTLTexture,
                              albedo: MTLTexture, normal: MTLTexture,
                              position: MTLTexture) {
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture   = albedo
        rpd.colorAttachments[0].loadAction  = .clear
        rpd.colorAttachments[0].storeAction = .store
        rpd.colorAttachments[0].clearColor  = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        rpd.colorAttachments[1].texture   = normal
        rpd.colorAttachments[1].loadAction  = .clear
        rpd.colorAttachments[1].storeAction = .store
        rpd.colorAttachments[1].clearColor  = MTLClearColor(red: 0.5, green: 0.5, blue: 1, alpha: 0.5)
        rpd.colorAttachments[2].texture   = position
        rpd.colorAttachments[2].loadAction  = .clear
        rpd.colorAttachments[2].storeAction = .store
        rpd.colorAttachments[2].clearColor  = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        rpd.depthAttachment.texture        = depth
        rpd.depthAttachment.loadAction     = .clear
        rpd.depthAttachment.storeAction    = .dontCare
        rpd.depthAttachment.clearDepth     = 1.0

        guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }
        enc.setRenderPipelineState(gBufferPSO)
        enc.setDepthStencilState(dss)
        enc.setCullMode(.none)

        for draw in draws {
            var uni = LFMUniforms(
                modelMatrix: draw.modelMatrix,
                vpMatrix:    vp,
                cameraPos:   camPos,
                emissive:    SIMD4(draw.emissive.x, draw.emissive.y,
                                   draw.emissive.z, draw.emissiveIntensity),
                material:    SIMD4(draw.metalness, draw.roughness,
                                   draw.isEmissive ? 1 : 0, 0))
            enc.setVertexBuffer(draw.vtxBuf, offset: 0, index: 0)
            enc.setVertexBytes(&uni,  length: MemoryLayout<LFMUniforms>.size, index: 1)
            enc.setFragmentBytes(&uni, length: MemoryLayout<LFMUniforms>.size, index: 1)
            enc.drawIndexedPrimitives(type: .triangle,
                                       indexCount: draw.indexCount,
                                       indexType: .uint32,
                                       indexBuffer: draw.idxBuf,
                                       indexBufferOffset: 0)
        }
        enc.endEncoding()
    }

    private func lightingPass(cmdBuf: MTLCommandBuffer,
                               hdr: MTLTexture, camPos: SIMD4<Float>,
                               albedo: MTLTexture, normal: MTLTexture,
                               position: MTLTexture) {
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture   = hdr
        rpd.colorAttachments[0].loadAction  = .clear
        rpd.colorAttachments[0].storeAction = .store
        rpd.colorAttachments[0].clearColor  = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }
        enc.setRenderPipelineState(lightingPSO)

        var duni = makeDeferredUniforms(camPos: camPos)
        enc.setFragmentBytes(&duni, length: MemoryLayout<LFMDeferredUniforms>.size, index: 0)
        enc.setFragmentTexture(albedo,   index: 0)
        enc.setFragmentTexture(normal,   index: 1)
        enc.setFragmentTexture(position, index: 2)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
    }

    private func bloomPass(cmdBuf: MTLCommandBuffer,
                            hdr: MTLTexture, b0: MTLTexture, b1: MTLTexture) {
        guard bloomThreshPSO != nil, bloomBlurHPSO != nil, bloomBlurVPSO != nil,
              viewSize.width > 0 else { return }
        let w = Int(viewSize.width), h = Int(viewSize.height)
        let tg  = MTLSize(width: 16, height: 16, depth: 1)
        let cnt = MTLSize(width: (w + 15) / 16, height: (h + 15) / 16, depth: 1)

        guard let enc = cmdBuf.makeComputeCommandEncoder() else { return }

        enc.setComputePipelineState(bloomThreshPSO)
        enc.setTexture(hdr, index: 0)
        enc.setTexture(b0,  index: 1)
        enc.dispatchThreadgroups(cnt, threadsPerThreadgroup: tg)

        enc.setComputePipelineState(bloomBlurHPSO)
        enc.setTexture(b0, index: 0)
        enc.setTexture(b1, index: 1)
        enc.dispatchThreadgroups(cnt, threadsPerThreadgroup: tg)

        enc.setComputePipelineState(bloomBlurVPSO)
        enc.setTexture(b1, index: 0)
        enc.setTexture(b0, index: 1)
        enc.dispatchThreadgroups(cnt, threadsPerThreadgroup: tg)

        enc.endEncoding()
    }

    private func compositePass(cmdBuf: MTLCommandBuffer,
                                drawable: CAMetalDrawable,
                                hdr: MTLTexture, bloom: MTLTexture) {
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture   = drawable.texture
        rpd.colorAttachments[0].loadAction  = .dontCare
        rpd.colorAttachments[0].storeAction = .store

        guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }
        enc.setRenderPipelineState(compositePSO)
        enc.setFragmentTexture(hdr,   index: 0)
        enc.setFragmentTexture(bloom, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Deferred Uniforms Helper
    // ═══════════════════════════════════════════════════════════════════════════

    private func makeDeferredUniforms(camPos: SIMD4<Float>) -> LFMDeferredUniforms {
        let pad = (lights.count < 6
            ? [LFMLight](repeating: LFMLight(position: .zero, color: .zero),
                          count: 6 - lights.count)
            : [])
        let all = lights + pad
        return LFMDeferredUniforms(
            cameraPos:        camPos,
            lights:           (all[0], all[1], all[2], all[3], all[4],
                               lights.count > 5 ? all[5] : LFMLight(position: .zero, color: .zero)),
            lightCount:       Int32(min(lights.count, 6)),
            ambientIntensity: 0.055,
            _pad:             .zero)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Geometry Builders
    // ═══════════════════════════════════════════════════════════════════════════

    private func addDraw(verts: [LFMVertex], indices: [UInt32],
                          albedo: SIMD3<Float> = .zero,
                          emissive: SIMD3<Float> = .zero, emissiveIntensity: Float = 0,
                          metalness: Float = 0.1, roughness: Float = 0.6,
                          isEmissive: Bool = false,
                          model: simd_float4x4 = matrix_identity_float4x4) {
        guard let vb = device.makeBuffer(
                bytes: verts,
                length: verts.count * MemoryLayout<LFMVertex>.stride,
                options: .storageModeShared),
              let ib = device.makeBuffer(
                bytes: indices,
                length: indices.count * MemoryLayout<UInt32>.stride,
                options: .storageModeShared) else { return }
        draws.append(LFMDrawCall(vtxBuf: vb, idxBuf: ib,
                                  indexCount: indices.count,
                                  albedo: albedo, emissive: emissive,
                                  emissiveIntensity: emissiveIntensity,
                                  metalness: metalness, roughness: roughness,
                                  isEmissive: isEmissive, modelMatrix: model))
    }

    // UV sphere, radius = 1.0
    private func makeSphere(rings: Int, sectors: Int) -> ([LFMVertex], [UInt32]) {
        var v: [LFMVertex] = []; var i: [UInt32] = []
        for ring in 0...rings {
            let phi = Float.pi * Float(ring) / Float(rings)
            let y = cos(phi); let r = sin(phi)
            for sec in 0...sectors {
                let theta = 2 * Float.pi * Float(sec) / Float(sectors)
                let x = r * cos(theta), z = r * sin(theta)
                v.append(LFMVertex(px: x, py: y, pz: z,
                                   nx: x, ny: y, nz: z,
                                   r: 1, g: 1, b: 1, a: 1))
            }
        }
        for ring in 0..<rings {
            for sec in 0..<sectors {
                let i0 = UInt32(ring * (sectors + 1) + sec)
                let i1 = i0 + 1
                let i2 = i0 + UInt32(sectors + 1)
                let i3 = i2 + 1
                i += [i0, i2, i1, i1, i2, i3]
            }
        }
        return (v, i)
    }

    // Box with per-face normals
    private func makeBox(w: Float, h: Float, d: Float) -> ([LFMVertex], [UInt32]) {
        let hw = w/2, hh = h/2, hd = d/2
        var v: [LFMVertex] = []; var idx: [UInt32] = []
        func face(_ pts: [(Float,Float,Float)], _ n: (Float,Float,Float)) {
            let fi = UInt32(v.count)
            for (x,y,z) in pts {
                v.append(LFMVertex(px:x,py:y,pz:z, nx:n.0,ny:n.1,nz:n.2, r:1,g:1,b:1,a:1))
            }
            idx += [fi,fi+1,fi+2, fi+1,fi+3,fi+2]
        }
        face([(-hw,hh,-hd),(hw,hh,-hd),(-hw,hh,hd),(hw,hh,hd)],   (0, 1,0))
        face([(-hw,-hh,hd),(hw,-hh,hd),(-hw,-hh,-hd),(hw,-hh,-hd)],(0,-1,0))
        face([(-hw,-hh,hd),(hw,-hh,hd),(-hw,hh,hd),(hw,hh,hd)],    (0,0, 1))
        face([(hw,-hh,-hd),(-hw,-hh,-hd),(hw,hh,-hd),(-hw,hh,-hd)],(0,0,-1))
        face([(hw,-hh,hd),(hw,-hh,-hd),(hw,hh,hd),(hw,hh,-hd)],    ( 1,0,0))
        face([(-hw,-hh,-hd),(-hw,-hh,hd),(-hw,hh,-hd),(-hw,hh,hd)],(-1,0,0))
        return (v, idx)
    }

    // Torus: ring in xz plane, pipe cross-section in yz
    private func makeTorus(ringR: Float, pipeR: Float,
                            ringSegs: Int, pipeSegs: Int) -> ([LFMVertex], [UInt32]) {
        var v: [LFMVertex] = []; var i: [UInt32] = []
        for rs in 0...ringSegs {
            let theta = 2 * Float.pi * Float(rs) / Float(ringSegs)
            let ct = cos(theta), st = sin(theta)
            for ps in 0...pipeSegs {
                let phi = 2 * Float.pi * Float(ps) / Float(pipeSegs)
                let cp = cos(phi), sp = sin(phi)
                let x = (ringR + pipeR * cp) * ct
                let y = pipeR * sp
                let z = (ringR + pipeR * cp) * st
                v.append(LFMVertex(px:x,py:y,pz:z, nx:cp*ct,ny:sp,nz:cp*st, r:1,g:1,b:1,a:1))
            }
        }
        for rs in 0..<ringSegs {
            for ps in 0..<pipeSegs {
                let i0 = UInt32(rs * (pipeSegs+1) + ps)
                let i1 = i0+1, i2 = i0+UInt32(pipeSegs+1), i3 = i2+1
                i += [i0,i2,i1, i1,i2,i3]
            }
        }
        return (v, i)
    }

    // Open-ended cylinder: radius 1, height 1, centred at origin
    private func makeCylinder(radius: Float, height: Float,
                               segments: Int) -> ([LFMVertex], [UInt32]) {
        var v: [LFMVertex] = []; var i: [UInt32] = []
        let hy = height / 2
        for s in 0...segments {
            let theta = 2 * Float.pi * Float(s) / Float(segments)
            let ct = cos(theta), st = sin(theta)
            let x = radius * ct, z = radius * st
            v.append(LFMVertex(px:x,py:-hy,pz:z, nx:ct,ny:0,nz:st, r:1,g:1,b:1,a:1))
            v.append(LFMVertex(px:x,py: hy,pz:z, nx:ct,ny:0,nz:st, r:1,g:1,b:1,a:1))
        }
        for s in 0..<segments {
            let i0 = UInt32(s*2)
            i += [i0,i0+2,i0+1, i0+1,i0+2,i0+3]
        }
        return (v, i)
    }

    // Pyramid with square base (base centred at origin, apex at (0,height,0))
    private func makePyramid(base: Float, height: Float) -> ([LFMVertex], [UInt32]) {
        let h = base/2
        var v: [LFMVertex] = []; var i: [UInt32] = []
        let apex = SIMD3<Float>(0, height, 0)
        let corners: [SIMD3<Float>] = [
            SIMD3(-h,0,-h), SIMD3(h,0,-h), SIMD3(h,0,h), SIMD3(-h,0,h)
        ]
        func tri(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
            let n = simd_normalize(simd_cross(b-a, c-a))
            let fi = UInt32(v.count)
            for p in [a,b,c] {
                v.append(LFMVertex(px:p.x,py:p.y,pz:p.z, nx:n.x,ny:n.y,nz:n.z, r:1,g:1,b:1,a:1))
            }
            i += [fi,fi+1,fi+2]
        }
        // Base (two triangles, wound outward — down)
        tri(corners[0], corners[2], corners[1])
        tri(corners[0], corners[3], corners[2])
        // Four side faces
        for k in 0..<4 { tri(corners[k], corners[(k+1)%4], apex) }
        return (v, i)
    }

    // Sunburst spokes: 12 flat thin rectangles in the xz plane
    private func makeSunburstSpokes(outerR: Float, innerR: Float,
                                     spokes: Int) -> ([LFMVertex], [UInt32]) {
        var v: [LFMVertex] = []; var i: [UInt32] = []
        let w: Float = 0.022
        for s in 0..<spokes {
            let angle = Float(s) / Float(spokes) * 2 * Float.pi
            let ct = cos(angle), st = sin(angle)
            let perp = SIMD3<Float>(-st, 0, ct)
            let base = SIMD3<Float>(innerR*ct, 0, innerR*st)
            let tip  = SIMD3<Float>(outerR*ct, 0, outerR*st)
            let pts  = [base - perp*(w/2), base + perp*(w/2),
                        tip  - perp*(w/2), tip  + perp*(w/2)]
            for side in [SIMD3<Float>(0,1,0), SIMD3<Float>(0,-1,0)] {
                let fi = UInt32(v.count)
                for p in pts {
                    v.append(LFMVertex(px:p.x,py:p.y,pz:p.z,
                                       nx:side.x,ny:side.y,nz:side.z, r:1,g:1,b:1,a:1))
                }
                i += [fi,fi+1,fi+2, fi+1,fi+3,fi+2]
            }
        }
        return (v, i)
    }

    // 1×1 quad (for stars) lying in xz plane
    private func makeQuad(size: Float) -> ([LFMVertex], [UInt32]) {
        let h = size/2
        return ([
            LFMVertex(px:-h,py:0,pz:-h, nx:0,ny:1,nz:0, r:1,g:1,b:1,a:1),
            LFMVertex(px: h,py:0,pz:-h, nx:0,ny:1,nz:0, r:1,g:1,b:1,a:1),
            LFMVertex(px:-h,py:0,pz: h, nx:0,ny:1,nz:0, r:1,g:1,b:1,a:1),
            LFMVertex(px: h,py:0,pz: h, nx:0,ny:1,nz:0, r:1,g:1,b:1,a:1),
        ], [0,1,2, 1,3,2])
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Matrix Helpers (right-handed world, Metal NDC z in [0,1])
    // ═══════════════════════════════════════════════════════════════════════════

    private func perspectiveMtx(fovY: Float, aspect: Float,
                                  near: Float, far: Float) -> simd_float4x4 {
        let y = 1.0 / tan(fovY * 0.5)
        let x = y / aspect
        return simd_float4x4(columns: (
            SIMD4(x,   0,              0,             0),
            SIMD4(0,   y,              0,             0),
            SIMD4(0,   0, far/(near-far),            -1),
            SIMD4(0,   0, near*far/(near-far),         0)))
    }

    private func lookAtMtx(eye: SIMD3<Float>, center: SIMD3<Float>,
                             up: SIMD3<Float>) -> simd_float4x4 {
        let f = simd_normalize(eye - center)        // view-space -Z (camera looks toward -f)
        let r = simd_normalize(simd_cross(up, f))   // view-space +X
        let u = simd_cross(f, r)                    // view-space +Y
        return simd_float4x4(columns: (
            SIMD4(r.x, u.x, f.x, 0),
            SIMD4(r.y, u.y, f.y, 0),
            SIMD4(r.z, u.z, f.z, 0),
            SIMD4(-simd_dot(r,eye), -simd_dot(u,eye), -simd_dot(f,eye), 1)))
    }

    private func translMtx(_ t: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4(t.x, t.y, t.z, 1)
        return m
    }

    private func scaleMtx(_ s: SIMD3<Float>) -> simd_float4x4 {
        simd_float4x4(diagonal: SIMD4(s.x, s.y, s.z, 1))
    }

    private func rotYMtx(_ a: Float) -> simd_float4x4 {
        let c = cos(a), s = sin(a)
        return simd_float4x4(columns: (
            SIMD4( c, 0,-s, 0), SIMD4(0,1,0,0),
            SIMD4( s, 0, c, 0), SIMD4(0,0,0,1)))
    }

    private func rotXMtx(_ a: Float) -> simd_float4x4 {
        let c = cos(a), s = sin(a)
        return simd_float4x4(columns: (
            SIMD4(1,0,0,0), SIMD4(0, c, s,0),
            SIMD4(0,-s,c,0), SIMD4(0,0,0,1)))
    }

    private func rotZMtx(_ a: Float) -> simd_float4x4 {
        let c = cos(a), s = sin(a)
        return simd_float4x4(columns: (
            SIMD4(c,s,0,0), SIMD4(-s,c,0,0),
            SIMD4(0,0,1,0), SIMD4(0,0,0,1)))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - Misc Helpers
    // ═══════════════════════════════════════════════════════════════════════════

    // Quadratic Bézier point
    private func bezier3(t: Float, p0: SIMD3<Float>,
                          p1: SIMD3<Float>, p2: SIMD3<Float>) -> SIMD3<Float> {
        let mt = 1 - t
        return mt*mt*p0 + 2*mt*t*p1 + t*t*p2
    }

    // Build a cylinder model matrix that aligns the cylinder's Y axis with (b - a)
    private func cylinderModelMatrix(from a: SIMD3<Float>,
                                      to b: SIMD3<Float>) -> (simd_float4x4, Float) {
        let delta  = b - a
        let length = simd_length(delta)
        let mid    = (a + b) * 0.5
        guard length > 0.001 else { return (translMtx(mid), length) }

        let dir  = delta / length
        let up   = SIMD3<Float>(0, 1, 0)
        // Rotation from up to dir
        let axis = simd_normalize(simd_cross(up, dir))
        let dot  = simd_dot(up, dir)
        let angle = acos(max(-1, min(1, dot)))

        let rot: simd_float4x4
        if simd_length(axis) < 0.001 {
            // Parallel or anti-parallel
            rot = dot > 0 ? matrix_identity_float4x4 : rotZMtx(Float.pi)
        } else {
            // Rodrigues rotation
            let a2 = axis, c = cos(angle), s = sin(angle), t2 = 1 - c
            rot = simd_float4x4(columns: (
                SIMD4(t2*a2.x*a2.x+c,     t2*a2.x*a2.y+s*a2.z, t2*a2.x*a2.z-s*a2.y, 0),
                SIMD4(t2*a2.x*a2.y-s*a2.z, t2*a2.y*a2.y+c,     t2*a2.y*a2.z+s*a2.x, 0),
                SIMD4(t2*a2.x*a2.z+s*a2.y, t2*a2.y*a2.z-s*a2.x, t2*a2.z*a2.z+c,     0),
                SIMD4(0,0,0,1)))
        }
        let r: Float = 0.016
        return (translMtx(mid) * rot * scaleMtx(SIMD3(r, length, r)), length)
    }

    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        a * (1 - t) + b * t
    }
}
