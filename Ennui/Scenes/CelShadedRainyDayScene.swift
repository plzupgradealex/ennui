import SwiftUI

// Cel-shaded rainy day — PS1/N64 low-poly aesthetic meets Parappa the Rapper
// and Jet Set Radio Future. Miffy-simple shapes, dark grey clouds rolling,
// bright flowers thriving in the rain, fat raindrops landing on petals and
// leaves, dripping down into little puddles. All geometry is flat-shaded
// with hard outlines — no blur, no smooth gradients — pure cel.

struct CelShadedRainyDayScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data types (all pure, no mutation in Canvas)

    struct FlowerData {
        let x, y: Double          // normalised 0..1
        let petalR, petalG, petalB: Double
        let leafG: Double         // shade of green
        let stemH: Double         // stem height in px
        let size: Double          // petal radius
        let swayPhase: Double
        let swayAmp: Double
        let petalCount: Int       // 4-6, Miffy-simple
        let leafSide: Double      // -1 or 1
    }

    struct CloudData {
        let y: Double             // normalised
        let w, h: Double          // normalised
        let speed: Double         // normalised/sec
        let shade: Double         // 0.15..0.35 grey
        let xOffset: Double       // starting offset
    }

    struct PuddleData {
        let cx, cy: Double        // normalised
        let rx, ry: Double        // radii normalised
        let shade: Double
    }

    struct Bloom: Identifiable {
        let id = UUID()
        let x, y, birth: Double
    }

    struct RainBurst {
        let birth: Double
        let x: Double
    }

    @State private var flowers: [FlowerData] = []
    @State private var clouds: [CloudData] = []
    @State private var puddles: [PuddleData] = []
    @State private var blooms: [Bloom] = []
    @State private var rainBursts: [RainBurst] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawClouds(ctx: &ctx, size: size, t: t)
                drawDistantHills(ctx: &ctx, size: size, t: t)
                drawGround(ctx: &ctx, size: size, t: t)
                drawPuddles(ctx: &ctx, size: size, t: t)
                drawPuddleRipples(ctx: &ctx, size: size, t: t)
                drawFlowerStems(ctx: &ctx, size: size, t: t)
                drawFlowerLeaves(ctx: &ctx, size: size, t: t)
                drawFlowerPetals(ctx: &ctx, size: size, t: t)
                drawDropletsOnPetals(ctx: &ctx, size: size, t: t)
                drawPixieDust(ctx: &ctx, size: size, t: t)
                drawBlooms(ctx: &ctx, size: size, t: t)
                drawRain(ctx: &ctx, size: size, t: t)
                drawCelOutlineOverlay(ctx: &ctx, size: size, t: t)
            }
        }
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            blooms.append(Bloom(x: loc.x, y: loc.y, birth: t))
            if blooms.count > 8 { blooms.removeFirst() }
            // Rain burst — heavier rain near tap + puddle shimmer
            rainBursts.append(RainBurst(birth: t, x: loc.x))
            if rainBursts.count > 4 { rainBursts.removeFirst() }
        }
    }

    // MARK: - Setup (deterministic RNG)

    private func setup() {
        var rng = SplitMix64(seed: 9933)

        // Bright Miffy palette
        let petalPalette: [(Double, Double, Double)] = [
            (1.0, 0.30, 0.35),   // cherry red
            (1.0, 0.85, 0.15),   // sunflower yellow
            (0.30, 0.55, 1.0),   // cornflower blue
            (1.0, 0.50, 0.80),   // bubblegum pink
            (1.0, 0.60, 0.20),   // warm orange
            (0.85, 0.40, 0.95),  // violet
            (0.95, 0.95, 0.95),  // white daisies
        ]

        flowers = (0..<55).map { _ in
            let (pr, pg, pb) = petalPalette[Int(nextDouble(&rng) * Double(petalPalette.count)) % petalPalette.count]
            return FlowerData(
                x: nextDouble(&rng) * 0.9 + 0.05,
                y: nextDouble(&rng) * 0.25 + 0.65,   // lower 35% of screen
                petalR: pr, petalG: pg, petalB: pb,
                leafG: 0.35 + nextDouble(&rng) * 0.25,
                stemH: 30.0 + nextDouble(&rng) * 60.0,
                size: 6.0 + nextDouble(&rng) * 10.0,
                swayPhase: nextDouble(&rng) * .pi * 2,
                swayAmp: 2.0 + nextDouble(&rng) * 4.0,
                petalCount: 4 + Int(nextDouble(&rng) * 3),
                leafSide: nextDouble(&rng) > 0.5 ? 1.0 : -1.0
            )
        }

        clouds = (0..<10).map { _ in
            CloudData(
                y: nextDouble(&rng) * 0.18 + 0.03,
                w: 0.15 + nextDouble(&rng) * 0.25,
                h: 0.04 + nextDouble(&rng) * 0.04,
                speed: 0.008 + nextDouble(&rng) * 0.015,
                shade: 0.15 + nextDouble(&rng) * 0.18,
                xOffset: nextDouble(&rng)
            )
        }

        puddles = (0..<12).map { _ in
            PuddleData(
                cx: nextDouble(&rng) * 0.85 + 0.075,
                cy: nextDouble(&rng) * 0.12 + 0.86,
                rx: 0.03 + nextDouble(&rng) * 0.05,
                ry: 0.008 + nextDouble(&rng) * 0.012,
                shade: 0.25 + nextDouble(&rng) * 0.1
            )
        }

        ready = true
    }

    // MARK: - Sky — flat cel bands, dark grey

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let bands = 5
        let bandH = size.height * 0.6 / Double(bands)
        for i in 0..<bands {
            let frac = Double(i) / Double(bands)
            let grey = 0.32 - frac * 0.12   // darker at top
            let y = Double(i) * bandH
            let r = CGRect(x: 0, y: y, width: size.width, height: bandH + 1)
            ctx.fill(Rectangle().path(in: r), with: .color(Color(red: grey * 0.85, green: grey * 0.88, blue: grey)))
        }
        // Fill rest below sky
        let restY = Double(bands) * bandH
        let restR = CGRect(x: 0, y: restY, width: size.width, height: size.height - restY)
        ctx.fill(Rectangle().path(in: restR), with: .color(Color(red: 0.22, green: 0.28, blue: 0.20)))
    }

    // MARK: - Clouds — big blocky dark grey masses, cel-shaded

    private func drawClouds(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for c in clouds {
            let x = fmod(c.xOffset + t * c.speed + 1.0, 1.4) - 0.2
            let cx = x * size.width
            let cy = c.y * size.height
            let w = c.w * size.width
            let h = c.h * size.height

            // Flat blocky cloud — 3 overlapping rounded rects (PS1 style)
            let grey = c.shade
            let darkGrey = Color(red: grey * 0.75, green: grey * 0.78, blue: grey * 0.82)
            let mainGrey = Color(red: grey * 0.85, green: grey * 0.88, blue: grey * 0.92)

            // Shadow layer
            let sr = CGRect(x: cx - w * 0.45, y: cy + h * 0.15, width: w, height: h * 0.8)
            ctx.fill(RoundedRectangle(cornerRadius: h * 0.3).path(in: sr), with: .color(darkGrey))

            // Main body
            let mr = CGRect(x: cx - w * 0.5, y: cy - h * 0.2, width: w, height: h)
            ctx.fill(RoundedRectangle(cornerRadius: h * 0.35).path(in: mr), with: .color(mainGrey))

            // Top bump
            let tr = CGRect(x: cx - w * 0.2, y: cy - h * 0.55, width: w * 0.5, height: h * 0.65)
            ctx.fill(RoundedRectangle(cornerRadius: h * 0.3).path(in: tr), with: .color(mainGrey))

            // Hard black outline (cel edge)
            ctx.stroke(RoundedRectangle(cornerRadius: h * 0.35).path(in: mr),
                       with: .color(.black.opacity(0.5)), lineWidth: 1.5)
            ctx.stroke(RoundedRectangle(cornerRadius: h * 0.3).path(in: tr),
                       with: .color(.black.opacity(0.4)), lineWidth: 1.0)
        }
    }

    // MARK: - Distant hills — flat stepped silhouettes

    private func drawDistantHills(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Two layers of rolling hills
        for layer in 0..<2 {
            let baseY = size.height * (0.48 + Double(layer) * 0.08)
            let amp = size.height * (0.04 + Double(layer) * 0.02)
            let freq = 2.5 + Double(layer) * 1.5
            let grey = 0.20 + Double(layer) * 0.06
            let hillColor = Color(red: grey * 0.8, green: grey, blue: grey * 0.7)

            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            let steps = 60
            for s in 0...steps {
                let frac = Double(s) / Double(steps)
                let x = frac * size.width
                // Stepped — quantise to nearest 4px
                let rawY = baseY - sin(frac * .pi * freq + Double(layer) * 1.7) * amp
                    - cos(frac * .pi * freq * 0.6 + 2.0) * amp * 0.4
                let steppedY = floor(rawY / 4.0) * 4.0
                path.addLine(to: CGPoint(x: x, y: steppedY))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
            ctx.fill(path, with: .color(hillColor))

            // Cel outline on top edge
            var outline = Path()
            for s in 0...steps {
                let frac = Double(s) / Double(steps)
                let x = frac * size.width
                let rawY = baseY - sin(frac * .pi * freq + Double(layer) * 1.7) * amp
                    - cos(frac * .pi * freq * 0.6 + 2.0) * amp * 0.4
                let steppedY = floor(rawY / 4.0) * 4.0
                if s == 0 { outline.move(to: CGPoint(x: x, y: steppedY)) }
                else { outline.addLine(to: CGPoint(x: x, y: steppedY)) }
            }
            ctx.stroke(outline, with: .color(.black.opacity(0.35)), lineWidth: 1.5)
        }
    }

    // MARK: - Ground — flat green with cel shading bands

    private func drawGround(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let groundTop = size.height * 0.62
        let bands = 4
        let bandH = (size.height - groundTop) / Double(bands)
        for i in 0..<bands {
            let frac = Double(i) / Double(bands)
            let g = 0.42 - frac * 0.08
            let r = 0.22 - frac * 0.04
            let b = 0.15 - frac * 0.03
            let rect = CGRect(x: 0, y: groundTop + Double(i) * bandH,
                              width: size.width, height: bandH + 1)
            ctx.fill(Rectangle().path(in: rect),
                     with: .color(Color(red: r, green: g, blue: b)))
        }
    }

    // MARK: - Puddles — flat ellipses with reflection tint

    private func drawPuddles(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for p in puddles {
            let cx = p.cx * size.width
            let cy = p.cy * size.height
            let rx = p.rx * size.width
            let ry = p.ry * size.height

            // Puddle body
            let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
            let puddleColor = Color(red: p.shade * 0.7, green: p.shade * 0.75, blue: p.shade)
            ctx.fill(Ellipse().path(in: rect), with: .color(puddleColor))

            // Sky reflection highlight — flat cel strip
            let highlightRect = CGRect(x: cx - rx * 0.6, y: cy - ry * 0.4,
                                       width: rx * 1.2, height: ry * 0.5)
            ctx.fill(Ellipse().path(in: highlightRect),
                     with: .color(Color(red: p.shade * 0.9, green: p.shade * 0.92, blue: p.shade * 1.1).opacity(0.5)))

            // Hard outline
            ctx.stroke(Ellipse().path(in: rect),
                       with: .color(.black.opacity(0.3)), lineWidth: 1.0)
        }
    }

    // MARK: - Puddle ripples — concentric circles from rain hitting

    private func drawPuddleRipples(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for (pi, p) in puddles.enumerated() {
            let cx = p.cx * size.width
            let cy = p.cy * size.height
            let rx = p.rx * size.width

            // 2 ripples per puddle at different phases
            for r in 0..<2 {
                let cycle = 2.5 + Double(pi) * 0.3
                let phase = fmod(t + Double(r) * cycle * 0.5 + Double(pi) * 1.1, cycle)
                let progress = phase / cycle
                let rippleR = progress * rx * 0.8
                let alpha = (1.0 - progress) * 0.4
                let rippleRect = CGRect(x: cx - rippleR, y: cy - rippleR * 0.3,
                                       width: rippleR * 2, height: rippleR * 0.6)
                ctx.stroke(Ellipse().path(in: rippleRect),
                           with: .color(Color.white.opacity(alpha)), lineWidth: 1.0)
            }
        }
    }

    // MARK: - Flower stems — thick lines with sway

    private func drawFlowerStems(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let growth = min(1.0, 0.15 + 0.85 * min(t / 8.0, 1.0))
        for f in flowers {
            let baseX = f.x * size.width
            let baseY = f.y * size.height
            let stemH = f.stemH * growth
            let sway = sin(t * 0.8 + f.swayPhase) * f.swayAmp * growth
            let topX = baseX + sway
            let topY = baseY - stemH

            var path = Path()
            path.move(to: CGPoint(x: baseX, y: baseY))
            path.addQuadCurve(to: CGPoint(x: topX, y: topY),
                              control: CGPoint(x: baseX + sway * 0.3, y: baseY - stemH * 0.5))

            let stemColor = Color(red: 0.15, green: f.leafG * 0.8, blue: 0.10)
            ctx.stroke(path, with: .color(stemColor), lineWidth: 2.5)
            // Cel outline
            ctx.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 0.8)
        }
    }

    // MARK: - Leaves — simple oval on stems

    private func drawFlowerLeaves(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let growth = min(1.0, 0.15 + 0.85 * min(t / 8.0, 1.0))
        for f in flowers {
            let baseX = f.x * size.width
            let baseY = f.y * size.height
            let stemH = f.stemH * growth
            let sway = sin(t * 0.8 + f.swayPhase) * f.swayAmp * growth

            let leafY = baseY - stemH * 0.45
            let leafX = baseX + sway * 0.3 + f.leafSide * 8
            let leafW = 10.0 * growth
            let leafH = 5.0 * growth

            let leafRect = CGRect(x: leafX - leafW / 2, y: leafY - leafH / 2,
                                  width: leafW, height: leafH)
            let leafColor = Color(red: 0.18, green: f.leafG, blue: 0.12)
            ctx.fill(Ellipse().path(in: leafRect), with: .color(leafColor))

            // Dark side (cel shade)
            let darkLeafRect = CGRect(x: leafX - leafW / 2, y: leafY,
                                      width: leafW, height: leafH * 0.4)
            ctx.fill(Ellipse().path(in: darkLeafRect),
                     with: .color(Color(red: 0.10, green: f.leafG * 0.6, blue: 0.08).opacity(0.5)))

            // Outline
            ctx.stroke(Ellipse().path(in: leafRect),
                       with: .color(.black.opacity(0.4)), lineWidth: 0.8)
        }
    }

    // MARK: - Flower petals — Miffy-simple flat circles around centre

    private func drawFlowerPetals(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for f in flowers {
            let baseX = f.x * size.width
            let baseY = f.y * size.height
            let sway = sin(t * 0.8 + f.swayPhase) * f.swayAmp
            let cx = baseX + sway
            let cy = baseY - f.stemH

            let petalColor = Color(red: f.petalR * 1.3, green: f.petalG * 1.3, blue: f.petalB * 1.3)
            let darkPetal = Color(red: f.petalR * 0.85, green: f.petalG * 0.85, blue: f.petalB * 0.85)

            // Draw petals as circles around centre
            for p in 0..<f.petalCount {
                let angle = Double(p) / Double(f.petalCount) * .pi * 2 + t * 0.05
                let px = cx + cos(angle) * f.size * 0.7
                let py = cy + sin(angle) * f.size * 0.7

                let pr = CGRect(x: px - f.size * 0.5, y: py - f.size * 0.5,
                               width: f.size, height: f.size)
                ctx.fill(Ellipse().path(in: pr), with: .color(petalColor))

                // Cel shade — lower half darker
                let darkRect = CGRect(x: px - f.size * 0.5, y: py,
                                      width: f.size, height: f.size * 0.4)
                ctx.fill(Ellipse().path(in: darkRect), with: .color(darkPetal.opacity(0.4)))

                // Outline
                ctx.stroke(Ellipse().path(in: pr),
                           with: .color(.black.opacity(0.4)), lineWidth: 0.8)
            }

            // Centre dot (bright HDR pop)
            let centreR = f.size * 0.35
            let centreRect = CGRect(x: cx - centreR, y: cy - centreR,
                                    width: centreR * 2, height: centreR * 2)
            ctx.fill(Ellipse().path(in: centreRect),
                     with: .color(Color(red: 1.6, green: 1.4, blue: 0.5)))
            ctx.stroke(Ellipse().path(in: centreRect),
                       with: .color(.black.opacity(0.5)), lineWidth: 0.8)
        }
    }

    // MARK: - Droplets on petals — small bright dots rolling down

    private func drawDropletsOnPetals(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let growth = min(1.0, 0.15 + 0.85 * min(t / 8.0, 1.0))
        for (fi, f) in flowers.enumerated() {
            let baseX = f.x * size.width
            let baseY = f.y * size.height
            let stemH = f.stemH * growth
            let sway = sin(t * 0.8 + f.swayPhase) * f.swayAmp * growth
            let cx = baseX + sway
            let cy = baseY - stemH

            // 2 droplets per flower, cycling
            for d in 0..<2 {
                let cycle = 3.5 + Double(fi) * 0.2
                let phase = fmod(t + Double(d) * 1.8 + Double(fi) * 0.7, cycle)
                let progress = phase / cycle

                // Droplet starts at top of flower, rolls down petal, drips off
                let angle = Double(d) / 2.0 * .pi + Double(fi) * 0.5
                let startX = cx + cos(angle) * f.size * 0.4
                let startY = cy - f.size * 0.3

                let dropX = startX + cos(angle) * progress * f.size * 0.5
                let dropY = startY + progress * (stemH * 0.3 + 10)

                let alpha = progress < 0.85 ? 0.6 : (1.0 - (progress - 0.85) / 0.15) * 0.6
                let dropSize = 2.0 + (1.0 - progress) * 1.5

                let dr = CGRect(x: dropX - dropSize / 2, y: dropY - dropSize / 2,
                               width: dropSize, height: dropSize * 1.3)
                // Bright raindrop — slight HDR
                ctx.fill(Ellipse().path(in: dr),
                         with: .color(Color(red: 0.7, green: 0.8, blue: 1.1).opacity(alpha)))
            }
        }
    }

    // MARK: - Tap blooms — expanding cel-shaded circles

    private func drawBlooms(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for bloom in blooms {
            let age = t - bloom.birth
            guard age < 5.0 else { continue }
            let p = age / 5.0

            // Central warm glow — cel-style (no blur for pixel aesthetic feel)
            let glowFade = age < 0.3 ? age / 0.3 : max(0, 1.0 - (age - 0.3) / 2.0)
            if glowFade > 0 {
                let r = 15 + p * 30
                ctx.fill(Ellipse().path(in: CGRect(x: bloom.x - r, y: bloom.y - r,
                                                    width: r * 2, height: r * 2)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 1.2, green: 1.0, blue: 0.4).opacity(0.18 * glowFade),
                            .clear
                        ]),
                        center: CGPoint(x: bloom.x, y: bloom.y),
                        startRadius: 0, endRadius: r))
            }

            // Multiple expanding rings — cel-shaded hard edges, staggered
            let ringColors: [(r: Double, g: Double, b: Double, delay: Double)] = [
                (1.1, 0.9, 0.3, 0.0),   // gold
                (1.0, 0.6, 0.9, 0.3),   // pink
                (0.5, 0.9, 1.1, 0.6),   // aqua
                (0.8, 1.0, 0.5, 0.9),   // lime
            ]
            for rc in ringColors {
                let ringAge = age - rc.delay
                guard ringAge > 0 else { continue }
                let rp = min(ringAge / 3.5, 1.0)
                let ringFade = max(0, 1.0 - rp)
                let radius = rp * 65
                let rect = CGRect(x: bloom.x - radius, y: bloom.y - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.stroke(Ellipse().path(in: rect),
                    with: .color(Color(red: rc.r, green: rc.g, blue: rc.b).opacity(ringFade * 0.45)),
                    lineWidth: 2.5 - rp * 1.5)
            }

            // Petal scatter — colorful circles drifting outward and falling
            let seed = UInt64(bloom.birth * 1000) & 0xFFFFFF
            var rng = SplitMix64(seed: seed)
            for _ in 0..<12 {
                let angle = nextDouble(&rng) * .pi * 2
                let drift = nextDouble(&rng) * 0.5 + 0.3
                let fallSpeed = nextDouble(&rng) * 12 + 6
                let sz = nextDouble(&rng) * 4 + 3
                let lifespan = nextDouble(&rng) * 2.0 + 2.5
                guard age < lifespan else { continue }
                let mp = age / lifespan
                let mFade = mp < 0.1 ? mp / 0.1 : max(0, 1.0 - (mp - 0.3) / 0.7)
                let dist = mp * drift * 80
                let px = bloom.x + cos(angle) * dist
                let py = bloom.y + sin(angle) * dist * 0.5 + (age > 0.8 ? (age - 0.8) * fallSpeed : 0)
                let colors: [(Double, Double, Double)] = [
                    (1.1, 0.5, 0.6), (0.5, 0.8, 1.1), (1.0, 0.9, 0.4), (0.8, 0.5, 1.0), (0.5, 1.0, 0.6)
                ]
                let ci = Int(nextDouble(&rng) * 5) % colors.count
                let c = colors[ci]
                let s = sz * max(0, mFade)
                ctx.fill(Ellipse().path(in: CGRect(x: px - s / 2, y: py - s / 2, width: s, height: s)),
                         with: .color(Color(red: c.0, green: c.1, blue: c.2).opacity(mFade * 0.6)))
            }
        }
    }

    // MARK: - Pixie dust — sparkle motes on flowers, brighter in heavy rain

    private func drawPixieDust(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Rain intensity from taps drives sparkle brightness
        var rainIntensity = 0.0
        for burst in rainBursts {
            let age = t - burst.birth
            guard age >= 0 && age < 5.0 else { continue }
            let env = age < 0.5 ? age / 0.5 : max(0, 1.0 - (age - 0.5) / 4.5)
            rainIntensity += env
        }
        rainIntensity = min(rainIntensity, 1.0)

        // Also ramp with natural rain build-up
        let naturalRain = min(t / 25.0, 1.0)
        let totalIntensity = min(naturalRain * 0.5 + rainIntensity, 1.0)

        let baseSparkles = 2
        let burstExtra = Int(totalIntensity * 8)
        let totalSparkles = baseSparkles + burstExtra
        let brightBoost = 1.0 + totalIntensity * 1.8

        let dustColors: [(Double, Double, Double)] = [
            (1.4, 1.2, 0.6),   // warm gold
            (1.2, 1.3, 1.5),   // ice white
            (1.3, 0.9, 1.2),   // soft pink
            (0.8, 1.3, 1.0),   // mint
            (1.5, 1.3, 0.4),   // bright gold
        ]

        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 1.5))
            for (fi, f) in flowers.enumerated() {
                let baseX = f.x * size.width
                let baseY = f.y * size.height
                let sway = sin(t * 0.8 + f.swayPhase) * f.swayAmp
                let cx = baseX + sway
                let cy = baseY - f.stemH

                for s in 0..<totalSparkles {
                    let seed = Double(fi * 37 + s * 13) * 0.731
                    let orbitAngle = fmod(seed * 2.7 + t * (0.3 + fmod(seed, 0.2)), .pi * 2)
                    let orbitR = f.size * (0.8 + fmod(seed * 3.1, 1.2))
                    let drift = fmod(t * (0.15 + fmod(seed * 1.7, 0.1)) + seed, 3.0) / 3.0

                    let px = cx + cos(orbitAngle) * orbitR + sin(t * 0.5 + seed) * 3
                    let py = cy - drift * 25 + sin(orbitAngle) * orbitR * 0.3

                    let twinkle = sin(t * (3.0 + fmod(seed * 2.3, 2.0)) + seed * 5.0) * 0.5 + 0.5
                    let lifecycle = drift < 0.1 ? drift / 0.1 : (drift > 0.8 ? (1.0 - drift) / 0.2 : 1.0)
                    let alpha = twinkle * lifecycle * 0.6 * brightBoost

                    let ci = Int(seed * 100) % dustColors.count
                    let c = dustColors[ci]
                    let sz = (1.0 + fmod(seed * 4.7, 2.0)) * (0.7 + totalIntensity * 0.5)

                    l.fill(
                        Ellipse().path(in: CGRect(x: px - sz / 2, y: py - sz / 2, width: sz, height: sz)),
                        with: .color(Color(red: c.0 * brightBoost, green: c.1 * brightBoost, blue: c.2 * brightBoost).opacity(alpha))
                    )
                }
            }
        }

        // Star-cross sparkles on brightest flowers during heavy rain
        if totalIntensity > 0.4 {
            let crossAlpha = (totalIntensity - 0.4) / 0.6 * 0.3
            for (fi, f) in flowers.enumerated() {
                guard fi % 3 == 0 else { continue } // every 3rd flower
                let baseX = f.x * size.width
                let baseY = f.y * size.height
                let sway = sin(t * 0.8 + f.swayPhase) * f.swayAmp
                let cx = baseX + sway
                let cy = baseY - f.stemH

                let twinkle = sin(t * 2.0 + Double(fi) * 1.3) * 0.5 + 0.5
                let crossLen = f.size * 0.8 * twinkle
                var hLine = Path()
                hLine.move(to: CGPoint(x: cx - crossLen, y: cy))
                hLine.addLine(to: CGPoint(x: cx + crossLen, y: cy))
                var vLine = Path()
                vLine.move(to: CGPoint(x: cx, y: cy - crossLen))
                vLine.addLine(to: CGPoint(x: cx, y: cy + crossLen))
                ctx.stroke(hLine, with: .color(Color(red: 1.3, green: 1.2, blue: 0.8).opacity(crossAlpha * twinkle)), lineWidth: 0.5)
                ctx.stroke(vLine, with: .color(Color(red: 1.3, green: 1.2, blue: 0.8).opacity(crossAlpha * twinkle)), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Rain — heavy downpour everywhere, intensifying over time

    private func drawRain(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Rain ramps up naturally over 25 seconds: drizzle → downpour
        let rainPhase = min(t / 25.0, 1.0)

        // Tap bursts add extra intensity on top
        var burstStr = 0.0
        for burst in rainBursts {
            let age = t - burst.birth
            if age >= 0 && age < 5.0 {
                burstStr += age < 0.3 ? age / 0.3 : max(0, 1.0 - (age - 0.3) / 4.7)
            }
        }
        burstStr = min(burstStr, 1.5)

        let totalIntensity = min(rainPhase + burstStr * 0.3, 1.0)
        let dropCount = 180 + Int(totalIntensity * 350)
        let windSway = sin(t * 0.15) * 0.08

        for i in 0..<dropCount {
            let seed = Double(i) * 7.31 + 1.23
            let cycle = 0.6 + fmod(seed * 3.7, 0.6) * (1.3 - totalIntensity * 0.5)
            let phase = fmod(t + seed * 0.13, cycle)
            let progress = phase / cycle

            let laneX = fmod(seed * 13.37, 1.0)
            let x = (laneX + windSway + progress * windSway * 0.5) * size.width
            let y = progress * size.height * 1.15 - size.height * 0.1

            // Drops get fatter and longer as rain intensifies
            let iScale = 0.7 + totalIntensity * 0.6
            let dropLen = (10.0 + fmod(seed * 2.1, 8.0)) * iScale
            let dropW = (1.8 + fmod(seed * 1.3, 1.2)) * (0.8 + totalIntensity * 0.4)

            let brightness = 0.6 + fmod(seed * 0.731, 0.4)
            let dropColor = Color(red: 0.65 * brightness, green: 0.75 * brightness, blue: 1.1 * brightness)

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + windSway * 8, y: y + dropLen))
            ctx.stroke(path, with: .color(dropColor.opacity(0.6 + totalIntensity * 0.2)), lineWidth: dropW)

            // Splash at bottom
            if progress > 0.88 {
                let splashProgress = (progress - 0.88) / 0.12
                let splashY = size.height * 0.92 + fmod(seed * 2.3, size.height * 0.08)
                let splashR = splashProgress * (5.0 + totalIntensity * 4.0)
                let splashAlpha = (1.0 - splashProgress) * (0.4 + totalIntensity * 0.2)

                let sr = CGRect(x: x - splashR, y: splashY - splashR * 0.3,
                               width: splashR * 2, height: splashR * 0.6)
                ctx.stroke(Ellipse().path(in: sr),
                           with: .color(Color.white.opacity(splashAlpha)), lineWidth: 0.8)
            }
        }

        // Puddle shimmer from overall rain intensity
        if totalIntensity > 0.25 {
            let shimmer = (totalIntensity - 0.25) / 0.75
            for p in puddles {
                let cx = p.cx * size.width
                let cy = p.cy * size.height
                let rx = p.rx * size.width
                let ry = p.ry * size.height
                let glint = sin(t * 4 + p.cx * 20) * 0.3 + 0.7
                let highlightRect = CGRect(x: cx - rx * 0.4, y: cy - ry * 0.5,
                                           width: rx * 0.8, height: ry * 0.5)
                ctx.fill(Ellipse().path(in: highlightRect),
                         with: .color(Color(red: 1.1, green: 1.1, blue: 1.3).opacity(shimmer * glint * 0.2)))
            }
        }
    }

    // MARK: - Cel outline overlay — scanline-like darkening at edges

    private func drawCelOutlineOverlay(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Horizontal cel-shade lines (PS1 dithering feel)
        let lineSpacing = 3.0
        let lineCount = Int(size.height / lineSpacing)
        for i in stride(from: 0, to: lineCount, by: 4) {
            let y = Double(i) * lineSpacing
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(path, with: .color(.black.opacity(0.018)), lineWidth: 0.5)
        }

        // Vignette corners (simple dark triangles — retro CRT feel)
        let cornerSize = min(size.width, size.height) * 0.15
        for corner in 0..<4 {
            let cx: Double = corner % 2 == 0 ? 0 : size.width
            let cy: Double = corner < 2 ? 0 : size.height
            var path = Path()
            path.move(to: CGPoint(x: cx, y: cy))
            path.addLine(to: CGPoint(x: cx + (corner % 2 == 0 ? cornerSize : -cornerSize), y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy + (corner < 2 ? cornerSize : -cornerSize)))
            path.closeSubpath()
            ctx.fill(path, with: .color(.black.opacity(0.12)))
        }
    }
}
