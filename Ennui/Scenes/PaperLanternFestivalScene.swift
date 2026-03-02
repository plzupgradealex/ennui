import SwiftUI

// Paper Lantern Festival — a warm, dream-like evening scene.
// Hundreds of glowing paper lanterns rise gently into the twilight
// from a dark lake. Each lantern has a warm inner flame that flickers.
// The lake below reflects the scene — undulating golden lights on dark
// water. Fireflies dance between lanterns. Distant mountains are
// silhouetted against a deep indigo-to-amber gradient sky.
// Tap to release a cluster of new lanterns from that position.
// Pure Canvas, 60fps, no state mutation inside Canvas closure.

struct PaperLanternFestivalScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data

    struct LanternData {
        let spawnX: Double      // normalised 0..1
        let spawnY: Double      // normalised start y (0.6..0.9)
        let riseSpeed: Double   // normalised per second
        let driftFreq: Double   // horizontal sway frequency
        let driftAmp: Double    // horizontal sway amplitude
        let size: Double        // radius in pts
        let warmth: Double      // 0=orange, 1=golden
        let flickerRate: Double
        let flickerPhase: Double
        let phase: Double       // time offset so lanterns stagger
        let cycleDuration: Double // total rise time before wrapping
    }

    struct FireflyData {
        let baseX, baseY: Double
        let orbitR: Double
        let speed: Double
        let phase: Double
        let brightness: Double
    }

    struct MountainPt {
        let x, y: Double // normalised
    }

    struct TapLantern: Identifiable {
        let id = UUID()
        let x, y, birth: Double
        let driftPhase: Double
    }

    @State private var lanterns: [LanternData] = []
    @State private var fireflies: [FireflyData] = []
    @State private var mountains: [MountainPt] = []
    @State private var tapLanterns: [TapLantern] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawDistantMountains(ctx: &ctx, size: size)
                drawLanterns(ctx: &ctx, size: size, t: t)
                drawTapLanterns(ctx: &ctx, size: size, t: t)
                drawFireflies(ctx: &ctx, size: size, t: t)
                drawWater(ctx: &ctx, size: size, t: t)
                drawReflections(ctx: &ctx, size: size, t: t)
                drawForegroundSilhouette(ctx: &ctx, size: size)
            }
        }
        .background(.black)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            let screenW = max(NSScreen.main?.frame.width ?? 1200, 1)
            let screenH = max(NSScreen.main?.frame.height ?? 800, 1)
            let nx = loc.x / screenW
            let ny = loc.y / screenH
            var rng = SplitMix64(seed: UInt64(t * 10000))
            for _ in 0..<5 {
                tapLanterns.append(TapLantern(
                    x: nx + (rng.nextDouble() - 0.5) * 0.06,
                    y: ny + rng.nextDouble() * 0.03,
                    birth: t,
                    driftPhase: rng.nextDouble() * .pi * 2
                ))
            }
            if tapLanterns.count > 40 { tapLanterns.removeFirst(5) }
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !ready else { return }
        var rng = SplitMix64(seed: 0xA4E840)

        // Lanterns
        for _ in 0..<120 {
            let cycle = 20.0 + rng.nextDouble() * 25.0
            lanterns.append(LanternData(
                spawnX: rng.nextDouble(),
                spawnY: 0.6 + rng.nextDouble() * 0.3,
                riseSpeed: 0.01 + rng.nextDouble() * 0.015,
                driftFreq: 0.2 + rng.nextDouble() * 0.6,
                driftAmp: 0.01 + rng.nextDouble() * 0.03,
                size: 4.0 + rng.nextDouble() * 8.0,
                warmth: rng.nextDouble(),
                flickerRate: 2.0 + rng.nextDouble() * 4.0,
                flickerPhase: rng.nextDouble() * .pi * 2,
                phase: rng.nextDouble() * 40.0,
                cycleDuration: cycle
            ))
        }

        // Fireflies
        for _ in 0..<40 {
            fireflies.append(FireflyData(
                baseX: rng.nextDouble(),
                baseY: 0.35 + rng.nextDouble() * 0.3,
                orbitR: 0.005 + rng.nextDouble() * 0.02,
                speed: 0.5 + rng.nextDouble() * 1.5,
                phase: rng.nextDouble() * .pi * 2,
                brightness: 0.3 + rng.nextDouble() * 0.7
            ))
        }

        // Mountain silhouette
        let segments = 30
        for i in 0...segments {
            let frac = Double(i) / Double(segments)
            // Gentle rolling hills
            let h = 0.08 + sin(frac * .pi * 3.0) * 0.03 + rng.nextDouble() * 0.02
            mountains.append(MountainPt(x: frac, y: h))
        }

        ready = true
    }

    // MARK: - Drawing

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        // Gradient: deep indigo at top → warm amber near horizon
        let steps = 30
        for i in 0..<steps {
            let frac = Double(i) / Double(steps)
            let y0 = frac * waterLine
            let y1 = (frac + 1.0 / Double(steps)) * waterLine + 1
            // Deep indigo to warm sunset
            let r = 0.03 + frac * 0.35
            let g = 0.02 + frac * 0.12
            let b = 0.12 + frac * 0.05 - frac * frac * 0.08
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0)),
                with: .color(Color(red: r, green: g, blue: b))
            )
        }

        // Subtle stars in the upper sky
        var rng = SplitMix64(seed: 0x5EA450)
        for _ in 0..<80 {
            let sx = rng.nextDouble() * w
            let sy = rng.nextDouble() * waterLine * 0.5
            let br = rng.nextDouble() * 0.3
            let twinkle = sin(t * (1.0 + rng.nextDouble() * 2.0) + rng.nextDouble() * 6.28) * 0.15 + 0.85
            let r = 0.5 + rng.nextDouble()
            ctx.fill(
                Circle().path(in: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)),
                with: .color(Color.white.opacity(br * twinkle))
            )
        }
    }

    private func drawDistantMountains(ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        var path = Path()
        for (i, pt) in mountains.enumerated() {
            let x = pt.x * w
            let y = waterLine - pt.y * h
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.addLine(to: CGPoint(x: w, y: waterLine))
        path.addLine(to: CGPoint(x: 0, y: waterLine))
        path.closeSubpath()
        ctx.fill(path, with: .color(Color(red: 0.04, green: 0.03, blue: 0.06)))
    }

    private func lanternPosition(lantern: LanternData, t: Double, w: Double, h: Double) -> (x: Double, y: Double, alpha: Double) {
        let age = fmod(t + lantern.phase, lantern.cycleDuration)
        let progress = age / lantern.cycleDuration
        let rise = progress * 0.7  // normalised rise distance
        let x = lantern.spawnX + sin(age * lantern.driftFreq * .pi * 2) * lantern.driftAmp
        let y = lantern.spawnY - rise

        // Fade in at bottom, fade out at top
        var alpha = 1.0
        if progress < 0.05 { alpha = progress / 0.05 }
        if progress > 0.85 { alpha = 1.0 - (progress - 0.85) / 0.15 }

        return (x * w, y * h, alpha)
    }

    private func drawLanterns(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Shared glow layer for all lanterns
        ctx.drawLayer { glowLayer in
            glowLayer.addFilter(.blur(radius: 18))
            for lantern in lanterns {
                let pos = lanternPosition(lantern: lantern, t: t, w: w, h: h)
                guard pos.alpha > 0.01, pos.y > 0, pos.y < h * 0.75 else { continue }

                let flicker = sin(t * lantern.flickerRate + lantern.flickerPhase) * 0.1 + 0.9
                let r = lantern.size * 2.0
                let warmR = 1.0 + lantern.warmth * 0.2
                let warmG = 0.6 + lantern.warmth * 0.15
                let warmB = 0.1 + lantern.warmth * 0.1

                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                glowLayer.fill(
                    Ellipse().path(in: rect),
                    with: .color(Color(red: warmR, green: warmG, blue: warmB).opacity(pos.alpha * flicker * 0.25))
                )
            }
        }

        // Lantern bodies
        for lantern in lanterns {
            let pos = lanternPosition(lantern: lantern, t: t, w: w, h: h)
            guard pos.alpha > 0.01, pos.y > 0, pos.y < h * 0.75 else { continue }

            let flicker = sin(t * lantern.flickerRate + lantern.flickerPhase) * 0.1 + 0.9
            let s = lantern.size
            let warmR = 1.0 + lantern.warmth * 0.3
            let warmG = 0.6 + lantern.warmth * 0.2
            let warmB = 0.15

            // Lantern shape: rounded rectangle body
            let bodyRect = CGRect(x: pos.x - s * 0.6, y: pos.y - s, width: s * 1.2, height: s * 1.6)
            ctx.fill(
                RoundedRectangle(cornerRadius: s * 0.3).path(in: bodyRect),
                with: .color(Color(red: warmR * flicker, green: warmG * flicker, blue: warmB).opacity(pos.alpha * 0.9))
            )

            // Inner flame dot
            let flameSize = s * 0.25
            let flameY = pos.y - s * 0.1 + sin(t * 5.0 + lantern.flickerPhase) * s * 0.08
            ctx.fill(
                Circle().path(in: CGRect(x: pos.x - flameSize, y: flameY - flameSize, width: flameSize * 2, height: flameSize * 2)),
                with: .color(Color(red: 1.5, green: 1.2, blue: 0.5).opacity(pos.alpha * flicker * 0.8))
            )

            // String hanging below
            let stringLen = s * 0.4
            var stringPath = Path()
            stringPath.move(to: CGPoint(x: pos.x, y: pos.y + s * 0.6))
            stringPath.addLine(to: CGPoint(x: pos.x + sin(t * 0.5 + lantern.driftFreq) * 1.5, y: pos.y + s * 0.6 + stringLen))
            ctx.stroke(stringPath, with: .color(Color.white.opacity(pos.alpha * 0.15)), lineWidth: 0.5)
        }
    }

    private func drawTapLanterns(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for tl in tapLanterns {
            let age = t - tl.birth
            guard age > 0, age < 15.0 else { continue }
            let rise = age * 0.025
            let x = (tl.x + sin(age * 0.8 + tl.driftPhase) * 0.02) * w
            let y = (tl.y - rise) * h
            guard y > 0 else { continue }

            var alpha = 1.0
            if age < 0.5 { alpha = age / 0.5 }
            if age > 12.0 { alpha = 1.0 - (age - 12.0) / 3.0 }
            alpha = max(0, alpha)

            let s = 6.0
            let flicker = sin(t * 3.5 + tl.driftPhase) * 0.1 + 0.9

            // Glow
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 12))
                let gr = s * 2.5
                layer.fill(
                    Ellipse().path(in: CGRect(x: x - gr, y: y - gr, width: gr * 2, height: gr * 2)),
                    with: .color(Color(red: 1.2, green: 0.7, blue: 0.15).opacity(alpha * flicker * 0.3))
                )
            }

            // Body
            let bodyRect = CGRect(x: x - s * 0.6, y: y - s, width: s * 1.2, height: s * 1.6)
            ctx.fill(
                RoundedRectangle(cornerRadius: s * 0.3).path(in: bodyRect),
                with: .color(Color(red: 1.2 * flicker, green: 0.7 * flicker, blue: 0.15).opacity(alpha * 0.9))
            )
        }
    }

    private func drawFireflies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            for ff in fireflies {
                let angle = t * ff.speed + ff.phase
                let x = (ff.baseX + cos(angle) * ff.orbitR) * w
                let y = (ff.baseY + sin(angle * 0.7) * ff.orbitR * 0.6) * h
                let pulse = sin(t * 2.0 + ff.phase) * 0.4 + 0.6
                let alpha = ff.brightness * pulse * 0.5
                let r = 2.0 + pulse
                layer.fill(
                    Circle().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 1.0, green: 0.9, blue: 0.3).opacity(alpha))
                )
            }
        }
    }

    private func drawWater(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        // Dark water with subtle wave texture
        let waterRect = CGRect(x: 0, y: waterLine, width: w, height: h - waterLine)
        ctx.fill(
            Path(waterRect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.02, green: 0.015, blue: 0.04),
                    Color(red: 0.01, green: 0.01, blue: 0.02),
                ]),
                startPoint: CGPoint(x: 0, y: waterLine),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        // Gentle wave lines
        for i in 0..<8 {
            let wy = waterLine + Double(i) * (h - waterLine) / 8.0 + 5
            var wave = Path()
            for xi in 0...40 {
                let frac = Double(xi) / 40.0
                let x = frac * w
                let offset = sin(frac * .pi * 4 + t * 0.3 + Double(i) * 0.8) * 2.0
                let pt = CGPoint(x: x, y: wy + offset)
                if xi == 0 { wave.move(to: pt) } else { wave.addLine(to: pt) }
            }
            ctx.stroke(wave, with: .color(Color(red: 0.15, green: 0.1, blue: 0.2).opacity(0.08)), lineWidth: 0.5)
        }
    }

    private func drawReflections(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        // Reflected lantern light on water — smeared, wavering columns of light
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            for lantern in lanterns {
                let pos = lanternPosition(lantern: lantern, t: t, w: w, h: h)
                guard pos.alpha > 0.1, pos.y > 0, pos.y < waterLine else { continue }

                let reflX = pos.x + sin(t * 0.5 + lantern.driftAmp * 10) * 3.0
                let reflY = waterLine + (waterLine - pos.y) * 0.4
                let reflH = (h - waterLine) * 0.3
                let reflW = lantern.size * 0.8

                let colRect = CGRect(x: reflX - reflW, y: reflY, width: reflW * 2, height: reflH)
                let warmth = lantern.warmth
                layer.fill(
                    Ellipse().path(in: colRect),
                    with: .color(Color(red: 0.9 + warmth * 0.2, green: 0.5 + warmth * 0.1, blue: 0.1).opacity(pos.alpha * 0.06))
                )
            }
        }
    }

    private func drawForegroundSilhouette(ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        // Silhouetted reeds/grass at bottom edges
        var rng = SplitMix64(seed: 0xBEED5)
        for _ in 0..<40 {
            let side = rng.nextDouble() > 0.5
            let baseX = side ? w - rng.nextDouble() * w * 0.15 : rng.nextDouble() * w * 0.15
            let baseY = waterLine - rng.nextDouble() * 5.0
            let reedH = 15.0 + rng.nextDouble() * 35.0
            let lean = (rng.nextDouble() - 0.5) * 8.0

            var reed = Path()
            reed.move(to: CGPoint(x: baseX, y: baseY))
            reed.addQuadCurve(
                to: CGPoint(x: baseX + lean, y: baseY - reedH),
                control: CGPoint(x: baseX + lean * 0.5, y: baseY - reedH * 0.5)
            )
            ctx.stroke(reed, with: .color(Color(red: 0.02, green: 0.02, blue: 0.03)), lineWidth: 1.0 + rng.nextDouble())
        }
    }
}
