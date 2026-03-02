import SwiftUI

// Voyager Nebula — drifting through a stellar nursery.
// Enormous soft gas curtains in muted teals, mauves, and ambers drift slowly.
// Dim stars peek through veils. A few brighter cores pulse with gentle HDR glow.
// Mostly negative space and atmosphere. Tap sends a faint illumination ripple.

struct VoyagerNebulaScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data types

    struct GasCloudData {
        let cx, cy: Double
        let radiusX, radiusY: Double   // separate axes for oblong shapes
        let r, g, b: Double
        let driftX, driftY: Double
        let phase: Double
        let opacity: Double
        let depth: Int                 // 0=far, 1=mid, 2=near
    }

    struct StarData {
        let x, y: Double
        let brightness: Double
        let size: Double
        let twinkleRate, twinklePhase: Double
        let warmth: Double
    }

    struct CoreData {
        let cx, cy: Double
        let r, g, b: Double
        let pulseRate, pulsePhase: Double
        let size: Double               // normalised
    }

    struct RippleData: Identifiable {
        let id = UUID()
        let x, y, birth: Double
    }

    @State private var gasClouds: [GasCloudData] = []
    @State private var stars: [StarData] = []
    @State private var cores: [CoreData] = []
    @State private var ripples: [RippleData] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawBackground(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawGasClouds(ctx: &ctx, size: size, t: t, depth: 0)
                drawGasClouds(ctx: &ctx, size: size, t: t, depth: 1)
                drawCores(ctx: &ctx, size: size, t: t)
                drawGasClouds(ctx: &ctx, size: size, t: t, depth: 2)
                drawRipples(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: generate)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            ripples.append(RippleData(x: loc.x, y: loc.y,
                                      birth: Date().timeIntervalSince(startDate)))
            if ripples.count > 6 { ripples.removeFirst() }
        }
    }

    // MARK: - Generate

    private func generate() {
        var rng = SplitMix64(seed: 4747)

        // Muted, desaturated palette — more natural gas cloud colours
        let palette: [(Double, Double, Double)] = [
            (0.20, 0.45, 0.55),   // muted teal
            (0.55, 0.22, 0.42),   // dusty mauve
            (0.60, 0.40, 0.18),   // amber haze
            (0.35, 0.22, 0.50),   // dim violet
            (0.50, 0.30, 0.35),   // muted rose
            (0.22, 0.38, 0.55),   // slate blue
            (0.45, 0.42, 0.22),   // faded gold
            (0.25, 0.48, 0.38),   // seafoam grey
        ]

        // Fewer clouds, more irregular shapes, lower opacity
        gasClouds = (0..<16).map { i in
            let (cr, cg, cb) = palette[i % palette.count]
            let depth = i < 5 ? 0 : (i < 11 ? 1 : 2)
            return GasCloudData(
                cx: Double.random(in: -0.15...1.15, using: &rng),
                cy: Double.random(in: -0.15...1.15, using: &rng),
                radiusX: Double.random(in: 0.10...0.35, using: &rng),
                radiusY: Double.random(in: 0.06...0.25, using: &rng),
                r: cr + Double.random(in: -0.08...0.08, using: &rng),
                g: cg + Double.random(in: -0.08...0.08, using: &rng),
                b: cb + Double.random(in: -0.08...0.08, using: &rng),
                driftX: Double.random(in: -0.0015...0.0015, using: &rng),
                driftY: Double.random(in: -0.001...0.001, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng),
                opacity: Double.random(in: 0.06...0.18, using: &rng),
                depth: depth
            )
        }

        // Plentiful dim stars
        stars = (0..<350).map { _ in
            StarData(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng),
                brightness: Double.random(in: 0.08...0.65, using: &rng),
                size: Double.random(in: 0.3...1.8, using: &rng),
                twinkleRate: Double.random(in: 0.2...0.9, using: &rng),
                twinklePhase: Double.random(in: 0...(.pi * 2), using: &rng),
                warmth: Double.random(in: 0...1, using: &rng)
            )
        }

        // Just 3 subtle cores — small, gentle glow
        cores = (0..<3).map { _ in
            let (cr, cg, cb) = palette[Int.random(in: 0..<palette.count, using: &rng)]
            return CoreData(
                cx: Double.random(in: 0.15...0.85, using: &rng),
                cy: Double.random(in: 0.15...0.85, using: &rng),
                r: min(cr + 0.25, 1.0),
                g: min(cg + 0.25, 1.0),
                b: min(cb + 0.25, 1.0),
                pulseRate: Double.random(in: 0.08...0.18, using: &rng),
                pulsePhase: Double.random(in: 0...(.pi * 2), using: &rng),
                size: Double.random(in: 0.005...0.012, using: &rng)
            )
        }

        ready = true
    }

    // MARK: - Background

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cycle = sin(t * 0.015) * 0.5 + 0.5
        let r1 = 0.012 + cycle * 0.015
        let g1 = 0.006 + (1 - cycle) * 0.01
        let b1 = 0.025 + cycle * 0.015

        ctx.fill(
            Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: r1, green: g1, blue: b1),
                    Color(red: r1 * 0.7, green: g1 * 1.2, blue: b1 * 1.3),
                    Color(red: r1 * 1.3, green: g1 * 0.7, blue: b1 * 0.8),
                ]),
                startPoint: CGPoint(x: size.width * (0.3 + sin(t * 0.006) * 0.2), y: 0),
                endPoint: CGPoint(x: size.width * (0.7 + cos(t * 0.008) * 0.2), y: size.height)
            )
        )
    }

    // MARK: - Stars

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for s in stars {
            let twinkle = (sin(t * s.twinkleRate + s.twinklePhase) + 1.0) * 0.5
            let alpha = s.brightness * (twinkle * 0.25 + 0.75)
            let x = s.x * size.width
            let y = s.y * size.height
            let sz = s.size * (0.9 + twinkle * 0.1)

            let w = s.warmth
            let sr = 0.85 + w * 0.15
            let sg = 0.82 + w * 0.08
            let sb = 1.0 - w * 0.2

            let rect = CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)
            ctx.fill(Ellipse().path(in: rect),
                     with: .color(Color(red: sr, green: sg, blue: sb).opacity(alpha)))
        }
    }

    // MARK: - Gas clouds — painted in a single blur layer per depth

    private func drawGasClouds(ctx: inout GraphicsContext, size: CGSize, t: Double, depth: Int) {
        let clouds = gasClouds.filter { $0.depth == depth }
        guard !clouds.isEmpty else { return }

        ctx.drawLayer { layerCtx in
            layerCtx.addFilter(.blur(radius: size.width * 0.10))

            for cloud in clouds {
                let x = (cloud.cx + sin(t * 0.03 + cloud.phase) * 0.02
                         + t * cloud.driftX) * size.width
                let y = (cloud.cy + cos(t * 0.025 + cloud.phase) * 0.015
                         + t * cloud.driftY) * size.height

                let breathe = sin(t * 0.06 + cloud.phase) * 0.04 + 1.0
                let rx = cloud.radiusX * size.width * breathe
                let ry = cloud.radiusY * size.height * breathe
                let color = Color(red: cloud.r, green: cloud.g, blue: cloud.b)

                // One large soft ellipse per cloud — no sub-ellipse loops
                let rect = CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2)
                layerCtx.fill(
                    Ellipse().path(in: rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            color.opacity(cloud.opacity),
                            color.opacity(cloud.opacity * 0.4),
                            color.opacity(cloud.opacity * 0.08),
                            .clear
                        ]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: max(rx, ry)
                    )
                )
            }
        }
    }

    // MARK: - Stellar cores — small gentle glowing points, no spikes

    private func drawCores(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Soft halo layer
        ctx.drawLayer { layerCtx in
            layerCtx.addFilter(.blur(radius: size.width * 0.025))
            for core in cores {
                let pulse = sin(t * core.pulseRate + core.pulsePhase) * 0.12 + 1.0
                let x = core.cx * size.width
                let y = core.cy * size.height
                let coreR = core.size * max(size.width, size.height) * pulse
                let bright = 1.1 * pulse
                let coreColor = Color(red: core.r * bright,
                                      green: core.g * bright,
                                      blue: core.b * bright)

                // Outer halo
                let haloR = coreR * 5
                let haloRect = CGRect(x: x - haloR, y: y - haloR,
                                      width: haloR * 2, height: haloR * 2)
                layerCtx.fill(
                    Ellipse().path(in: haloRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            coreColor.opacity(0.18),
                            coreColor.opacity(0.04),
                            .clear
                        ]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: haloR
                    )
                )
            }
        }

        // Hard bright dots
        for core in cores {
            let pulse = sin(t * core.pulseRate + core.pulsePhase) * 0.12 + 1.0
            let x = core.cx * size.width
            let y = core.cy * size.height
            let coreR = core.size * max(size.width, size.height) * pulse
            let bright = 1.15 * pulse
            let coreColor = Color(red: core.r * bright,
                                  green: core.g * bright,
                                  blue: core.b * bright)

            let dotR = coreR * 0.6
            let dotRect = CGRect(x: x - dotR, y: y - dotR,
                                 width: dotR * 2, height: dotR * 2)
            ctx.fill(Ellipse().path(in: dotRect), with: .color(coreColor))
        }
    }

    // MARK: - Tap ripples — gentle expanding ring of light

    private func drawRipples(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let active = ripples.filter { t - $0.birth < 8.0 }
        guard !active.isEmpty else { return }

        for ripple in active {
            let age = t - ripple.birth
            let p = age / 8.0

            // Stellar core flash
            let coreFade = age < 0.4 ? age / 0.4 : max(0, 1.0 - (age - 0.4) / 2.5)
            if coreFade > 0 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 25 + p * 40))
                    let r = 20 + p * 50
                    l.fill(Ellipse().path(in: CGRect(x: ripple.x - r, y: ripple.y - r,
                                                     width: r * 2, height: r * 2)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1.6, green: 1.4, blue: 1.8).opacity(0.35 * coreFade),
                                Color(red: 1.0, green: 0.8, blue: 1.3).opacity(0.12 * coreFade),
                                .clear
                            ]),
                            center: CGPoint(x: ripple.x, y: ripple.y),
                            startRadius: 0, endRadius: r))
                }
            }

            // 3 color band rings: amber → teal → violet
            let bands: [(r: Double, g: Double, b: Double, delay: Double)] = [
                (1.3, 0.9, 0.4, 0.0),
                (0.3, 1.1, 0.9, 0.5),
                (0.7, 0.4, 1.2, 1.0),
            ]
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 12))
                for band in bands {
                    let bandAge = age - band.delay
                    guard bandAge > 0 else { continue }
                    let bp = min(bandAge / 6.0, 1.0)
                    let bandFade = max(0, 1.0 - bp)
                    let scale = max(size.width, size.height)
                    let radius = bp * scale * 0.3
                    let rect = CGRect(x: ripple.x - radius, y: ripple.y - radius,
                                     width: radius * 2, height: radius * 2)
                    l.stroke(Ellipse().path(in: rect),
                        with: .color(Color(red: band.r, green: band.g, blue: band.b)
                            .opacity(bandFade * 0.18)),
                        lineWidth: 2.5 - bp * 1.5)
                }
            }

            // Wispy tendrils curving outward
            let seed = UInt64(ripple.birth * 1000) & 0xFFFFFF
            var rng = SplitMix64(seed: seed)
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 8))
                for _ in 0..<10 {
                    let baseAngle = nextDouble(&rng) * .pi * 2
                    let curveBias = (nextDouble(&rng) - 0.5) * 1.5
                    let tendrilSpeed = nextDouble(&rng) * 0.6 + 0.4
                    let lifespan = nextDouble(&rng) * 3.5 + 4.0
                    guard age < lifespan else { continue }
                    let tp = age / lifespan
                    let tendrilFade = tp < 0.15 ? tp / 0.15 : max(0, 1.0 - (tp - 0.15) / 0.85)
                    let len = tp * tendrilSpeed * 140

                    var path = Path()
                    path.move(to: CGPoint(x: ripple.x, y: ripple.y))
                    let steps = 8
                    for s in 1...steps {
                        let sf = Double(s) / Double(steps)
                        let dist = sf * len
                        let angle = baseAngle + sf * curveBias
                        let wx = ripple.x + cos(angle) * dist
                        let wy = ripple.y + sin(angle) * dist
                        path.addLine(to: CGPoint(x: wx, y: wy))
                    }

                    let warmth = nextDouble(&rng)
                    let col = warmth > 0.5
                        ? Color(red: 0.5, green: 0.8, blue: 1.2)
                        : Color(red: 0.8, green: 0.5, blue: 1.1)
                    l.stroke(path, with: .color(col.opacity(tendrilFade * 0.15)),
                        lineWidth: 2.0 * tendrilFade)

                    // Bright tip particle
                    let tipDist = tp * tendrilSpeed * 140
                    let tipAngle = baseAngle + curveBias
                    let tx = ripple.x + cos(tipAngle) * tipDist
                    let ty = ripple.y + sin(tipAngle) * tipDist
                    let tipS = 3.0 * tendrilFade
                    l.fill(Ellipse().path(in: CGRect(x: tx - tipS, y: ty - tipS,
                                                     width: tipS * 2, height: tipS * 2)),
                        with: .color(Color(red: 1.3, green: 1.2, blue: 1.5).opacity(tendrilFade * 0.4)))
                }
            }
        }
    }
}
