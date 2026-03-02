import SwiftUI

// Retro PS1/N64 — dreamy low-resolution nostalgia.
// Classic vertex jitter, affine texture wobble, dithered gradients,
// limited colour palette, and CRT scanline overlay. A serene nighttime
// scene: low-poly mountains, a shimmering lake, a small cabin with a
// glowing window, drifting fireflies, and a sky full of chunky stars.
// Everything gently wobbles like real PS1 hardware. Tap to spawn
// a shooting star. Pure Canvas, 60fps, no state mutation in Canvas.

struct RetroPS1Scene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()
    private let gridSnap: Double = 2.0  // vertex snap grid (PS1 jitter)

    // MARK: - Data types

    struct MountainPeak {
        let x, height, width: Double
        let shade: Double       // 0..1 how dark
    }

    struct TreeData {
        let x, y: Double
        let height, width: Double
        let shade: Double
        let swayPhase: Double
    }

    struct StarData {
        let x, y: Double
        let size: Double
        let brightness: Double
        let twinkleRate, twinklePhase: Double
    }

    struct FireflyData {
        let baseX, baseY: Double
        let driftXSpeed, driftYSpeed: Double
        let phase: Double
        let brightness: Double
    }

    struct ShootingStar: Identifiable {
        let id = UUID()
        let startX, startY, angle, speed, birth: Double
    }

    @State private var mountains: [MountainPeak] = []
    @State private var trees: [TreeData] = []
    @State private var stars: [StarData] = []
    @State private var fireflies: [FireflyData] = []
    @State private var shootingStars: [ShootingStar] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawShootingStars(ctx: &ctx, size: size, t: t)
                drawMountains(ctx: &ctx, size: size, t: t)
                drawLake(ctx: &ctx, size: size, t: t)
                drawLakeReflections(ctx: &ctx, size: size, t: t)
                drawTrees(ctx: &ctx, size: size, t: t)
                drawCabin(ctx: &ctx, size: size, t: t)
                drawFireflies(ctx: &ctx, size: size, t: t)
                drawForeground(ctx: &ctx, size: size, t: t)
                drawScanlines(ctx: &ctx, size: size, t: t)
                drawDitherOverlay(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.02, green: 0.01, blue: 0.06))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            shootingStars.append(ShootingStar(
                startX: loc.x, startY: loc.y,
                angle: -.pi / 4 + Double.random(in: -0.3...0.3),
                speed: 350 + Double.random(in: 0...150),
                birth: t
            ))
            if shootingStars.count > 8 { shootingStars.removeFirst() }
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 1997)

        mountains = (0..<12).map { _ in
            MountainPeak(
                x: nextDouble(&rng),
                height: 0.15 + nextDouble(&rng) * 0.25,
                width: 0.08 + nextDouble(&rng) * 0.15,
                shade: nextDouble(&rng)
            )
        }

        trees = (0..<20).map { _ in
            TreeData(
                x: nextDouble(&rng),
                y: 0.52 + nextDouble(&rng) * 0.06,
                height: 20 + nextDouble(&rng) * 35,
                width: 8 + nextDouble(&rng) * 12,
                shade: nextDouble(&rng),
                swayPhase: nextDouble(&rng) * .pi * 2
            )
        }

        stars = (0..<120).map { _ in
            StarData(
                x: nextDouble(&rng),
                y: nextDouble(&rng) * 0.5,
                size: 1.0 + nextDouble(&rng) * 3.0,
                brightness: 0.3 + nextDouble(&rng) * 0.7,
                twinkleRate: 0.5 + nextDouble(&rng) * 2.0,
                twinklePhase: nextDouble(&rng) * .pi * 2
            )
        }

        fireflies = (0..<25).map { _ in
            FireflyData(
                baseX: 0.1 + nextDouble(&rng) * 0.8,
                baseY: 0.45 + nextDouble(&rng) * 0.35,
                driftXSpeed: 0.01 + nextDouble(&rng) * 0.02,
                driftYSpeed: 0.008 + nextDouble(&rng) * 0.015,
                phase: nextDouble(&rng) * .pi * 2,
                brightness: 0.4 + nextDouble(&rng) * 0.6
            )
        }

        ready = true
    }

    // MARK: - PS1 vertex snap (jitter effect)

    private func snap(_ v: Double, t: Double, seed: Double = 0) -> Double {
        let jitter = sin(t * 15.0 + seed * 7.3) * gridSnap * 0.5
        return (v / gridSnap + jitter / gridSnap).rounded(.down) * gridSnap
    }

    private func snapPt(_ x: Double, _ y: Double, t: Double, seed: Double = 0) -> CGPoint {
        CGPoint(x: snap(x, t: t, seed: seed), y: snap(y, t: t, seed: seed + 3.7))
    }

    // MARK: - PS1 colour quantisation

    private func quantise(_ c: Double, levels: Int = 16) -> Double {
        let l = Double(levels)
        return (c * l).rounded(.down) / l
    }

    // MARK: - Drawing

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // PS1-style banded sky (discrete colour steps instead of smooth gradient)
        let bands = 12
        let bandH = size.height * 0.55 / Double(bands)
        for i in 0..<bands {
            let f = Double(i) / Double(bands)
            let r = quantise(0.02 + f * 0.08)
            let g = quantise(0.01 + f * 0.04)
            let b = quantise(0.06 + f * 0.18)
            let y = Double(i) * bandH
            let rect = CGRect(x: 0, y: y, width: size.width, height: bandH + 1)
            ctx.fill(Rectangle().path(in: rect), with: .color(Color(red: r, green: g, blue: b)))
        }
    }

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for st in stars {
            let twinkle = sin(t * st.twinkleRate + st.twinklePhase)
            let alpha = st.brightness * (0.5 + twinkle * 0.5)
            guard alpha > 0.15 else { continue }

            let x = snap(st.x * size.width, t: t, seed: st.twinklePhase)
            let y = snap(st.y * size.height, t: t, seed: st.twinklePhase + 2)
            let s = max(gridSnap, st.size.rounded(.down) * gridSnap)

            // PS1 stars: square pixels, not round
            let rect = CGRect(x: x, y: y, width: s, height: s)
            let brightness = quantise(alpha)
            ctx.fill(Rectangle().path(in: rect),
                     with: .color(Color(red: brightness * 0.9, green: brightness * 0.85, blue: brightness)))
        }
    }

    private func drawShootingStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for ss in shootingStars {
            let age = t - ss.birth
            guard age < 4.0 else { continue }

            // Main trail phase (first 2s)
            if age < 2.5 {
                let fade = max(0, 1.0 - age / 2.5)
                let trailLen = 12
                for ti in 0..<trailLen {
                    let ft = Double(ti) / Double(trailLen)
                    let dist = age * ss.speed - ft * 50
                    guard dist > 0 else { continue }
                    let x = snap(ss.startX + cos(ss.angle) * dist, t: t, seed: Double(ti))
                    let y = snap(ss.startY + sin(ss.angle) * dist, t: t, seed: Double(ti) + 5)
                    let a = fade * (1.0 - ft) * 0.8
                    let s = gridSnap * (2.0 - ft)
                    ctx.fill(Rectangle().path(in: CGRect(x: x, y: y, width: s, height: s)),
                             with: .color(Color(red: 1.0, green: 0.95, blue: 0.7).opacity(a)))
                }

                // Bright head glow
                let headX = snap(ss.startX + cos(ss.angle) * age * ss.speed, t: t, seed: 999)
                let headY = snap(ss.startY + sin(ss.angle) * age * ss.speed, t: t, seed: 998)
                let headFade = age < 0.3 ? age / 0.3 : fade
                let headS = gridSnap * 3
                ctx.fill(Rectangle().path(in: CGRect(x: headX - headS / 2, y: headY - headS / 2,
                                                     width: headS, height: headS)),
                    with: .color(Color(red: 1.3, green: 1.2, blue: 0.9).opacity(headFade * 0.6)))
            }

            // Pixel dust scatter (appears after 0.5s, lingers)
            if age > 0.5 {
                let dustAge = age - 0.5
                let seed = UInt64(ss.birth * 1000) & 0xFFFFFF
                var rng = SplitMix64(seed: seed)
                let impactX = ss.startX + cos(ss.angle) * 0.5 * ss.speed
                let impactY = ss.startY + sin(ss.angle) * 0.5 * ss.speed
                for _ in 0..<10 {
                    let angle = nextDouble(&rng) * .pi * 2
                    let drift = nextDouble(&rng) * 30 + 15
                    let fallSpeed = nextDouble(&rng) * 15 + 8
                    let lifespan = nextDouble(&rng) * 1.5 + 2.0
                    guard dustAge < lifespan else { continue }
                    let dp = dustAge / lifespan
                    let dFade = dp < 0.1 ? dp / 0.1 : max(0, 1.0 - (dp - 0.1) / 0.9)
                    let dx = snap(impactX + cos(angle) * dp * drift, t: t, seed: nextDouble(&rng) * 100)
                    let dy = snap(impactY + sin(angle) * dp * drift * 0.5 + dp * fallSpeed, t: t, seed: nextDouble(&rng) * 100)
                    let s = gridSnap * dFade
                    let warmth = nextDouble(&rng)
                    let color = warmth > 0.5
                        ? Color(red: 1.0, green: 0.9, blue: 0.6)
                        : Color(red: 0.8, green: 0.7, blue: 1.0)
                    ctx.fill(Rectangle().path(in: CGRect(x: dx, y: dy, width: s, height: s)),
                        with: .color(color.opacity(dFade * 0.45)))
                }
            }
        }
    }

    private func drawMountains(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Background mountain layer (far)
        for mt in mountains {
            let cx = mt.x * size.width
            let baseY = size.height * 0.55
            let peakY = baseY - mt.height * size.height
            let halfW = mt.width * size.width

            // PS1 low-poly triangle mountain
            var p = Path()
            p.move(to: snapPt(cx - halfW, baseY, t: t, seed: mt.x))
            p.addLine(to: snapPt(cx, peakY, t: t, seed: mt.x + 1))
            p.addLine(to: snapPt(cx + halfW, baseY, t: t, seed: mt.x + 2))
            p.closeSubpath()

            // Flat shading — darker = farther
            let shade = 0.06 + mt.shade * 0.08
            ctx.fill(p, with: .color(Color(red: shade * 0.7, green: shade * 0.5, blue: shade * 1.2)))

            // One light edge (PS1 gouraud-ish)
            var edge = Path()
            edge.move(to: snapPt(cx, peakY, t: t, seed: mt.x + 1))
            edge.addLine(to: snapPt(cx + halfW * 0.5, (peakY + baseY) / 2, t: t, seed: mt.x + 3))
            ctx.stroke(edge, with: .color(Color(red: shade * 1.2, green: shade * 0.9, blue: shade * 1.8).opacity(0.3)), lineWidth: 1)
        }
    }

    private func drawLake(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let lakeTop = size.height * 0.55
        let lakeBot = size.height * 0.72

        // Horizontal bands for water (PS1 flat-shaded quads)
        let waterBands = 8
        let bandH = (lakeBot - lakeTop) / Double(waterBands)
        for i in 0..<waterBands {
            let f = Double(i) / Double(waterBands)
            let wobble = sin(t * 0.8 + f * 4.0) * 2.0
            let y = lakeTop + Double(i) * bandH + wobble
            let shade = quantise(0.04 + f * 0.06)
            let rect = CGRect(x: 0, y: y, width: size.width, height: bandH + 2)
            ctx.fill(Rectangle().path(in: rect),
                     with: .color(Color(red: shade * 0.3, green: shade * 0.5, blue: shade * 1.5)))
        }

        // Surface shimmer (PS1 vertex-coloured highlight)
        for i in 0..<6 {
            let sx = fmod(Double(i) * size.width / 5.0 + t * 12.0, size.width + 40) - 20
            let sy = lakeTop + sin(t * 1.2 + Double(i) * 1.5) * 3.0
            let w = gridSnap * 6
            let h = gridSnap
            let a = sin(t * 0.7 + Double(i) * 2) * 0.15 + 0.15
            ctx.fill(Rectangle().path(in: CGRect(x: snap(sx, t: t, seed: Double(i)), y: snap(sy, t: t, seed: Double(i) + 10), width: w, height: h)),
                     with: .color(Color(red: 0.3, green: 0.5, blue: 0.9).opacity(a)))
        }
    }

    private func drawLakeReflections(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let lakeTop = size.height * 0.55

        // Reflected mountains (simpler, warped)
        for mt in mountains.prefix(6) {
            let cx = mt.x * size.width
            let refY = lakeTop + mt.height * size.height * 0.3
            let halfW = mt.width * size.width * 0.8

            var p = Path()
            let wobX = sin(t * 0.6 + mt.x * 5) * 3
            p.move(to: snapPt(cx - halfW + wobX, lakeTop, t: t, seed: mt.x + 10))
            p.addLine(to: snapPt(cx + wobX, refY, t: t, seed: mt.x + 11))
            p.addLine(to: snapPt(cx + halfW + wobX, lakeTop, t: t, seed: mt.x + 12))
            p.closeSubpath()

            let shade = 0.03 + mt.shade * 0.04
            ctx.fill(p, with: .color(Color(red: shade * 0.5, green: shade * 0.6, blue: shade * 1.5).opacity(0.35)))
        }
    }

    private func drawTrees(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for tree in trees.sorted(by: { $0.y < $1.y }) {
            let x = tree.x * size.width
            let y = tree.y * size.height
            let sway = sin(t * 0.4 + tree.swayPhase) * 3.0

            // Trunk (single rectangle — very PS1)
            let trunkW = tree.width * 0.3
            let trunkH = tree.height * 0.4
            let trunkRect = CGRect(
                x: snap(x - trunkW / 2, t: t, seed: tree.x),
                y: snap(y - trunkH, t: t, seed: tree.x + 1),
                width: trunkW, height: trunkH)
            ctx.fill(Rectangle().path(in: trunkRect),
                     with: .color(Color(red: 0.15, green: 0.08, blue: 0.04)))

            // Foliage: two overlapping triangles (conifer PS1 style)
            let shade = quantise(0.05 + tree.shade * 0.12)
            let foliageColor = Color(red: shade * 0.4, green: shade, blue: shade * 0.3)

            // Lower triangle
            var lo = Path()
            lo.move(to: snapPt(x - tree.width * 0.6 + sway * 0.5, y - trunkH * 0.5, t: t, seed: tree.x + 2))
            lo.addLine(to: snapPt(x + sway, y - tree.height * 0.7, t: t, seed: tree.x + 3))
            lo.addLine(to: snapPt(x + tree.width * 0.6 + sway * 0.5, y - trunkH * 0.5, t: t, seed: tree.x + 4))
            lo.closeSubpath()
            ctx.fill(lo, with: .color(foliageColor))

            // Upper triangle
            var hi = Path()
            hi.move(to: snapPt(x - tree.width * 0.4 + sway, y - tree.height * 0.55, t: t, seed: tree.x + 5))
            hi.addLine(to: snapPt(x + sway, y - tree.height + sway * 0.3, t: t, seed: tree.x + 6))
            hi.addLine(to: snapPt(x + tree.width * 0.4 + sway, y - tree.height * 0.55, t: t, seed: tree.x + 7))
            hi.closeSubpath()
            ctx.fill(hi, with: .color(foliageColor.opacity(0.9)))
        }
    }

    private func drawCabin(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width * 0.65
        let baseY = size.height * 0.54
        let cabW = 50.0
        let cabH = 30.0
        let roofH = 20.0

        // Cabin body
        let bodyRect = CGRect(
            x: snap(cx - cabW / 2, t: t, seed: 100),
            y: snap(baseY - cabH, t: t, seed: 101),
            width: cabW, height: cabH)
        ctx.fill(Rectangle().path(in: bodyRect),
                 with: .color(Color(red: 0.18, green: 0.1, blue: 0.06)))

        // Roof (triangle)
        var roof = Path()
        roof.move(to: snapPt(cx - cabW / 2 - 5.0, baseY - cabH, t: t, seed: 102))
        roof.addLine(to: snapPt(cx, baseY - cabH - roofH, t: t, seed: 103))
        roof.addLine(to: snapPt(cx + cabW / 2 + 5.0, baseY - cabH, t: t, seed: 104))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(red: 0.12, green: 0.06, blue: 0.04)))

        // Window (glowing!)
        let winW = 10.0, winH = 10.0
        let winX = cx - 6
        let winY = baseY - cabH + 8
        let pulse = sin(t * 0.3) * 0.15 + 0.85
        let winRect = CGRect(
            x: snap(winX, t: t, seed: 105),
            y: snap(winY, t: t, seed: 106),
            width: winW, height: winH)
        ctx.fill(Rectangle().path(in: winRect),
                 with: .color(Color(red: 1.2 * pulse, green: 0.85 * pulse, blue: 0.3 * pulse)))

        // Door
        let doorW = 8.0, doorH = 14.0
        let doorRect = CGRect(
            x: snap(cx + 5, t: t, seed: 107),
            y: snap(baseY - doorH, t: t, seed: 108),
            width: doorW, height: doorH)
        ctx.fill(Rectangle().path(in: doorRect),
                 with: .color(Color(red: 0.1, green: 0.05, blue: 0.03)))

        // Chimney with smoke
        let chimX = cx + cabW / 4
        let chimRect = CGRect(
            x: snap(chimX, t: t, seed: 109), y: snap(baseY - cabH - roofH + 2, t: t, seed: 110),
            width: 6, height: roofH - 2)
        ctx.fill(Rectangle().path(in: chimRect),
                 with: .color(Color(red: 0.15, green: 0.08, blue: 0.04)))

        // Smoke puffs (square particles rising)
        for i in 0..<5 {
            let age = fmod(t * 0.3 + Double(i) * 0.2, 1.0)
            let sx = chimX + 3 + sin(t * 0.5 + Double(i) * 2) * (8 * age)
            let sy = baseY - cabH - roofH - age * 60
            let a = (1 - age) * 0.25
            let s = gridSnap * (1 + age * 2)
            ctx.fill(Rectangle().path(in: CGRect(
                x: snap(sx, t: t, seed: Double(i) + 200),
                y: snap(sy, t: t, seed: Double(i) + 201),
                width: s, height: s)),
                     with: .color(Color.white.opacity(a)))
        }
    }

    private func drawFireflies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for ff in fireflies {
            let x = (ff.baseX + sin(t * ff.driftXSpeed * 5 + ff.phase) * 0.06) * size.width
            let y = (ff.baseY + sin(t * ff.driftYSpeed * 4 + ff.phase + 1) * 0.04) * size.height
            let pulse = sin(t * 2.0 + ff.phase) * 0.5 + 0.5
            let alpha = ff.brightness * pulse
            guard alpha > 0.1 else { continue }

            let sx = snap(x, t: t, seed: ff.phase)
            let sy = snap(y, t: t, seed: ff.phase + 3)

            // Core pixel
            let s = gridSnap
            ctx.fill(Rectangle().path(in: CGRect(x: sx, y: sy, width: s, height: s)),
                     with: .color(Color(red: 0.9, green: 1.2, blue: 0.3).opacity(alpha)))

            // Tiny glow cross (PS1 style glow = adjacent pixels)
            if alpha > 0.3 {
                let ga = alpha * 0.3
                let glowColor = Color(red: 0.7, green: 1.0, blue: 0.2).opacity(ga)
                ctx.fill(Rectangle().path(in: CGRect(x: sx - s, y: sy, width: s, height: s)), with: .color(glowColor))
                ctx.fill(Rectangle().path(in: CGRect(x: sx + s, y: sy, width: s, height: s)), with: .color(glowColor))
                ctx.fill(Rectangle().path(in: CGRect(x: sx, y: sy - s, width: s, height: s)), with: .color(glowColor))
                ctx.fill(Rectangle().path(in: CGRect(x: sx, y: sy + s, width: s, height: s)), with: .color(glowColor))
            }
        }
    }

    private func drawForeground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Dark ground beneath lake
        let groundTop = size.height * 0.72
        let rect = CGRect(x: 0, y: groundTop, width: size.width, height: size.height - groundTop)
        ctx.fill(Rectangle().path(in: rect), with: .color(Color(red: 0.03, green: 0.02, blue: 0.01)))

        // Foreground grass clumps (square pixel tufts)
        var rng = SplitMix64(seed: 5555)
        for _ in 0..<30 {
            let gx = nextDouble(&rng) * size.width
            let gy = groundTop - 2 + nextDouble(&rng) * 8
            let gh = 4 + nextDouble(&rng) * 8
            let sway = sin(t * 0.5 + gx * 0.01) * 2
            let shade = quantise(0.06 + nextDouble(&rng) * 0.08)

            var p = Path()
            p.move(to: snapPt(gx + sway, gy - gh, t: t, seed: gx))
            p.addLine(to: snapPt(gx - 3, gy, t: t, seed: gx + 1))
            p.addLine(to: snapPt(gx + 3, gy, t: t, seed: gx + 2))
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(red: shade * 0.3, green: shade, blue: shade * 0.2)))
        }
    }

    private func drawScanlines(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // CRT scanline overlay
        let lineSpacing = 3.0
        let alpha = 0.06 + sin(t * 0.1) * 0.01
        for y in stride(from: 0.0, through: size.height, by: lineSpacing) {
            ctx.fill(
                Rectangle().path(in: CGRect(x: 0, y: y, width: size.width, height: 1)),
                with: .color(Color.black.opacity(alpha))
            )
        }
    }

    private func drawDitherOverlay(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Subtle ordered dithering pattern (Bayer 2x2 feel)
        // Only draw sparse pixels to get the PS1 dither texture
        let step = 6.0
        let breathe = sin(t * 0.15) * 0.005 + 0.015
        var rng = SplitMix64(seed: 3333)
        // Sparse sampling — draw ~1/8 of the grid for performance
        for _ in 0..<Int(size.width * size.height / (step * step) / 8) {
            let px = nextDouble(&rng) * size.width
            let py = nextDouble(&rng) * size.height
            let ix = Int(px / step) % 2
            let iy = Int(py / step) % 2
            // Bayer 2x2: 0,2,3,1 pattern mapped to alpha
            let bayer = [[0.0, 0.5], [0.75, 0.25]]
            let d = bayer[iy][ix]
            let a = breathe * d
            ctx.fill(Rectangle().path(in: CGRect(x: px, y: py, width: 1, height: 1)),
                     with: .color(Color.white.opacity(a)))
        }
    }
}
