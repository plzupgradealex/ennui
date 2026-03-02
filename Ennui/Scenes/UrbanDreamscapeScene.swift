import SwiftUI

// Urban Dreamscape — Paris + Tokyo + Rome + Istanbul + NYC + Chicago
// A cel-shaded PS1-style city panorama at twilight. Neon signs in
// katakana, the Eiffel Tower silhouette, Roman domes, Ottoman minarets,
// Manhattan grid lights, Chicago el-train, all blended into a single
// impossible skyline. Low-poly aesthetic with vertex jitter, dithered
// gradients, scanlines. Puddles reflect the city. Rain streaks.
// Tap to flash neon signs and send ripples through puddles.

struct UrbanDreamscapeScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()
    @State private var ready = false
    @State private var neonFlashes: [(x: Double, birth: Double)] = []

    // PS1 pixel snap
    private func snap(_ v: Double, grid: Double = 3) -> Double {
        (v / grid).rounded(.down) * grid
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawDistantSkyline(ctx: &ctx, size: size, t: t)
                drawLandmarks(ctx: &ctx, size: size, t: t)
                drawMainSkyline(ctx: &ctx, size: size, t: t)
                drawNeonSigns(ctx: &ctx, size: size, t: t)
                drawStreetLevel(ctx: &ctx, size: size, t: t)
                drawPuddles(ctx: &ctx, size: size, t: t)
                drawElTrain(ctx: &ctx, size: size, t: t)
                drawRain(ctx: &ctx, size: size, t: t)
                drawPuddleRipples(ctx: &ctx, size: size, t: t)
                drawScanlines(ctx: &ctx, size: size, t: t)
                drawDither(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.04, green: 0.02, blue: 0.08))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear { ready = true }
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            neonFlashes.append((x: loc.x, birth: Date().timeIntervalSince(startDate)))
            if neonFlashes.count > 6 { neonFlashes.removeFirst() }
        }
    }

    // MARK: - Sky

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Quantized twilight gradient — PS1 banding
        let bands = 18
        let bandH = size.height * 0.7 / Double(bands)
        for i in 0..<bands {
            let frac = Double(i) / Double(bands)
            let r = snap(0.12 + frac * 0.15, grid: 0.04)
            let g = snap(0.03 + frac * 0.04, grid: 0.02)
            let b = snap(0.18 - frac * 0.06, grid: 0.03)
            let y = Double(i) * bandH
            ctx.fill(Rectangle().path(in: CGRect(x: 0, y: y, width: size.width, height: bandH + 1)),
                with: .color(Color(red: r, green: g, blue: b)))
        }
        // Horizon warm band
        let horzY = size.height * 0.55
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: horzY, width: size.width, height: 30)),
            with: .color(Color(red: 0.3, green: 0.12, blue: 0.08).opacity(0.3)))
    }

    // MARK: - Stars (square pixels)

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xC1A5DAE)
        for _ in 0..<120 {
            let x = snap(nextDouble(&rng) * size.width)
            let y = snap(nextDouble(&rng) * size.height * 0.45)
            let s = snap(nextDouble(&rng) * 2 + 1, grid: 1)
            let b = nextDouble(&rng) * 0.4 + 0.2
            let tw = sin(t * (0.5 + nextDouble(&rng)) + nextDouble(&rng) * 6.28) * 0.3 + 0.7
            ctx.fill(Rectangle().path(in: CGRect(x: x, y: y, width: s, height: s)),
                with: .color(.white.opacity(b * tw)))
        }
    }

    // MARK: - Distant skyline silhouette

    private func drawDistantSkyline(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xD15AA00)
        let baseY = size.height * 0.52
        for _ in 0..<50 {
            let x = snap(nextDouble(&rng) * size.width)
            let w = snap(3 + nextDouble(&rng) * 8)
            let h = snap(8 + nextDouble(&rng) * 50)
            ctx.fill(Rectangle().path(in: CGRect(x: x, y: baseY - h, width: w, height: h)),
                with: .color(Color(red: 0.06, green: 0.04, blue: 0.10).opacity(0.6)))
        }
    }

    // MARK: - Iconic landmarks (silhouettes + details)

    private func drawLandmarks(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let baseY = size.height * 0.58

        // Eiffel Tower (left quarter)
        let eifX = size.width * 0.12
        let eifH = 200.0
        var eif = Path()
        eif.move(to: CGPoint(x: snap(eifX - 30), y: snap(baseY)))
        eif.addLine(to: CGPoint(x: snap(eifX - 6), y: snap(baseY - eifH * 0.6)))
        eif.addLine(to: CGPoint(x: snap(eifX - 3), y: snap(baseY - eifH)))
        eif.addLine(to: CGPoint(x: snap(eifX + 3), y: snap(baseY - eifH)))
        eif.addLine(to: CGPoint(x: snap(eifX + 6), y: snap(baseY - eifH * 0.6)))
        eif.addLine(to: CGPoint(x: snap(eifX + 30), y: snap(baseY)))
        eif.closeSubpath()
        ctx.fill(eif, with: .color(Color(red: 0.10, green: 0.08, blue: 0.14)))
        // Cross beams
        for frac in [0.3, 0.6, 0.85] {
            let beamY = snap(baseY - eifH * frac)
            let halfW = 30 * (1 - frac * 0.8)
            ctx.fill(Rectangle().path(in: CGRect(x: snap(eifX - halfW), y: beamY, width: snap(halfW * 2), height: 2)),
                with: .color(Color(red: 0.12, green: 0.10, blue: 0.16)))
        }
        // Light beacon
        let beaconPulse = sin(t * 2) > 0.5
        if beaconPulse {
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 10))
                l.fill(Ellipse().path(in: CGRect(x: eifX - 6, y: baseY - eifH - 6, width: 12, height: 12)),
                    with: .color(Color(red: 1.4, green: 1.2, blue: 0.8).opacity(0.4)))
            }
        }

        // Ottoman minarets (Istanbul, centre-left)
        let minX = size.width * 0.35
        for i in 0..<2 {
            let mx = snap(minX + Double(i) * 40 - 20)
            let mh = 140 + Double(i) * 20
            ctx.fill(Rectangle().path(in: CGRect(x: mx - 4, y: snap(baseY - mh), width: 8, height: snap(mh))),
                with: .color(Color(red: 0.09, green: 0.07, blue: 0.12)))
            // Pointed top
            var top = Path()
            top.move(to: CGPoint(x: mx - 6, y: snap(baseY - mh)))
            top.addLine(to: CGPoint(x: mx, y: snap(baseY - mh - 18)))
            top.addLine(to: CGPoint(x: mx + 6, y: snap(baseY - mh)))
            top.closeSubpath()
            ctx.fill(top, with: .color(Color(red: 0.09, green: 0.07, blue: 0.12)))
        }
        // Dome
        let domeX = snap(minX)
        let domeY = snap(baseY - 80)
        ctx.fill(Ellipse().path(in: CGRect(x: domeX - 25, y: domeY - 22, width: 50, height: 28)),
            with: .color(Color(red: 0.09, green: 0.07, blue: 0.12)))
        ctx.fill(Rectangle().path(in: CGRect(x: domeX - 30, y: domeY, width: 60, height: 80)),
            with: .color(Color(red: 0.08, green: 0.06, blue: 0.11)))

        // Roman dome / Pantheon (centre)
        let panX = snap(size.width * 0.52)
        let panY = snap(baseY - 60)
        ctx.fill(Rectangle().path(in: CGRect(x: panX - 40, y: panY, width: 80, height: 60)),
            with: .color(Color(red: 0.10, green: 0.08, blue: 0.13)))
        // Columns
        for c in 0..<6 {
            let cx = panX - 35 + Double(c) * 14
            ctx.fill(Rectangle().path(in: CGRect(x: snap(cx), y: panY, width: 3, height: 60)),
                with: .color(Color(red: 0.12, green: 0.10, blue: 0.15).opacity(0.5)))
        }
        // Dome
        var dome = Path()
        dome.addArc(center: CGPoint(x: panX, y: panY), radius: 35,
                   startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        ctx.fill(dome, with: .color(Color(red: 0.09, green: 0.07, blue: 0.12)))

        // Tokyo Tower (right-centre)
        let ttX = snap(size.width * 0.72)
        let ttH = 170.0
        var tt = Path()
        tt.move(to: CGPoint(x: snap(ttX - 20), y: snap(baseY)))
        tt.addLine(to: CGPoint(x: snap(ttX - 3), y: snap(baseY - ttH)))
        tt.addLine(to: CGPoint(x: snap(ttX + 3), y: snap(baseY - ttH)))
        tt.addLine(to: CGPoint(x: snap(ttX + 20), y: snap(baseY)))
        tt.closeSubpath()
        ctx.fill(tt, with: .color(Color(red: 0.20, green: 0.06, blue: 0.04)))
        // White bands
        for frac in stride(from: 0.1, through: 0.9, by: 0.2) {
            let bY = snap(baseY - ttH * frac)
            let hw = 20 * (1 - frac * 0.8)
            ctx.fill(Rectangle().path(in: CGRect(x: snap(ttX - hw), y: bY, width: snap(hw * 2), height: 3)),
                with: .color(.white.opacity(0.15)))
        }
        // Top blink
        let ttBlink = sin(t * 1.5 + 1) > 0.6
        if ttBlink {
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 8))
                l.fill(Ellipse().path(in: CGRect(x: ttX - 5, y: baseY - ttH - 8, width: 10, height: 10)),
                    with: .color(Color(red: 1.4, green: 0.3, blue: 0.2).opacity(0.5)))
            }
        }

        // NYC/Chicago skyscrapers (right)
        var rng = SplitMix64(seed: 0xBAC0E3A)
        for _ in 0..<8 {
            let bx = snap(size.width * 0.82 + nextDouble(&rng) * size.width * 0.16)
            let bw = snap(12 + nextDouble(&rng) * 18)
            let bh = snap(80 + nextDouble(&rng) * 140)
            let br = 0.07 + nextDouble(&rng) * 0.04
            let bg = 0.06 + nextDouble(&rng) * 0.03
            let bb = 0.10 + nextDouble(&rng) * 0.04
            ctx.fill(Rectangle().path(in: CGRect(x: bx, y: snap(baseY - bh), width: bw, height: snap(bh))),
                with: .color(Color(red: br, green: bg, blue: bb)))
            // Windows: grid of lit squares
            let wGridX = 4, wGridY = Int(bh / 8)
            for wy in 0..<wGridY {
                for wx in 0..<wGridX {
                    if nextDouble(&rng) > 0.5 {
                        let winX = bx + 2 + Double(wx) * (bw - 4) / Double(wGridX)
                        let winY = baseY - bh + 4 + Double(wy) * 8
                        let wFlick = sin(t * 0.3 + nextDouble(&rng) * 10) * 0.1 + 0.9
                        ctx.fill(Rectangle().path(in: CGRect(x: snap(winX), y: snap(winY), width: 2, height: 3)),
                            with: .color(Color(red: 1.1 * wFlick, green: 0.9 * wFlick, blue: 0.5).opacity(0.5)))
                    }
                }
            }
        }
    }

    // MARK: - Main foreground skyline

    private func drawMainSkyline(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let baseY = size.height * 0.65
        var rng = SplitMix64(seed: 0xFACE514)
        for _ in 0..<24 {
            let x = snap(nextDouble(&rng) * size.width)
            let w = snap(14 + nextDouble(&rng) * 28)
            let h = snap(30 + nextDouble(&rng) * 95)
            let r = 0.08 + nextDouble(&rng) * 0.06
            let g = 0.06 + nextDouble(&rng) * 0.04
            let b = 0.11 + nextDouble(&rng) * 0.05

            ctx.fill(Rectangle().path(in: CGRect(x: x, y: snap(baseY - h), width: w, height: snap(h))),
                with: .color(Color(red: r, green: g, blue: b)))

            // Lit windows
            let cols = Int(w / 6)
            let rows = Int(h / 10)
            for row in 0..<rows {
                for col in 0..<cols {
                    if nextDouble(&rng) > 0.4 {
                        let wx = x + 2 + Double(col) * 6
                        let wy = baseY - h + 3 + Double(row) * 10
                        let flick = sin(t * 0.4 + nextDouble(&rng) * 8) * 0.12 + 0.88
                        let warmOrCool = nextDouble(&rng) > 0.3
                        if warmOrCool {
                            ctx.fill(Rectangle().path(in: CGRect(x: snap(wx), y: snap(wy), width: 3, height: 3)),
                                with: .color(Color(red: 1.1 * flick, green: 0.85 * flick, blue: 0.4).opacity(0.6)))
                        } else {
                            ctx.fill(Rectangle().path(in: CGRect(x: snap(wx), y: snap(wy), width: 3, height: 3)),
                                with: .color(Color(red: 0.4, green: 0.6 * flick, blue: 1.1 * flick).opacity(0.5)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Neon signs (katakana + diner + bar)

    private func drawNeonSigns(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let baseY = size.height * 0.6
        // Fixed neon sign positions
        let signs: [(x: Double, y: Double, color: (Double, Double, Double), flicker: Double)] = [
            (0.15, 0.50, (1.4, 0.3, 0.8), 1.2),   // magenta
            (0.30, 0.52, (0.3, 1.4, 0.5), 0.8),    // green
            (0.48, 0.48, (1.4, 0.8, 0.2), 1.5),    // amber
            (0.62, 0.53, (0.3, 0.5, 1.5), 1.0),    // blue
            (0.78, 0.50, (1.5, 0.3, 0.3), 0.9),    // red
            (0.88, 0.52, (0.8, 0.3, 1.4), 1.3),    // purple
        ]

        for (i, sign) in signs.enumerated() {
            let sx = snap(sign.x * size.width)
            let sy = snap(sign.y * size.height)
            let on = sin(t * sign.flicker + Double(i) * 2.1) > -0.3

            // Check for flash amplification from taps
            var flashBoost = 0.0
            for flash in neonFlashes {
                let age = Date().timeIntervalSince(startDate) - flash.birth
                if age < 1.5 {
                    let dist = abs(flash.x - sign.x * size.width) / size.width
                    if dist < 0.15 {
                        flashBoost = max(flashBoost, (1.0 - age / 1.5) * (1.0 - dist / 0.15))
                    }
                }
            }

            if on || flashBoost > 0 {
                let alpha = (on ? 0.6 : 0) + flashBoost * 0.5
                let col = Color(red: sign.color.0, green: sign.color.1, blue: sign.color.2)

                // Glow
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 18 + flashBoost * 12))
                    l.fill(Ellipse().path(in: CGRect(x: sx - 20, y: sy - 10, width: 40, height: 20)),
                        with: .color(col.opacity(alpha * 0.3)))
                }

                // Sign body (rectangular neon tube look)
                ctx.fill(RoundedRectangle(cornerRadius: 1).path(in: CGRect(x: sx - 12, y: sy - 4, width: 24, height: 8)),
                    with: .color(col.opacity(alpha)))
            }
        }
    }

    // MARK: - Street level

    private func drawStreetLevel(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let streetY = size.height * 0.72
        // Dark ground
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: streetY, width: size.width, height: size.height - streetY)),
            with: .color(Color(red: 0.04, green: 0.03, blue: 0.06)))

        // Street surface
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: streetY, width: size.width, height: 20)),
            with: .color(Color(red: 0.08, green: 0.07, blue: 0.10)))

        // Lane markings
        let dashW = 15.0, gapW = 12.0
        let scroll = fmod(t * 0, dashW + gapW) // static road
        var dx = -scroll
        while dx < size.width + dashW {
            ctx.fill(Rectangle().path(in: CGRect(x: snap(dx), y: streetY + 9, width: snap(dashW), height: 2)),
                with: .color(Color(red: 0.4, green: 0.35, blue: 0.2).opacity(0.3)))
            dx += dashW + gapW
        }

        // Streetlights
        for i in 0..<6 {
            let lx = snap(size.width * (0.1 + Double(i) * 0.16))
            let ly = streetY - 50
            ctx.fill(Rectangle().path(in: CGRect(x: lx - 1, y: ly, width: 2, height: 50)),
                with: .color(Color(red: 0.12, green: 0.10, blue: 0.08)))
            // Light cone
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 15))
                let coneRect = CGRect(x: lx - 15, y: streetY - 5, width: 30, height: 15)
                l.fill(Ellipse().path(in: coneRect),
                    with: .color(Color(red: 1.2, green: 1.0, blue: 0.6).opacity(0.12)))
            }
            // Lamp head
            ctx.fill(Rectangle().path(in: CGRect(x: lx - 4, y: ly - 2, width: 8, height: 4)),
                with: .color(Color(red: 0.15, green: 0.12, blue: 0.08)))
            ctx.fill(Ellipse().path(in: CGRect(x: lx - 2, y: ly - 1, width: 4, height: 3)),
                with: .color(Color(red: 1.2, green: 1.0, blue: 0.6).opacity(0.6)))
        }
    }

    // MARK: - Puddles (flat reflections)

    private func drawPuddles(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let streetY = size.height * 0.72
        var rng = SplitMix64(seed: 0xA0DDED)
        for _ in 0..<8 {
            let px = snap(nextDouble(&rng) * size.width * 0.9 + size.width * 0.05)
            let py = snap(streetY + 5 + nextDouble(&rng) * 15)
            let pw = snap(30 + nextDouble(&rng) * 50)
            let ph = snap(4 + nextDouble(&rng) * 6)
            let shimmer = sin(t * 0.5 + nextDouble(&rng) * 6) * 0.05 + 0.15

            ctx.fill(Ellipse().path(in: CGRect(x: px, y: py, width: pw, height: ph)),
                with: .color(Color(red: 0.1 + shimmer, green: 0.08 + shimmer, blue: 0.15 + shimmer * 1.5).opacity(0.5)))

            // Reflected neon colors
            let neonRef = sin(t * 0.8 + px * 0.01) * 0.5 + 0.5
            ctx.fill(Ellipse().path(in: CGRect(x: px + 3, y: py + 1, width: pw - 6, height: ph - 2)),
                with: .color(Color(red: 1.2 * neonRef, green: 0.4, blue: 1.0 * (1 - neonRef)).opacity(0.08)))
        }
    }

    // MARK: - Chicago el-train

    private func drawElTrain(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let trackY = size.height * 0.63
        // Elevated track
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: trackY, width: size.width, height: 3)),
            with: .color(Color(red: 0.10, green: 0.08, blue: 0.06).opacity(0.6)))
        // Support pillars
        for i in stride(from: 0, through: Int(size.width), by: 60) {
            ctx.fill(Rectangle().path(in: CGRect(x: snap(Double(i)), y: trackY, width: 3, height: size.height * 0.09)),
                with: .color(Color(red: 0.08, green: 0.06, blue: 0.05).opacity(0.4)))
        }

        // Train cars
        let carW = 40.0, carH = 12.0, carCount = 4
        let totalLen = Double(carCount) * (carW + 3)
        let cycle = size.width + totalLen + 100
        let tx = fmod(t * 25, cycle) - totalLen

        for i in 0..<carCount {
            let cx = snap(tx + Double(i) * (carW + 3))
            let cy = trackY - carH
            ctx.fill(Rectangle().path(in: CGRect(x: cx, y: snap(cy), width: snap(carW), height: snap(carH))),
                with: .color(Color(red: 0.15, green: 0.12, blue: 0.18)))
            // Windows
            for w in 0..<5 {
                let wx = cx + 4 + Double(w) * 7
                ctx.fill(Rectangle().path(in: CGRect(x: snap(wx), y: snap(cy + 2), width: 3, height: 4)),
                    with: .color(Color(red: 1.1, green: 0.9, blue: 0.5).opacity(0.5)))
            }
        }
    }

    // MARK: - Rain

    private func drawRain(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xBA10DBA)
        for _ in 0..<60 {
            let bx = nextDouble(&rng) * size.width
            let speed = nextDouble(&rng) * 300 + 200
            let len = snap(nextDouble(&rng) * 8 + 4)
            let phase = nextDouble(&rng) * 100
            let y = fmod((t + phase) * speed, size.height + len * 2) - len
            let x = bx + sin(t * 0.1 + phase) * 3

            var drop = Path()
            drop.move(to: CGPoint(x: snap(x), y: snap(y)))
            drop.addLine(to: CGPoint(x: snap(x - 1), y: snap(y + len)))
            ctx.stroke(drop, with: .color(.white.opacity(0.08)), lineWidth: 1)
        }
    }

    // MARK: - Puddle ripples on tap

    private func drawPuddleRipples(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let currentT = Date().timeIntervalSince(startDate)
        for flash in neonFlashes {
            let age = currentT - flash.birth
            guard age < 2.0 else { continue }
            let p = age / 2.0
            let fade = (1 - p) * (1 - p)
            let streetY = size.height * 0.72

            // Ripple rings on puddle area
            for ring in 0..<3 {
                let ringAge = p - Double(ring) * 0.15
                guard ringAge > 0 else { continue }
                let radius = ringAge * 40
                let ringFade = fade * max(0, 1 - Double(ring) * 0.3)
                let rx = flash.x
                let ry = streetY + 12

                var ripple = Path()
                ripple.addEllipse(in: CGRect(x: rx - radius, y: ry - radius * 0.3, width: radius * 2, height: radius * 0.6))
                ctx.stroke(ripple, with: .color(Color(red: 0.5, green: 0.5, blue: 1.0).opacity(ringFade * 0.2)), lineWidth: 1)
            }
        }
    }

    // MARK: - CRT scanlines

    private func drawScanlines(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let spacing = 3.0
        var y = 0.0
        while y < size.height {
            ctx.fill(Rectangle().path(in: CGRect(x: 0, y: y, width: size.width, height: 1)),
                with: .color(.black.opacity(0.06)))
            y += spacing
        }
    }

    // MARK: - Colour quantization / dither

    private func drawDither(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Subtle 2x2 Bayer dither noise overlay
        let step = 6.0
        var rng = SplitMix64(seed: 0xD1AE0E0)
        let maxX = min(size.width, 1200.0)
        let maxY = min(size.height, 800.0)
        for x in stride(from: 0.0, through: maxX, by: step) {
            for y in stride(from: 0.0, through: maxY, by: step) {
                let v = nextDouble(&rng)
                if v > 0.92 {
                    ctx.fill(Rectangle().path(in: CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(.white.opacity(0.015)))
                }
            }
        }
    }
}
