// NightflyScene — Inspired by all four of Donald Fagen's solo albums.
//
// "The Nightfly" (1982) — a retrofuturistic late-night radio studio:
//   reel-to-reel tape, a ribbon microphone, a mixing console, VU meters.
// "Kamakiriad" (1993) — a sleek steam-powered vehicle idles on the street,
//   wisps of warm exhaust drifting upward through the cold air.
// "Morph the Cat" (2006) — Manhattan fog, a cat watching from a rooftop,
//   sodium-orange street lamps mirrored in rain-slicked asphalt.
// "Sunken Condos" (2012) — warm windows high in dark towers, the quiet
//   solitude of a city that never stops breathing.
//
// Tap to broadcast a signal — radio rings ripple outward across the skyline.

import SwiftUI

struct NightflyScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data types

    struct SignalRipple: Identifiable {
        let id = UUID()
        let birth: Double
    }

    struct SteamPuff {
        let x, phase, speed: Double
    }

    // MARK: - State

    @State private var ready = false
    @State private var ripples: [SignalRipple] = []
    @State private var steamPuffs: [SteamPuff] = []

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                let w = size.width
                let h = size.height

                drawSky(ctx: &ctx, w: w, h: h, t: t)
                drawCityscape(ctx: &ctx, w: w, h: h, t: t)
                drawFog(ctx: &ctx, w: w, h: h, t: t)
                drawStreet(ctx: &ctx, w: w, h: h, t: t)
                drawSteam(ctx: &ctx, w: w, h: h, t: t)
                drawKamakiriad(ctx: &ctx, w: w, h: h, t: t)
                drawCat(ctx: &ctx, w: w, h: h, t: t)
                drawWindowFrame(ctx: &ctx, w: w, h: h)
                drawControlBoard(ctx: &ctx, w: w, h: h, t: t)
                drawReelToReel(ctx: &ctx, w: w, h: h, t: t)
                drawMicrophone(ctx: &ctx, w: w, h: h)
                drawVUMeters(ctx: &ctx, w: w, h: h, t: t)
                drawSignalRipples(ctx: &ctx, w: w, h: h, t: t)
            }
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.09))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: generate)
        .onChange(of: interaction.tapCount) { _, _ in
            let t = Date().timeIntervalSince(startDate)
            ripples.append(SignalRipple(birth: t))
            if ripples.count > 5 { ripples.removeFirst() }
        }
    }

    // MARK: - Generate

    private func generate() {
        var rng = SplitMix64(seed: 0x1982_CAFE)
        steamPuffs = (0..<9).map { _ in
            SteamPuff(
                x: 0.08 + nextDouble(&rng) * 0.84,
                phase: nextDouble(&rng) * .pi * 2,
                speed: 0.22 + nextDouble(&rng) * 0.18
            )
        }
        ready = true
    }

    // MARK: - Sky

    private func drawSky(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let skyH = h * 0.74
        // Deep night-blue gradient — Manhattan light pollution tints the low horizon amber
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: skyH)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.10),
                    Color(red: 0.06, green: 0.07, blue: 0.15),
                    Color(red: 0.14, green: 0.10, blue: 0.10),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: skyH)
            )
        )

        // Sparse stars filtered through light pollution
        var rng = SplitMix64(seed: 0x4E59)
        for _ in 0..<70 {
            let sx = nextDouble(&rng) * w
            let sy = nextDouble(&rng) * skyH * 0.65
            let ss = 0.5 + nextDouble(&rng) * 1.0
            let twinkle = sin(t * (1.2 + nextDouble(&rng) * 2.5) + nextDouble(&rng) * 6.28) * 0.25 + 0.75
            ctx.fill(
                Ellipse().path(in: CGRect(x: sx - ss / 2, y: sy - ss / 2, width: ss, height: ss)),
                with: .color(.white.opacity(0.35 * twinkle))
            )
        }

        // City-glow haze on the horizon
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 55))
            l.fill(
                Ellipse().path(in: CGRect(x: -w * 0.1, y: skyH * 0.55, width: w * 1.2, height: h * 0.28)),
                with: .color(Color(red: 0.65, green: 0.42, blue: 0.18).opacity(0.14))
            )
        }
    }

    // MARK: - Cityscape  (Morph the Cat / Sunken Condos Manhattan)

    private func drawCityscape(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let horizonY = h * 0.74
        var rng = SplitMix64(seed: 0x2006_NYCT)

        // Background building layer — 20 varied towers
        for i in 0..<20 {
            let bx = w * Double(i) / 20.0 + nextDouble(&rng) * w * 0.03
            let bw = w * (0.055 + nextDouble(&rng) * 0.07)
            let bh = h * (0.12 + nextDouble(&rng) * 0.38)
            let by = horizonY - bh
            let warmth = 0.07 + nextDouble(&rng) * 0.06

            // Building face
            ctx.fill(
                Path(CGRect(x: bx, y: by, width: bw, height: bh + 2)),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: warmth * 1.1, green: warmth * 0.85, blue: warmth * 0.6),
                        Color(red: warmth * 0.75, green: warmth * 0.6, blue: warmth * 0.45),
                    ]),
                    startPoint: CGPoint(x: bx, y: by),
                    endPoint: CGPoint(x: bx, y: horizonY)
                )
            )

            // Water tower on some rooftops
            if nextDouble(&rng) > 0.72 {
                let wtX = bx + bw * 0.25 + nextDouble(&rng) * bw * 0.3
                let wtR = bw * 0.14
                let wtH = h * 0.042
                // Legs
                ctx.fill(
                    Path(CGRect(x: wtX - wtR * 0.08, y: by - wtH * 0.7, width: wtR * 0.18, height: wtH * 0.7)),
                    with: .color(Color(red: 0.11, green: 0.09, blue: 0.07))
                )
                ctx.fill(
                    Path(CGRect(x: wtX + wtR * 0.55, y: by - wtH * 0.7, width: wtR * 0.18, height: wtH * 0.7)),
                    with: .color(Color(red: 0.11, green: 0.09, blue: 0.07))
                )
                // Tank
                var tankPath = Path()
                tankPath.move(to: CGPoint(x: wtX - wtR, y: by - wtH * 0.15))
                tankPath.addLine(to: CGPoint(x: wtX + wtR, y: by - wtH * 0.15))
                tankPath.addLine(to: CGPoint(x: wtX + wtR * 0.78, y: by - wtH))
                tankPath.addLine(to: CGPoint(x: wtX - wtR * 0.78, y: by - wtH))
                tankPath.closeSubpath()
                ctx.fill(tankPath, with: .color(Color(red: 0.14, green: 0.11, blue: 0.08)))
            }

            // Lit windows (Sunken Condos warmth)
            let cols = Int(2 + nextDouble(&rng) * 4)
            let rows = Int(3 + nextDouble(&rng) * 9)
            let cellW = bw / Double(cols + 1)
            let cellH = bh / Double(rows + 2)
            var wRng = SplitMix64(seed: UInt64(i * 41 + 7))
            for row in 0..<rows {
                for col in 0..<cols {
                    guard nextDouble(&wRng) > 0.48 else { continue }
                    let wx = bx + cellW * (Double(col) + 0.5)
                    let wy = by + cellH * (Double(row) + 1.0)
                    let flicker = sin(t * 0.25 + Double(i * 5 + row * 3 + col)) * 0.04 + 0.96
                    ctx.fill(
                        Path(CGRect(x: wx, y: wy, width: cellW * 0.58, height: cellH * 0.48)),
                        with: .color(Color(red: 1.0, green: 0.88, blue: 0.62).opacity(0.72 * flicker))
                    )
                }
            }
        }

        // Radio / broadcast tower (The Nightfly) — tallest structure
        let txX = w * 0.80
        let txBase = horizonY - h * 0.13
        let txTop = h * 0.03
        // Tower body
        ctx.fill(
            Path(CGRect(x: txX - 1.5, y: txTop, width: 3.0, height: txBase - txTop)),
            with: .color(Color(red: 0.18, green: 0.16, blue: 0.12))
        )
        // Cross-braces
        for brace in 0..<5 {
            let by2 = txTop + Double(brace) * (txBase - txTop) / 5.0
            let braceW = 5.0 + Double(brace) * 2.5
            var bracePath = Path()
            bracePath.move(to: CGPoint(x: txX - braceW, y: by2))
            bracePath.addLine(to: CGPoint(x: txX + braceW, y: by2 + (txBase - txTop) / 5.0 * 0.5))
            ctx.stroke(bracePath, with: .color(Color(red: 0.20, green: 0.17, blue: 0.13)), lineWidth: 1.0)
        }
        // Aviation beacon
        let blink = sin(t * 2.5) > 0.45 ? 1.0 : 0.0
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 4))
            l.fill(
                Ellipse().path(in: CGRect(x: txX - 5, y: txTop - 5, width: 10, height: 10)),
                with: .color(Color(red: 1.0, green: 0.18, blue: 0.18).opacity(0.85 * blink))
            )
        }
        ctx.fill(
            Ellipse().path(in: CGRect(x: txX - 2.5, y: txTop - 2.5, width: 5, height: 5)),
            with: .color(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(blink))
        )
    }

    // MARK: - Fog  (Morph the Cat)

    private func drawFog(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 35))
            let a = 0.11 + sin(t * 0.09) * 0.04
            l.fill(
                Path(CGRect(x: -w * 0.1, y: h * 0.52, width: w * 1.2, height: h * 0.28)),
                with: .color(Color(red: 0.50, green: 0.53, blue: 0.62).opacity(a))
            )
        }
    }

    // MARK: - Street  (rain-slicked asphalt)

    private func drawStreet(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let streetTop = h * 0.74

        // Asphalt
        ctx.fill(
            Path(CGRect(x: 0, y: streetTop, width: w, height: h * 0.26)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.09, green: 0.09, blue: 0.11),
                    Color(red: 0.06, green: 0.06, blue: 0.08),
                ]),
                startPoint: CGPoint(x: 0, y: streetTop),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        // Rain reflections of city lights
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 9))
            var rng = SplitMix64(seed: 0xABCD)
            for i in 0..<14 {
                let rx = nextDouble(&rng) * w
                let ry = streetTop + nextDouble(&rng) * h * 0.18
                let rw = 5.0 + nextDouble(&rng) * 18.0
                let rh = 28.0 + nextDouble(&rng) * 55.0
                let warmth = 0.7 + nextDouble(&rng) * 0.3
                l.fill(
                    Ellipse().path(in: CGRect(x: rx - rw / 2, y: ry, width: rw, height: rh)),
                    with: .color(
                        Color(red: warmth, green: warmth * 0.82, blue: warmth * 0.45)
                            .opacity(0.16 + sin(t * 0.38 + Double(i)) * 0.05)
                    )
                )
            }
        }

        // Kerb line
        ctx.fill(
            Path(CGRect(x: 0, y: streetTop, width: w, height: 7)),
            with: .color(Color(red: 0.16, green: 0.15, blue: 0.16))
        )

        // Street lane markings
        for i in 0..<7 {
            let mx = w * Double(i) / 6.0
            ctx.fill(
                Path(CGRect(x: mx - w * 0.03, y: streetTop + h * 0.12, width: w * 0.055, height: 2.5)),
                with: .color(Color(red: 0.32, green: 0.30, blue: 0.22).opacity(0.45))
            )
        }

        // Street lamps — sodium orange (Morph the Cat)
        for lampI in 0..<4 {
            let lx = w * (Double(lampI) + 0.5) / 4.0
            let lPoleTop = streetTop - h * 0.13
            // Pole
            ctx.fill(
                Path(CGRect(x: lx - 1.5, y: lPoleTop, width: 3, height: h * 0.13 + 7)),
                with: .color(Color(red: 0.20, green: 0.18, blue: 0.14))
            )
            // Arm
            var armPath = Path()
            armPath.move(to: CGPoint(x: lx, y: lPoleTop + 5))
            armPath.addCurve(
                to: CGPoint(x: lx + 18, y: lPoleTop),
                control1: CGPoint(x: lx + 8, y: lPoleTop + 3),
                control2: CGPoint(x: lx + 15, y: lPoleTop + 1)
            )
            ctx.stroke(armPath, with: .color(Color(red: 0.20, green: 0.18, blue: 0.14)), lineWidth: 2.5)
            // Halo
            let flicker = 0.95 + sin(t * 0.17 + Double(lampI) * 1.9) * 0.05
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 14))
                l.fill(
                    Ellipse().path(in: CGRect(x: lx + 8, y: lPoleTop - 10, width: 26, height: 20)),
                    with: .color(Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.50 * flicker))
                )
            }
            ctx.fill(
                Ellipse().path(in: CGRect(x: lx + 14, y: lPoleTop - 5, width: 10, height: 7)),
                with: .color(Color(red: 1.0, green: 0.95, blue: 0.72).opacity(0.92))
            )
        }
    }

    // MARK: - Steam from street grates  (Kamakiriad)

    private func drawSteam(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let streetTop = h * 0.74
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 7))
            for puff in steamPuffs {
                let px = puff.x * w
                let life = fmod(t * puff.speed + puff.phase, 1.0)
                let py = streetTop - life * h * 0.28
                let alpha = (1.0 - life) * (1.0 - life) * 0.38
                let sz = 11 + life * 38
                l.fill(
                    Ellipse().path(in: CGRect(x: px - sz / 2, y: py - sz * 0.7, width: sz, height: sz * 1.4)),
                    with: .color(Color(red: 0.72, green: 0.76, blue: 0.82).opacity(alpha))
                )
            }
        }
    }

    // MARK: - Kamakiriad vehicle

    private func drawKamakiriad(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let streetTop = h * 0.74
        // Slow idle drift
        let carX = w * 0.54 + sin(t * 0.04) * w * 0.015
        let carY = streetTop + h * 0.028
        let carW = w * 0.20
        let carH = h * 0.058

        // Sleek aerodynamic body
        var bodyPath = Path()
        bodyPath.move(to: CGPoint(x: carX, y: carY + carH))
        bodyPath.addLine(to: CGPoint(x: carX + carW, y: carY + carH))
        bodyPath.addLine(to: CGPoint(x: carX + carW * 1.04, y: carY + carH * 0.52))
        bodyPath.addQuadCurve(
            to: CGPoint(x: carX + carW * 0.68, y: carY),
            control: CGPoint(x: carX + carW * 1.0, y: carY + carH * 0.08)
        )
        bodyPath.addQuadCurve(
            to: CGPoint(x: carX + carW * 0.14, y: carY),
            control: CGPoint(x: carX + carW * 0.48, y: carY - carH * 0.28)
        )
        bodyPath.addQuadCurve(
            to: CGPoint(x: carX - carW * 0.04, y: carY + carH * 0.52),
            control: CGPoint(x: carX, y: carY + carH * 0.09)
        )
        bodyPath.closeSubpath()

        ctx.fill(bodyPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.22, green: 0.24, blue: 0.30),
                Color(red: 0.10, green: 0.11, blue: 0.15),
            ]),
            startPoint: CGPoint(x: carX, y: carY),
            endPoint: CGPoint(x: carX, y: carY + carH)
        ))
        // Subtle sheen
        ctx.fill(bodyPath, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.55, green: 0.60, blue: 0.72).opacity(0.12),
                Color.clear,
            ]),
            startPoint: CGPoint(x: carX, y: carY),
            endPoint: CGPoint(x: carX, y: carY + carH * 0.5)
        ))

        // Steam exhaust — Kamakiriad is steam-powered
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 8))
            let exX = carX + carW * 0.91
            let exY = carY + carH * 0.38
            for i in 0..<4 {
                let phase = fmod(t * 0.85 + Double(i) * 0.28, 1.0)
                let ey = exY - phase * carH * 2.2
                let er = 4.5 + phase * 11.0
                l.fill(
                    Ellipse().path(in: CGRect(x: exX - er / 2, y: ey - er / 2, width: er, height: er)),
                    with: .color(Color(red: 0.82, green: 0.86, blue: 0.92).opacity((1.0 - phase) * 0.55))
                )
            }
        }

        // Headlights
        let headY = carY + carH * 0.38
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 22))
            l.fill(
                Ellipse().path(in: CGRect(x: carX - 32, y: headY - 14, width: 44, height: 28)),
                with: .color(Color(red: 0.90, green: 0.86, blue: 0.70).opacity(0.28))
            )
        }
        ctx.fill(
            Ellipse().path(in: CGRect(x: carX - 4, y: headY - 3, width: 7, height: 6)),
            with: .color(Color(red: 1.0, green: 0.96, blue: 0.82))
        )

        // Rear blue running light (futuristic)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 6))
            l.fill(
                Ellipse().path(in: CGRect(x: carX + carW * 0.94, y: carY + carH * 0.42, width: 11, height: 7)),
                with: .color(Color(red: 0.28, green: 0.50, blue: 1.0).opacity(0.65))
            )
        }

        // Wheels
        for wDX in [carX + carW * 0.17, carX + carW * 0.76] {
            let wr = carH * 0.36
            ctx.fill(
                Ellipse().path(in: CGRect(x: wDX - wr, y: carY + carH * 0.72, width: wr * 2, height: wr * 2)),
                with: .color(Color(red: 0.07, green: 0.07, blue: 0.09))
            )
            ctx.stroke(
                Ellipse().path(in: CGRect(x: wDX - wr, y: carY + carH * 0.72, width: wr * 2, height: wr * 2)),
                with: .color(Color(red: 0.28, green: 0.24, blue: 0.20)),
                lineWidth: 1.5
            )
        }
    }

    // MARK: - Cat  (Morph the Cat)

    private func drawCat(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        // Silhouette on a rooftop — watching the city
        let catX = w * 0.24
        let catY = h * 0.41
        let cs = w * 0.020      // scale unit

        // Tail — slow graceful sway
        let sway = sin(t * 0.75) * 0.32
        var tailPath = Path()
        tailPath.move(to: CGPoint(x: catX - cs * 0.9, y: catY))
        tailPath.addCurve(
            to: CGPoint(x: catX - cs * 2.1, y: catY - cs * 0.6),
            control1: CGPoint(x: catX - cs * 1.3, y: catY + cs * 0.35 + sway * cs),
            control2: CGPoint(x: catX - cs * 1.8, y: catY - cs * 0.15 + sway * cs * 0.5)
        )
        ctx.stroke(tailPath,
                   with: .color(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.92)),
                   lineWidth: cs * 0.38)

        // Body
        ctx.fill(
            Ellipse().path(in: CGRect(x: catX - cs, y: catY - cs * 0.55, width: cs * 2.0, height: cs * 1.15)),
            with: .color(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.92))
        )

        // Head
        ctx.fill(
            Ellipse().path(in: CGRect(x: catX - cs * 0.52, y: catY - cs * 1.52, width: cs * 1.04, height: cs * 1.0)),
            with: .color(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.92))
        )

        // Ears
        for earDir in [-1.0, 1.0] {
            let ex = catX + earDir * cs * 0.28
            var earPath = Path()
            earPath.move(to: CGPoint(x: ex - cs * 0.18, y: catY - cs * 1.52))
            earPath.addLine(to: CGPoint(x: ex, y: catY - cs * 2.12))
            earPath.addLine(to: CGPoint(x: ex + cs * 0.18, y: catY - cs * 1.52))
            earPath.closeSubpath()
            ctx.fill(earPath, with: .color(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.92)))
        }

        // Eyes — amber gleam
        let eyeGlow = sin(t * 0.55) * 0.12 + 0.88
        for exDir in [-1.0, 1.0] {
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 2))
                l.fill(
                    Ellipse().path(in: CGRect(
                        x: catX + exDir * cs * 0.24 - 2,
                        y: catY - cs * 1.07 - 1.5,
                        width: 4, height: 3
                    )),
                    with: .color(Color(red: 0.92, green: 0.70, blue: 0.18).opacity(0.65 * eyeGlow))
                )
            }
        }
    }

    // MARK: - Window frame  (we're inside the studio)

    private func drawWindowFrame(ctx: inout GraphicsContext, w: Double, h: Double) {
        let fw = w * 0.07

        // Left drape of darkness
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: fw, height: h)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.11, green: 0.09, blue: 0.07),
                    Color(red: 0.11, green: 0.09, blue: 0.07).opacity(0),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: fw, y: 0)
            )
        )
        // Right drape of darkness
        ctx.fill(
            Path(CGRect(x: w - fw, y: 0, width: fw, height: h)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.11, green: 0.09, blue: 0.07).opacity(0),
                    Color(red: 0.11, green: 0.09, blue: 0.07),
                ]),
                startPoint: CGPoint(x: w - fw, y: 0),
                endPoint: CGPoint(x: w, y: 0)
            )
        )
        // Window sill
        ctx.fill(
            Path(CGRect(x: 0, y: h * 0.74, width: w, height: h * 0.018)),
            with: .color(Color(red: 0.16, green: 0.13, blue: 0.10))
        )
        // Reflection of console on sill
        ctx.fill(
            Path(CGRect(x: 0, y: h * 0.74 + h * 0.018, width: w, height: 1.5)),
            with: .color(Color(red: 0.40, green: 0.35, blue: 0.28).opacity(0.3))
        )
    }

    // MARK: - Mixing console  (The Nightfly)

    private func drawControlBoard(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let boardY = h * 0.79
        let boardH = h * 0.21

        // Console surface
        ctx.fill(
            Path(CGRect(x: 0, y: boardY, width: w, height: boardH)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.19, green: 0.17, blue: 0.14),
                    Color(red: 0.11, green: 0.10, blue: 0.09),
                ]),
                startPoint: CGPoint(x: 0, y: boardY),
                endPoint: CGPoint(x: 0, y: h)
            )
        )
        // Sheen
        ctx.fill(
            Path(CGRect(x: 0, y: boardY, width: w, height: 2)),
            with: .color(Color(red: 0.58, green: 0.50, blue: 0.40).opacity(0.45))
        )

        // Fader bank — 14 channels
        let faderCount = 14
        for i in 0..<faderCount {
            let fx = w * 0.04 + Double(i) * (w * 0.066)
            let trackH = boardH * 0.52
            let fy = boardY + boardH * 0.10

            // Track groove
            ctx.fill(
                Path(CGRect(x: fx - 1.5, y: fy, width: 3, height: trackH)),
                with: .color(Color(red: 0.07, green: 0.07, blue: 0.08))
            )
            // Fader cap
            var rng = SplitMix64(seed: UInt64(i * 19 + 3))
            let pos = 0.18 + nextDouble(&rng) * 0.64
            let capY = fy + trackH * (1.0 - pos)
            ctx.fill(
                Path(CGRect(x: fx - 6.5, y: capY - 4, width: 13, height: 8)),
                with: .color(Color(red: 0.46, green: 0.41, blue: 0.35))
            )
            ctx.fill(
                Path(CGRect(x: fx - 4.5, y: capY - 1, width: 9, height: 2)),
                with: .color(Color(red: 0.66, green: 0.60, blue: 0.52).opacity(0.55))
            )
        }

        // Knobs
        let knobCount = 9
        for i in 0..<knobCount {
            let kx = w * 0.055 + Double(i) * (w * 0.104)
            let ky = boardY + boardH * 0.78
            let kr = w * 0.017

            ctx.fill(
                Ellipse().path(in: CGRect(x: kx - kr, y: ky - kr, width: kr * 2, height: kr * 2)),
                with: .color(Color(red: 0.28, green: 0.25, blue: 0.21))
            )
            ctx.stroke(
                Ellipse().path(in: CGRect(x: kx - kr, y: ky - kr, width: kr * 2, height: kr * 2)),
                with: .color(Color(red: 0.46, green: 0.41, blue: 0.35).opacity(0.45)),
                lineWidth: 1.0
            )
            var rng = SplitMix64(seed: UInt64(i * 29 + 13))
            let angle = (0.25 + nextDouble(&rng) * 0.75) * .pi * 1.5 - .pi * 0.75
            let dx = cos(angle) * kr * 0.64
            let dy = sin(angle) * kr * 0.64
            ctx.fill(
                Ellipse().path(in: CGRect(x: kx + dx - 1.5, y: ky + dy - 1.5, width: 3, height: 3)),
                with: .color(Color(red: 0.85, green: 0.80, blue: 0.68).opacity(0.8))
            )
        }

        // ON AIR button — pulsing red
        let oaX = w * 0.89
        let oaY = boardY + boardH * 0.52
        let oaR = w * 0.023
        let oaPulse = sin(t * 1.85) * 0.22 + 0.78
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 9))
            l.fill(
                Ellipse().path(in: CGRect(x: oaX - oaR * 2, y: oaY - oaR * 2, width: oaR * 4, height: oaR * 4)),
                with: .color(Color(red: 1.0, green: 0.08, blue: 0.08).opacity(0.42 * oaPulse))
            )
        }
        ctx.fill(
            Ellipse().path(in: CGRect(x: oaX - oaR, y: oaY - oaR, width: oaR * 2, height: oaR * 2)),
            with: .color(Color(red: 0.88, green: 0.07, blue: 0.07).opacity(0.80 + oaPulse * 0.20))
        )

        // Small indicator LEDs
        for ledI in 0..<5 {
            let lx = w * 0.82 + Double(ledI) * w * 0.018
            let ly = boardY + boardH * 0.72
            let ledOn = sin(t * 3.2 + Double(ledI) * 1.1) > 0.2
            let ledColor: Color = ledOn
                ? Color(red: 0.1, green: 0.9, blue: 0.35)
                : Color(red: 0.05, green: 0.18, blue: 0.08)
            ctx.fill(
                Ellipse().path(in: CGRect(x: lx - 2, y: ly - 2, width: 4, height: 4)),
                with: .color(ledColor)
            )
        }
    }

    // MARK: - Reel-to-reel  (The Nightfly)

    private func drawReelToReel(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let r2rX = w * 0.70
        let r2rY = h * 0.65
        let reelR = w * 0.062

        // Machine housing
        ctx.fill(
            Path(CGRect(
                x: r2rX - reelR * 1.45, y: r2rY - reelR * 0.45,
                width: reelR * 2.90, height: reelR * 1.85
            )),
            with: .color(Color(red: 0.14, green: 0.12, blue: 0.10))
        )
        ctx.stroke(
            Path(CGRect(
                x: r2rX - reelR * 1.45, y: r2rY - reelR * 0.45,
                width: reelR * 2.90, height: reelR * 1.85
            )),
            with: .color(Color(red: 0.30, green: 0.26, blue: 0.20).opacity(0.35)),
            lineWidth: 1.0
        )

        // Two reels
        for (dX, dir) in [(-reelR * 0.68, 1.0), (reelR * 0.68, -0.65)] {
            let rx = r2rX + dX
            let ry = r2rY
            let spinAngle = t * 0.38 * dir

            // Tape body
            ctx.fill(
                Ellipse().path(in: CGRect(x: rx - reelR, y: ry - reelR, width: reelR * 2, height: reelR * 2)),
                with: .color(Color(red: 0.21, green: 0.19, blue: 0.16))
            )
            // Spokes
            for spoke in 0..<6 {
                let sa = spinAngle + Double(spoke) * .pi / 3.0
                var spk = Path()
                spk.move(to: CGPoint(x: rx + cos(sa) * reelR * 0.18, y: ry + sin(sa) * reelR * 0.18))
                spk.addLine(to: CGPoint(x: rx + cos(sa) * reelR * 0.84, y: ry + sin(sa) * reelR * 0.84))
                ctx.stroke(spk, with: .color(Color(red: 0.38, green: 0.33, blue: 0.26)), lineWidth: 1.5)
            }
            // Rim
            ctx.stroke(
                Ellipse().path(in: CGRect(x: rx - reelR, y: ry - reelR, width: reelR * 2, height: reelR * 2)),
                with: .color(Color(red: 0.36, green: 0.30, blue: 0.24)),
                lineWidth: 1.5
            )
            // Hub
            ctx.fill(
                Ellipse().path(in: CGRect(x: rx - reelR * 0.14, y: ry - reelR * 0.14, width: reelR * 0.28, height: reelR * 0.28)),
                with: .color(Color(red: 0.46, green: 0.41, blue: 0.34))
            )
        }

        // Tape ribbon between reels
        var tapePath = Path()
        tapePath.move(to: CGPoint(x: r2rX - reelR * 0.68 + reelR * 0.84, y: r2rY))
        tapePath.addLine(to: CGPoint(x: r2rX + reelR * 0.68 - reelR * 0.84, y: r2rY))
        ctx.stroke(tapePath, with: .color(Color(red: 0.16, green: 0.14, blue: 0.11)), lineWidth: 3.0)
    }

    // MARK: - Ribbon microphone  (The Nightfly)

    private func drawMicrophone(ctx: inout GraphicsContext, w: Double, h: Double) {
        let micX = w * 0.49
        let micY = h * 0.595
        let micW = w * 0.022
        let micH = h * 0.115

        // Boom arm
        var boom = Path()
        boom.move(to: CGPoint(x: micX - w * 0.115, y: micY + micH * 0.55))
        boom.addLine(to: CGPoint(x: micX + w * 0.038, y: micY))
        ctx.stroke(boom, with: .color(Color(red: 0.30, green: 0.27, blue: 0.23)), lineWidth: 2.5)

        // Vertical stand
        ctx.fill(
            Path(CGRect(x: micX - w * 0.115 - 1.5, y: micY + micH * 0.55, width: 3, height: h * 0.19)),
            with: .color(Color(red: 0.27, green: 0.24, blue: 0.20))
        )

        // Base
        var base = Path()
        base.move(to: CGPoint(x: micX - w * 0.115 - w * 0.038, y: micY + micH * 0.55 + h * 0.19))
        base.addLine(to: CGPoint(x: micX - w * 0.115 + w * 0.038, y: micY + micH * 0.55 + h * 0.19))
        ctx.stroke(base, with: .color(Color(red: 0.27, green: 0.24, blue: 0.20)), lineWidth: 3.0)

        // Capsule — vintage ribbon shape
        var cap = Path()
        cap.addRoundedRect(
            in: CGRect(x: micX + w * 0.038 - micW / 2, y: micY - micH / 2, width: micW, height: micH),
            cornerSize: CGSize(width: micW * 0.45, height: micW * 0.45)
        )
        ctx.fill(cap, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.56, green: 0.50, blue: 0.42),
                Color(red: 0.34, green: 0.29, blue: 0.24),
            ]),
            startPoint: CGPoint(x: micX - micW, y: micY),
            endPoint: CGPoint(x: micX + micW, y: micY)
        ))

        // Mesh lines
        for i in 0..<6 {
            let ly = micY - micH * 0.42 + Double(i) * micH * 0.16
            ctx.fill(
                Path(CGRect(x: micX + w * 0.038 - micW / 2 + 2.5, y: ly, width: micW - 5, height: 0.8)),
                with: .color(Color(red: 0.22, green: 0.19, blue: 0.15).opacity(0.7))
            )
        }
    }

    // MARK: - VU meters  (The Nightfly — pulsing to imagined music)

    private func drawVUMeters(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let vuX = w * 0.84
        let vuY = h * 0.590
        let vuW = w * 0.12
        let vuH = h * 0.135

        // Panel
        ctx.fill(
            Path(CGRect(x: vuX, y: vuY, width: vuW, height: vuH)),
            with: .color(Color(red: 0.05, green: 0.055, blue: 0.065))
        )
        ctx.stroke(
            Path(CGRect(x: vuX, y: vuY, width: vuW, height: vuH)),
            with: .color(Color(red: 0.30, green: 0.25, blue: 0.18).opacity(0.35)),
            lineWidth: 1.0
        )

        // Left + Right channel columns
        for ch in 0..<2 {
            let chX = vuX + vuW * (0.10 + Double(ch) * 0.50)
            let chW = vuW * 0.34
            let chH = vuH * 0.76
            let chY = vuY + vuH * 0.11

            let seed = Double(ch) * 8.1
            let level = min(1.0,
                0.28
                + abs(sin(t * 1.15 + seed)) * 0.30
                + abs(sin(t * 2.85 + seed * 1.4)) * 0.22
                + abs(sin(t * 5.5 + seed * 0.8)) * 0.18
            )

            let segCount = 16
            let peakSeg = Int(Double(segCount) * min(1.0, level + 0.07))

            for seg in 0..<segCount {
                let segY = chY + chH * (1.0 - Double(seg + 1) / Double(segCount))
                let segH = chH / Double(segCount) * 0.84
                let filled = Double(seg) / Double(segCount) < level

                let segColor: Color
                if seg >= segCount - 3 {
                    segColor = filled
                        ? Color(red: 1.0, green: 0.12, blue: 0.08)
                        : Color(red: 0.20, green: 0.05, blue: 0.05)
                } else if seg >= segCount - 6 {
                    segColor = filled
                        ? Color(red: 1.0, green: 0.78, blue: 0.04)
                        : Color(red: 0.20, green: 0.15, blue: 0.02)
                } else {
                    segColor = filled
                        ? Color(red: 0.08, green: 0.88, blue: 0.28)
                        : Color(red: 0.04, green: 0.17, blue: 0.07)
                }
                ctx.fill(
                    Path(CGRect(x: chX, y: segY, width: chW, height: segH)),
                    with: .color(segColor)
                )
                // Peak hold dot
                if seg == peakSeg - 1 && seg >= segCount / 2 {
                    ctx.fill(
                        Path(CGRect(x: chX, y: segY, width: chW, height: segH)),
                        with: .color(Color(red: 1.0, green: 0.92, blue: 0.55))
                    )
                }
            }

            // Channel label
            ctx.draw(
                Text(ch == 0 ? "L" : "R")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.55, green: 0.50, blue: 0.38)),
                at: CGPoint(x: chX + chW / 2, y: vuY + vuH * 0.93)
            )
        }
    }

    // MARK: - Signal ripples  (tap interaction — broadcasting)

    private func drawSignalRipples(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        for ripple in ripples {
            let age = t - ripple.birth
            guard age < 3.2 else { continue }
            for ring in 0..<3 {
                let delay = Double(ring) * 0.28
                let rAge = age - delay
                guard rAge > 0 else { continue }
                let progress = rAge / 2.6
                guard progress < 1.0 else { continue }
                let radius = progress * w * 0.52
                let alpha = (1.0 - progress) * 0.45
                // Slightly elliptical to suggest broadcast waves
                ctx.stroke(
                    Ellipse().path(in: CGRect(
                        x: w * 0.5 - radius, y: h * 0.38 - radius * 0.58,
                        width: radius * 2, height: radius * 1.16
                    )),
                    with: .color(Color(red: 0.32, green: 0.62, blue: 1.0).opacity(alpha)),
                    lineWidth: 1.5 * (1.0 - progress)
                )
            }
        }
    }
}
