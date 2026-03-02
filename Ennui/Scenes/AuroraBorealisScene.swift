import SwiftUI

// Aurora Borealis — the northern lights dance over a frozen wilderness.
// Curtains of green and violet ripple across the sky using layered sine
// waves. A perfectly still frozen lake mirrors the aurora. Silhouetted
// pines line the horizon. A lone cabin sits on the far shore, warm
// golden light in a single window. Delicate ice crystals drift slowly.
// Stars poke through the aurora's thinner regions.
// Tap to send a bright solar flare pulse through the curtain.
// Pure Canvas, 60fps, no state mutation inside Canvas closure.

struct AuroraBorealisScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data

    struct PineTree {
        let x: Double          // normalised 0..1
        let height: Double     // normalised
        let width: Double      // normalised
        let depth: Double      // 0=far, 1=near (affects shade)
    }

    struct StarData {
        let x, y: Double
        let brightness: Double
        let size: Double
        let twinkleRate, twinklePhase: Double
    }

    struct IceCrystal {
        let x, y: Double       // normalised spawn position
        let size: Double
        let rotation: Double
        let driftX, driftY: Double
        let sparklePhase: Double
        let arms: Int          // 4 or 6
    }

    struct SolarFlare: Identifiable {
        let id = UUID()
        let x, birth: Double   // normalised x, time
    }

    @State private var trees: [PineTree] = []
    @State private var stars: [StarData] = []
    @State private var crystals: [IceCrystal] = []
    @State private var flares: [SolarFlare] = []
    @State private var ready = false
    @State private var viewSize: CGSize = CGSize(width: 1200, height: 800)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawAurora(ctx: &ctx, size: size, t: t)
                drawFlares(ctx: &ctx, size: size, t: t)
                drawDistantMountains(ctx: &ctx, size: size, t: t)
                drawLake(ctx: &ctx, size: size, t: t)
                drawAuroraReflection(ctx: &ctx, size: size, t: t)
                drawTrees(ctx: &ctx, size: size, t: t)
                drawCabin(ctx: &ctx, size: size, t: t)
                drawIceCrystals(ctx: &ctx, size: size, t: t)
                drawFrostOverlay(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in viewSize = newSize }
            }
        )
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            let nx = loc.x / max(viewSize.width, 1)
            flares.append(SolarFlare(x: nx, birth: t))
            if flares.count > 5 { flares.removeFirst() }
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !ready else { return }
        var rng = SplitMix64(seed: 0xA0B0C0D0)

        // Stars — only upper portion of sky
        for _ in 0..<200 {
            stars.append(StarData(
                x: rng.nextDouble(),
                y: rng.nextDouble() * 0.5,
                brightness: 0.3 + rng.nextDouble() * 0.7,
                size: 0.5 + rng.nextDouble() * 1.5,
                twinkleRate: 0.3 + rng.nextDouble() * 2.0,
                twinklePhase: rng.nextDouble() * .pi * 2
            ))
        }

        // Pine trees along the horizon
        for _ in 0..<60 {
            let depth = rng.nextDouble()
            trees.append(PineTree(
                x: rng.nextDouble(),
                height: (0.04 + rng.nextDouble() * 0.08) * (0.5 + depth * 0.5),
                width: (0.008 + rng.nextDouble() * 0.012) * (0.5 + depth * 0.5),
                depth: depth
            ))
        }

        // Floating ice crystals
        for _ in 0..<30 {
            crystals.append(IceCrystal(
                x: rng.nextDouble(),
                y: 0.1 + rng.nextDouble() * 0.8,
                size: 2.0 + rng.nextDouble() * 5.0,
                rotation: rng.nextDouble() * .pi * 2,
                driftX: (rng.nextDouble() - 0.5) * 0.01,
                driftY: -0.002 - rng.nextDouble() * 0.005,
                sparklePhase: rng.nextDouble() * .pi * 2,
                arms: rng.nextDouble() > 0.5 ? 6 : 4
            ))
        }

        ready = true
    }

    // MARK: - Drawing

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Deep dark sky gradient — near-black at top, dark teal near horizon
        let w = size.width, h = size.height
        let horizonY = h * 0.55
        let steps = 20
        for i in 0..<steps {
            let frac = Double(i) / Double(steps)
            let y0 = frac * horizonY
            let y1 = (frac + 1.0 / Double(steps)) * horizonY
            let r = 0.01 + frac * 0.03
            let g = 0.02 + frac * 0.06
            let b = 0.06 + frac * 0.1
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0 + 1)),
                with: .color(Color(red: r, green: g, blue: b))
            )
        }
    }

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for s in stars {
            let twinkle = sin(t * s.twinkleRate + s.twinklePhase) * 0.3 + 0.7
            let alpha = s.brightness * twinkle * 0.6
            let px = s.x * w
            let py = s.y * h
            let r = s.size * twinkle
            ctx.fill(
                Circle().path(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.85, green: 0.9, blue: 1.0).opacity(alpha))
            )
        }
    }

    private func drawAurora(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Multiple aurora curtains — layered sine wave ribbons
        let w = size.width, h = size.height
        let curtains: [(baseY: Double, color1: (Double, Double, Double), color2: (Double, Double, Double), speed: Double, amplitude: Double, freq: Double)] = [
            (0.18, (0.1, 0.9, 0.4), (0.05, 0.5, 0.3), 0.15, 0.06, 2.5),
            (0.22, (0.2, 0.8, 0.6), (0.1, 0.4, 0.5), 0.12, 0.05, 3.0),
            (0.15, (0.4, 0.3, 0.8), (0.3, 0.2, 0.6), 0.18, 0.04, 2.0),
            (0.25, (0.1, 0.7, 0.3), (0.05, 0.45, 0.25), 0.1,  0.07, 1.8),
        ]

        for curtain in curtains {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 20))
                let steps = 80
                let bandHeight = h * 0.12
                for i in 0..<steps {
                    let frac = Double(i) / Double(steps)
                    let x = frac * w
                    // Multi-octave displacement
                    let wave1 = sin(frac * curtain.freq * .pi * 2 + t * curtain.speed) * curtain.amplitude
                    let wave2 = sin(frac * curtain.freq * 1.7 * .pi * 2 - t * curtain.speed * 0.7) * curtain.amplitude * 0.5
                    let wave3 = sin(frac * curtain.freq * 3.1 * .pi * 2 + t * curtain.speed * 1.3) * curtain.amplitude * 0.25
                    let displacement = (wave1 + wave2 + wave3) * h

                    let cy = curtain.baseY * h + displacement

                    // Vertical brightness falloff within the band
                    let bandSteps = 8
                    for j in 0..<bandSteps {
                        let vf = Double(j) / Double(bandSteps)
                        let intensity = exp(-vf * 3.0) * 0.35
                        // Color interpolation between top and bottom
                        let rr = curtain.color1.0 + (curtain.color2.0 - curtain.color1.0) * vf
                        let gg = curtain.color1.1 + (curtain.color2.1 - curtain.color1.1) * vf
                        let bb = curtain.color1.2 + (curtain.color2.2 - curtain.color1.2) * vf
                        let colW = w / Double(steps) + 2
                        let colH = bandHeight / Double(bandSteps)
                        let rect = CGRect(x: x, y: cy + vf * bandHeight, width: colW, height: colH + 1)
                        layer.fill(
                            Path(rect),
                            with: .color(Color(red: rr * 1.5, green: gg * 1.5, blue: bb * 1.5).opacity(intensity))
                        )
                    }
                }
            }
        }
    }

    private func drawFlares(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for flare in flares {
            let age = t - flare.birth
            guard age < 4.0 else { continue }
            let progress = age / 4.0
            let alpha = (1.0 - progress) * 0.6
            let spread = progress * 0.3

            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 40 + progress * 60))
                let cx = flare.x * w
                let cy = h * 0.2
                let rx = w * (0.05 + spread)
                let ry = h * 0.15
                let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
                layer.fill(
                    Ellipse().path(in: rect),
                    with: .color(Color(red: 0.3, green: 1.2, blue: 0.5).opacity(alpha))
                )
            }
        }
    }

    private func drawDistantMountains(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let horizonY = h * 0.55

        // Two mountain ranges
        let ranges: [(seed: UInt64, yBase: Double, peakH: Double, shade: Double)] = [
            (0xABCD, 0.0, 0.12, 0.03),
            (0x1234, 0.0, 0.08, 0.05),
        ]

        for range in ranges {
            var rng = SplitMix64(seed: range.seed)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: horizonY))

            let segments = 40
            for i in 0...segments {
                let frac = Double(i) / Double(segments)
                let peakNoise = rng.nextDouble()
                let peak = range.peakH * (0.3 + peakNoise * 0.7)
                let x = frac * w
                let y = horizonY - peak * h + range.yBase * h
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.addLine(to: CGPoint(x: w, y: horizonY))
            path.addLine(to: CGPoint(x: 0, y: horizonY))
            path.closeSubpath()
            ctx.fill(path, with: .color(Color(red: range.shade, green: range.shade + 0.01, blue: range.shade + 0.03)))
        }
    }

    private func drawLake(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let horizonY = h * 0.55

        // Frozen lake — very dark, slightly reflective
        let lakeRect = CGRect(x: 0, y: horizonY, width: w, height: h - horizonY)
        ctx.fill(
            Path(lakeRect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.08),
                    Color(red: 0.01, green: 0.03, blue: 0.05),
                ]),
                startPoint: CGPoint(x: 0, y: horizonY),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        // Subtle ice cracks
        var rng = SplitMix64(seed: 0x1CE000)
        for _ in 0..<15 {
            let startX = rng.nextDouble() * w
            let startY = horizonY + rng.nextDouble() * (h - horizonY)
            var crack = Path()
            crack.move(to: CGPoint(x: startX, y: startY))
            let segs = 3 + Int(rng.nextDouble() * 4)
            var cx = startX, cy = startY
            for _ in 0..<segs {
                cx += (rng.nextDouble() - 0.5) * 40
                cy += rng.nextDouble() * 20
                crack.addLine(to: CGPoint(x: cx, y: cy))
            }
            ctx.stroke(crack, with: .color(Color(red: 0.15, green: 0.2, blue: 0.3).opacity(0.15)), lineWidth: 0.5)
        }
    }

    private func drawAuroraReflection(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let horizonY = h * 0.55

        // Faint reflection of aurora on the lake surface
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 30))
            let colors: [(Double, Double, Double, Double)] = [
                (0.1, 0.6, 0.3, 0.08),
                (0.3, 0.2, 0.5, 0.05),
                (0.1, 0.5, 0.25, 0.06),
            ]
            for (idx, c) in colors.enumerated() {
                let wave = sin(t * 0.1 + Double(idx) * 2.0) * 0.15
                let cx = (0.3 + Double(idx) * 0.2 + wave) * w
                let rx = w * 0.25
                let ry = (h - horizonY) * 0.4
                let cy = horizonY + ry * 0.5
                let rect = CGRect(x: cx - rx, y: cy - ry * 0.3, width: rx * 2, height: ry)
                layer.fill(
                    Ellipse().path(in: rect),
                    with: .color(Color(red: c.0, green: c.1, blue: c.2).opacity(c.3))
                )
            }
        }
    }

    private func drawTrees(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let horizonY = h * 0.55

        let sorted = trees.sorted { $0.depth < $1.depth }
        for tree in sorted {
            let shade = 0.01 + tree.depth * 0.02
            let baseX = tree.x * w
            let baseY = horizonY
            let treeH = tree.height * h
            let treeW = tree.width * w

            // Simple triangular pine silhouette
            var path = Path()
            path.move(to: CGPoint(x: baseX, y: baseY - treeH))
            path.addLine(to: CGPoint(x: baseX - treeW * 3, y: baseY))
            path.addLine(to: CGPoint(x: baseX + treeW * 3, y: baseY))
            path.closeSubpath()

            // Trunk
            let trunkW = treeW * 0.8
            let trunkH = treeH * 0.15
            path.addRect(CGRect(x: baseX - trunkW / 2, y: baseY - trunkH, width: trunkW, height: trunkH))

            ctx.fill(path, with: .color(Color(red: shade, green: shade, blue: shade + 0.01)))

            // Subtle snow on tips
            let snowY = baseY - treeH
            let snowR = treeW * 1.5
            ctx.fill(
                Ellipse().path(in: CGRect(x: baseX - snowR, y: snowY - snowR * 0.3, width: snowR * 2, height: snowR * 0.6)),
                with: .color(Color.white.opacity(0.08 + tree.depth * 0.04))
            )
        }
    }

    private func drawCabin(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let horizonY = h * 0.55
        let cabinX = w * 0.72
        let cabinW = w * 0.035
        let cabinH = h * 0.025
        let roofH = h * 0.02
        let baseY = horizonY

        // Cabin body — dark silhouette
        let bodyRect = CGRect(x: cabinX - cabinW / 2, y: baseY - cabinH, width: cabinW, height: cabinH)
        ctx.fill(Path(bodyRect), with: .color(Color(red: 0.03, green: 0.03, blue: 0.04)))

        // Roof — triangle
        var roof = Path()
        roof.move(to: CGPoint(x: cabinX, y: baseY - cabinH - roofH))
        roof.addLine(to: CGPoint(x: cabinX - cabinW * 0.65, y: baseY - cabinH))
        roof.addLine(to: CGPoint(x: cabinX + cabinW * 0.65, y: baseY - cabinH))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(red: 0.04, green: 0.04, blue: 0.05)))

        // Window — warm golden glow
        let winW = cabinW * 0.25
        let winH = cabinH * 0.45
        let winX = cabinX - winW * 0.5
        let winY = baseY - cabinH * 0.7
        let flicker = sin(t * 3.0) * 0.05 + sin(t * 7.3) * 0.03
        let brightness = 0.85 + flicker

        ctx.fill(
            Path(CGRect(x: winX, y: winY, width: winW, height: winH)),
            with: .color(Color(red: 1.0 * brightness, green: 0.7 * brightness, blue: 0.2 * brightness))
        )

        // Window glow halo
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            let glowR = cabinW * 0.8
            let rect = CGRect(x: cabinX - glowR, y: winY - glowR * 0.3, width: glowR * 2, height: glowR * 1.5)
            layer.fill(
                Ellipse().path(in: rect),
                with: .color(Color(red: 1.0, green: 0.65, blue: 0.15).opacity(0.12 * brightness))
            )
        }

        // Chimney smoke — wisps rising
        let chimneyX = cabinX + cabinW * 0.25
        let chimneyY = baseY - cabinH - roofH * 0.5
        for i in 0..<6 {
            let age = fmod(t * 0.3 + Double(i) * 0.4, 2.4)
            let rise = age * 30.0
            let drift = sin(t * 0.5 + Double(i)) * 8.0
            let alpha = max(0, 0.15 - age * 0.06)
            let r = 3.0 + age * 5.0
            let sx = chimneyX + drift
            let sy = chimneyY - rise
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: r))
                layer.fill(
                    Circle().path(in: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 0.5, green: 0.55, blue: 0.6).opacity(alpha))
                )
            }
        }
    }

    private func drawIceCrystals(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for crystal in crystals {
            let x = fmod(crystal.x + crystal.driftX * t + 1.0, 1.0) * w
            let y = fmod(crystal.y + crystal.driftY * t + 2.0, 1.0) * h
            let sparkle = sin(t * 2.0 + crystal.sparklePhase) * 0.3 + 0.7
            let alpha = 0.2 * sparkle
            let rot = crystal.rotation + t * 0.1

            let arms = crystal.arms
            let armLen = crystal.size
            for a in 0..<arms {
                let angle = rot + Double(a) / Double(arms) * .pi * 2
                let ex = x + cos(angle) * armLen
                let ey = y + sin(angle) * armLen
                var arm = Path()
                arm.move(to: CGPoint(x: x, y: y))
                arm.addLine(to: CGPoint(x: ex, y: ey))
                // Small branches
                let bx1 = x + cos(angle) * armLen * 0.5 + cos(angle + 0.6) * armLen * 0.3
                let by1 = y + sin(angle) * armLen * 0.5 + sin(angle + 0.6) * armLen * 0.3
                arm.move(to: CGPoint(x: x + cos(angle) * armLen * 0.5, y: y + sin(angle) * armLen * 0.5))
                arm.addLine(to: CGPoint(x: bx1, y: by1))
                ctx.stroke(arm, with: .color(Color.white.opacity(alpha)), lineWidth: 0.5)
            }
        }
    }

    private func drawFrostOverlay(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        // Subtle frost vignette along edges — icy blue tinge
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 60))
            let edgeWidth = 80.0
            // Top edge
            layer.fill(
                Path(CGRect(x: 0, y: 0, width: w, height: edgeWidth)),
                with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.04))
            )
            // Bottom edge
            layer.fill(
                Path(CGRect(x: 0, y: h - edgeWidth, width: w, height: edgeWidth)),
                with: .color(Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.06))
            )
            // Side edges
            layer.fill(
                Path(CGRect(x: 0, y: 0, width: edgeWidth, height: h)),
                with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.03))
            )
            layer.fill(
                Path(CGRect(x: w - edgeWidth, y: 0, width: edgeWidth, height: h)),
                with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.03))
            )
        }
    }
}
