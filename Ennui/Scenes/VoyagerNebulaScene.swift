import SwiftUI

// Voyager Nebula — the beautiful, vivid nebulae from Star Trek: Voyager.
// Enormous gas clouds in teals, magentas, ambers, and violets swirl slowly.
// Bright stellar nursery cores pulse with HDR bloom. Dust lanes snake through.
// Distant stars peek between gas curtains. Tap sends a shockwave that
// momentarily illuminates hidden structure. Pure Canvas, 60fps, no blur abuse.

struct VoyagerNebulaScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data types

    struct GasCloudData {
        let cx, cy: Double           // normalised centre
        let radius: Double           // normalised
        let r, g, b: Double          // base colour
        let driftX, driftY: Double   // drift speed
        let phase: Double            // animation offset
        let density: Double          // 0.2..0.8
        let layerDepth: Int          // 0=far, 1=mid, 2=near
    }

    struct DustLaneData {
        let startX, startY: Double
        let endX, endY: Double
        let thickness: Double
        let opacity: Double
        let curl: Double
    }

    struct StellarCoreData {
        let cx, cy: Double
        let brightness: Double       // HDR multiplier
        let r, g, b: Double
        let pulseRate: Double
        let pulsePhase: Double
        let coreSize: Double
    }

    struct BackgroundStarData {
        let x, y: Double
        let brightness: Double
        let size: Double
        let twinkleRate, twinklePhase: Double
        let warmth: Double
    }

    struct ShockwaveData: Identifiable {
        let id = UUID()
        let x, y, birth: Double
    }

    @State private var gasClouds: [GasCloudData] = []
    @State private var dustLanes: [DustLaneData] = []
    @State private var stellarCores: [StellarCoreData] = []
    @State private var stars: [BackgroundStarData] = []
    @State private var shockwaves: [ShockwaveData] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawDeepBackground(ctx: &ctx, size: size, t: t)
                drawBackgroundStars(ctx: &ctx, size: size, t: t)
                drawFarGasClouds(ctx: &ctx, size: size, t: t)
                drawDustLanes(ctx: &ctx, size: size, t: t)
                drawMidGasClouds(ctx: &ctx, size: size, t: t)
                drawStellarCores(ctx: &ctx, size: size, t: t)
                drawNearGasClouds(ctx: &ctx, size: size, t: t)
                drawGodRays(ctx: &ctx, size: size, t: t)
                drawShockwaves(ctx: &ctx, size: size, t: t)
                drawViewscreenFrame(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            shockwaves.append(ShockwaveData(x: loc.x, y: loc.y,
                                            birth: Date().timeIntervalSince(startDate)))
            if shockwaves.count > 5 { shockwaves.removeFirst() }
        }
    }

    // MARK: - Setup

    private func setup() {
        var rng = SplitMix64(seed: 4747)

        // Voyager-palette gas clouds: teals, magentas, amber, violet, rose
        let palette: [(Double, Double, Double)] = [
            (0.15, 0.65, 0.75),  // teal
            (0.80, 0.20, 0.55),  // magenta
            (0.90, 0.55, 0.15),  // amber
            (0.50, 0.25, 0.75),  // violet
            (0.85, 0.35, 0.40),  // rose
            (0.25, 0.50, 0.85),  // cerulean
            (0.70, 0.70, 0.25),  // gold
            (0.30, 0.75, 0.50),  // seafoam
            (0.60, 0.15, 0.80),  // deep purple
        ]

        gasClouds = (0..<22).map { i in
            let (cr, cg, cb) = palette[i % palette.count]
            let depth = i < 7 ? 0 : (i < 15 ? 1 : 2)
            return GasCloudData(
                cx: nextDouble(&rng) * 1.4 - 0.2,
                cy: nextDouble(&rng) * 1.4 - 0.2,
                radius: 0.10 + nextDouble(&rng) * 0.30,
                r: cr + (nextDouble(&rng) - 0.5) * 0.15,
                g: cg + (nextDouble(&rng) - 0.5) * 0.15,
                b: cb + (nextDouble(&rng) - 0.5) * 0.15,
                driftX: (nextDouble(&rng) - 0.5) * 0.003,
                driftY: (nextDouble(&rng) - 0.5) * 0.002,
                phase: nextDouble(&rng) * .pi * 2,
                density: 0.15 + nextDouble(&rng) * 0.45,
                layerDepth: depth
            )
        }

        dustLanes = (0..<8).map { _ in
            DustLaneData(
                startX: nextDouble(&rng) * 0.3,
                startY: nextDouble(&rng),
                endX: 0.7 + nextDouble(&rng) * 0.3,
                endY: nextDouble(&rng),
                thickness: 0.02 + nextDouble(&rng) * 0.04,
                opacity: 0.25 + nextDouble(&rng) * 0.35,
                curl: (nextDouble(&rng) - 0.5) * 0.15
            )
        }

        stellarCores = (0..<5).map { _ in
            let (cr, cg, cb) = palette[Int(nextDouble(&rng) * Double(palette.count)) % palette.count]
            return StellarCoreData(
                cx: 0.15 + nextDouble(&rng) * 0.7,
                cy: 0.15 + nextDouble(&rng) * 0.7,
                brightness: 1.3 + nextDouble(&rng) * 0.8,
                r: min(cr + 0.3, 1.0),
                g: min(cg + 0.3, 1.0),
                b: min(cb + 0.3, 1.0),
                pulseRate: 0.15 + nextDouble(&rng) * 0.2,
                pulsePhase: nextDouble(&rng) * .pi * 2,
                coreSize: 0.01 + nextDouble(&rng) * 0.02
            )
        }

        stars = (0..<250).map { _ in
            BackgroundStarData(
                x: nextDouble(&rng),
                y: nextDouble(&rng),
                brightness: nextDouble(&rng) * 0.7 + 0.1,
                size: 0.3 + nextDouble(&rng) * 2.0,
                twinkleRate: 0.3 + nextDouble(&rng) * 1.0,
                twinklePhase: nextDouble(&rng) * .pi * 2,
                warmth: nextDouble(&rng)
            )
        }

        ready = true
    }

    // MARK: - Deep background — dark with subtle colour wash

    private func drawDeepBackground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Slowly cycling deep space wash
        let cycle = sin(t * 0.012) * 0.5 + 0.5
        let r1 = 0.015 + cycle * 0.02
        let g1 = 0.008 + (1 - cycle) * 0.015
        let b1 = 0.03 + cycle * 0.02

        ctx.fill(
            Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: r1, green: g1, blue: b1),
                    Color(red: r1 * 0.6, green: g1 * 1.3, blue: b1 * 1.5),
                    Color(red: r1 * 1.4, green: g1 * 0.8, blue: b1 * 0.7),
                ]),
                startPoint: CGPoint(x: size.width * (0.3 + sin(t * 0.008) * 0.2), y: 0),
                endPoint: CGPoint(x: size.width * (0.7 + cos(t * 0.01) * 0.2), y: size.height)
            )
        )
    }

    // MARK: - Background stars — dim, twinkling behind gas

    private func drawBackgroundStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for s in stars {
            let twinkle = (sin(t * s.twinkleRate + s.twinklePhase) + 1.0) * 0.5
            let alpha = s.brightness * (twinkle * 0.3 + 0.7)
            let x = s.x * size.width
            let y = s.y * size.height
            let sz = s.size * (0.85 + twinkle * 0.15)

            let w = s.warmth
            let sr = (0.85 + w * 0.15)
            let sg = (0.82 + w * 0.08)
            let sb = (1.0 - w * 0.2)

            let rect = CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)
            ctx.fill(Ellipse().path(in: rect),
                     with: .color(Color(red: sr, green: sg, blue: sb).opacity(alpha)))
        }
    }

    // MARK: - Gas clouds (by layer)

    private func drawGasCloudLayer(ctx: inout GraphicsContext, size: CGSize, t: Double, depth: Int) {
        for cloud in gasClouds where cloud.layerDepth == depth {
            let x = (cloud.cx + sin(t * 0.05 + cloud.phase) * 0.03
                     + t * cloud.driftX) * size.width
            let y = (cloud.cy + cos(t * 0.04 + cloud.phase) * 0.025
                     + t * cloud.driftY) * size.height

            let breathe = sin(t * 0.08 + cloud.phase) * 0.06 + 1.0
            let baseR = cloud.radius * max(size.width, size.height) * breathe

            let color = Color(red: cloud.r, green: cloud.g, blue: cloud.b)

            // Multiple overlapping ellipses for organic shape
            for sub in 0..<4 {
                let angle = Double(sub) / 4.0 * .pi * 2 + cloud.phase
                let offsetX = cos(angle + t * 0.02) * baseR * 0.25
                let offsetY = sin(angle + t * 0.015) * baseR * 0.2
                let subR = baseR * (0.6 + Double(sub) * 0.12)

                let sx = x + offsetX
                let sy = y + offsetY

                let rect = CGRect(x: sx - subR, y: sy - subR * 0.7,
                                 width: subR * 2, height: subR * 1.4)

                ctx.drawLayer { layerCtx in
                    layerCtx.addFilter(.blur(radius: subR * 0.35))
                    layerCtx.opacity = cloud.density * 0.25
                    layerCtx.fill(
                        Ellipse().path(in: rect),
                        with: .radialGradient(
                            Gradient(colors: [
                                color.opacity(0.8),
                                color.opacity(0.35),
                                color.opacity(0.08),
                                .clear
                            ]),
                            center: CGPoint(x: sx, y: sy),
                            startRadius: 0,
                            endRadius: subR * 0.8
                        )
                    )
                }
            }

            // Bright inner edge — HDR glow
            let innerR = baseR * 0.2
            let innerRect = CGRect(x: x - innerR, y: y - innerR,
                                   width: innerR * 2, height: innerR * 2)
            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: innerR * 0.6))
                layerCtx.opacity = cloud.density * 0.12
                let hdrColor = Color(red: min(cloud.r * 1.5, 1.5),
                                     green: min(cloud.g * 1.5, 1.5),
                                     blue: min(cloud.b * 1.5, 1.5))
                layerCtx.fill(Ellipse().path(in: innerRect), with: .color(hdrColor))
            }
        }
    }

    private func drawFarGasClouds(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        drawGasCloudLayer(ctx: &ctx, size: size, t: t, depth: 0)
    }

    private func drawMidGasClouds(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        drawGasCloudLayer(ctx: &ctx, size: size, t: t, depth: 1)
    }

    private func drawNearGasClouds(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        drawGasCloudLayer(ctx: &ctx, size: size, t: t, depth: 2)
    }

    // MARK: - Dust lanes — dark ribbons snaking through the nebula

    private func drawDustLanes(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for lane in dustLanes {
            let sx = lane.startX * size.width
            let sy = lane.startY * size.height
            let ex = lane.endX * size.width
            let ey = lane.endY * size.height
            let thick = lane.thickness * size.height

            // Curving path
            let midX = (sx + ex) / 2 + lane.curl * size.width + sin(t * 0.03) * 20
            let midY = (sy + ey) / 2 + lane.curl * size.height * 0.5

            var path = Path()
            path.move(to: CGPoint(x: sx, y: sy))
            path.addQuadCurve(to: CGPoint(x: ex, y: ey),
                              control: CGPoint(x: midX, y: midY))

            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: thick * 0.5))
                layerCtx.stroke(path, with: .color(.black.opacity(lane.opacity)),
                                lineWidth: thick)
            }
        }
    }

    // MARK: - Stellar cores — bright HDR points with blooming light

    private func drawStellarCores(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for core in stellarCores {
            let pulse = sin(t * core.pulseRate + core.pulsePhase) * 0.15 + 1.0
            let x = core.cx * size.width
            let y = core.cy * size.height
            let coreR = core.coreSize * max(size.width, size.height) * pulse

            let hdrBright = core.brightness * pulse
            let coreColor = Color(red: core.r * hdrBright,
                                  green: core.g * hdrBright,
                                  blue: core.b * hdrBright)

            // Wide glow halo
            let haloR = coreR * 6
            let haloRect = CGRect(x: x - haloR, y: y - haloR,
                                  width: haloR * 2, height: haloR * 2)
            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: haloR * 0.4))
                layerCtx.fill(
                    Ellipse().path(in: haloRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            coreColor.opacity(0.35),
                            coreColor.opacity(0.08),
                            .clear
                        ]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: haloR
                    )
                )
            }

            // Medium glow
            let midR = coreR * 2.5
            let midRect = CGRect(x: x - midR, y: y - midR,
                                 width: midR * 2, height: midR * 2)
            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: midR * 0.3))
                layerCtx.fill(Ellipse().path(in: midRect),
                              with: .color(coreColor.opacity(0.5)))
            }

            // Hard bright core
            let coreRect = CGRect(x: x - coreR, y: y - coreR,
                                  width: coreR * 2, height: coreR * 2)
            ctx.fill(Ellipse().path(in: coreRect), with: .color(coreColor))

            // Spike cross (lens flare feel — Voyager style)
            for angle in [0.0, Double.pi / 2] {
                let spikeLen = coreR * 4 * pulse
                var spike = Path()
                spike.move(to: CGPoint(x: x - cos(angle) * spikeLen,
                                       y: y - sin(angle) * spikeLen))
                spike.addLine(to: CGPoint(x: x + cos(angle) * spikeLen,
                                          y: y + sin(angle) * spikeLen))
                ctx.stroke(spike, with: .color(coreColor.opacity(0.25)),
                           lineWidth: 1.0)
            }
        }
    }

    // MARK: - God rays — sweeping light beams from stellar cores

    private func drawGodRays(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        guard let brightest = stellarCores.max(by: { $0.brightness < $1.brightness }) else { return }
        let cx = brightest.cx * size.width
        let cy = brightest.cy * size.height

        for i in 0..<6 {
            let baseAngle = Double(i) / 6.0 * .pi * 2
            let angle = baseAngle + t * 0.008 + sin(t * 0.03 + Double(i)) * 0.15
            let rayLen = max(size.width, size.height) * 0.6
            let spread = 0.04 + sin(t * 0.1 + Double(i) * 1.5) * 0.02

            var path = Path()
            path.move(to: CGPoint(x: cx, y: cy))
            path.addLine(to: CGPoint(x: cx + cos(angle - spread) * rayLen,
                                     y: cy + sin(angle - spread) * rayLen))
            path.addLine(to: CGPoint(x: cx + cos(angle + spread) * rayLen,
                                     y: cy + sin(angle + spread) * rayLen))
            path.closeSubpath()

            let rayColor = Color(red: brightest.r * 0.5,
                                 green: brightest.g * 0.5,
                                 blue: brightest.b * 0.5)

            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: 25))
                layerCtx.fill(path, with: .color(rayColor.opacity(0.04)))
            }
        }
    }

    // MARK: - Tap shockwaves — expanding ring of illumination

    private func drawShockwaves(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for wave in shockwaves {
            let age = t - wave.birth
            guard age < 4.0 else { continue }
            let progress = age / 4.0
            let radius = progress * max(size.width, size.height) * 0.5
            let alpha = (1.0 - progress) * 0.3

            let color = Color(red: 0.5, green: 0.8, blue: 1.3)

            // Expanding ring
            let rect = CGRect(x: wave.x - radius, y: wave.y - radius,
                              width: radius * 2, height: radius * 2)
            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: 6 + progress * 15))
                layerCtx.stroke(Ellipse().path(in: rect),
                                with: .color(color.opacity(alpha)),
                                lineWidth: 3.0 - progress * 2.0)
            }

            // Inner brighter ring
            let r2 = radius * 0.7
            let rect2 = CGRect(x: wave.x - r2, y: wave.y - r2,
                               width: r2 * 2, height: r2 * 2)
            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: 4))
                layerCtx.stroke(Ellipse().path(in: rect2),
                                with: .color(color.opacity(alpha * 0.5)),
                                lineWidth: 1.5)
            }

            // Flash at centre (first 0.3s)
            if progress < 0.075 {
                let flashAlpha = (1.0 - progress / 0.075) * 0.5
                let flashR = 30.0 + progress * 100.0
                let flashRect = CGRect(x: wave.x - flashR, y: wave.y - flashR,
                                       width: flashR * 2, height: flashR * 2)
                ctx.drawLayer { layerCtx in
                    layerCtx.addFilter(.blur(radius: flashR * 0.5))
                    layerCtx.fill(Ellipse().path(in: flashRect),
                                  with: .color(Color(red: 0.8, green: 0.9, blue: 1.5).opacity(flashAlpha)))
                }
            }
        }
    }

    // MARK: - Viewscreen frame — subtle LCARS-ish border feel

    private func drawViewscreenFrame(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Very subtle rounded-corner darkening to suggest a starship viewscreen
        let inset: Double = 12
        let cornerR: Double = 28
        let frameRect = CGRect(x: inset, y: inset,
                              width: size.width - inset * 2, height: size.height - inset * 2)
        let framePath = RoundedRectangle(cornerRadius: cornerR).path(in: CGRect(origin: .zero, size: size))
        let innerPath = RoundedRectangle(cornerRadius: cornerR - 4).path(in: frameRect)

        // Dark border band
        ctx.drawLayer { layerCtx in
            layerCtx.clip(to: framePath)
            // Fill entire view with dark
            layerCtx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
                          with: .color(.black.opacity(0.12)))
            // Cut out inner — by drawing inner with clear blend mode
            layerCtx.blendMode = .destinationOut
            layerCtx.fill(innerPath, with: .color(.white))
        }

        // Faint edge highlight on inner border (teal tint — Federation feel)
        let edgeColor = Color(red: 0.3, green: 0.6, blue: 0.8)
        ctx.stroke(RoundedRectangle(cornerRadius: cornerR - 4).path(in: frameRect),
                   with: .color(edgeColor.opacity(0.06 + sin(t * 0.3) * 0.02)),
                   lineWidth: 0.8)
    }
}
