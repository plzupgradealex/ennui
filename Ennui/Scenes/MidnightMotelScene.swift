// MidnightMotelScene — A motel room somewhere in America, 1968.
// Neon VACANCY sign bleeding through thin curtains, wood paneling,
// a patterned bedspread, a rotary phone, headlights sweeping
// across the ceiling. The warm solitude of being nowhere in particular.

import SwiftUI

struct MidnightMotelScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    struct HeadlightSweep: Identifiable {
        let id = UUID()
        let birth: Double
        let speed: Double
        let brightness: Double
    }

    @State private var ready = false
    @State private var sweeps: [HeadlightSweep] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                let w = size.width
                let h = size.height

                drawWalls(ctx: &ctx, w: w, h: h, t: t)
                drawWindow(ctx: &ctx, w: w, h: h, t: t)
                drawCurtains(ctx: &ctx, w: w, h: h, t: t)
                drawVacancyGlow(ctx: &ctx, w: w, h: h, t: t)
                drawBed(ctx: &ctx, w: w, h: h, t: t)
                drawNightstand(ctx: &ctx, w: w, h: h, t: t)
                drawLamp(ctx: &ctx, w: w, h: h, t: t)
                drawPhone(ctx: &ctx, w: w, h: h, t: t)
                drawSuitcase(ctx: &ctx, w: w, h: h)
                drawCarpet(ctx: &ctx, w: w, h: h)
                drawHeadlights(ctx: &ctx, w: w, h: h, t: t)
                drawDust(ctx: &ctx, w: w, h: h, t: t)
            }
        }
        .background(Color(red: 0.04, green: 0.03, blue: 0.05))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear { ready = true }
        .onChange(of: interaction.tapCount) { _, _ in
            let t = Date().timeIntervalSince(startDate)
            var rng = SplitMix64(seed: UInt64(t * 7777))
            sweeps.append(HeadlightSweep(
                birth: t,
                speed: Double.random(in: 0.8...1.6, using: &rng),
                brightness: Double.random(in: 0.12...0.25, using: &rng)
            ))
            if sweeps.count > 6 { sweeps.removeFirst() }
        }
    }

    // MARK: - Wood-paneled walls

    private func drawWalls(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        // Dark wood paneling — horizontal planks
        let wallTop = h * 0.08
        let wallBottom = h * 0.72

        // Base wall color
        ctx.fill(
            Path(CGRect(x: 0, y: wallTop, width: w, height: wallBottom - wallTop)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.14, green: 0.09, blue: 0.06),
                Color(red: 0.12, green: 0.08, blue: 0.05),
                Color(red: 0.10, green: 0.07, blue: 0.04),
            ]), startPoint: CGPoint(x: 0, y: wallTop), endPoint: CGPoint(x: 0, y: wallBottom)))

        // Horizontal plank lines
        var rng = SplitMix64(seed: 0x1968_0101)
        let plankH = (wallBottom - wallTop) / 14.0
        for i in 0..<14 {
            let y = wallTop + Double(i) * plankH
            let grain = Double.random(in: -0.01...0.01, using: &rng)
            ctx.fill(
                Path(CGRect(x: 0, y: y, width: w, height: 1)),
                with: .color(Color(red: 0.06 + grain, green: 0.04, blue: 0.03).opacity(0.5)))

            // Subtle grain streaks
            for _ in 0..<3 {
                let gx = Double.random(in: 0...w, using: &rng)
                let gw = Double.random(in: 40...200, using: &rng)
                let go = Double.random(in: 0.02...0.06, using: &rng)
                ctx.fill(
                    Path(CGRect(x: gx, y: y + 3, width: gw, height: plankH - 6)),
                    with: .color(Color(red: 0.16, green: 0.10, blue: 0.06).opacity(go)))
            }
        }

        // Ceiling - dark
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: wallTop)),
            with: .color(Color(red: 0.06, green: 0.05, blue: 0.04)))
    }

    // MARK: - Window

    private func drawWindow(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let wx = w * 0.35
        let wy = h * 0.12
        let ww = w * 0.30
        let wh = h * 0.42

        // Window frame - dark wood
        ctx.fill(
            Path(CGRect(x: wx - 4, y: wy - 4, width: ww + 8, height: wh + 8)),
            with: .color(Color(red: 0.08, green: 0.05, blue: 0.03)))

        // Night sky through window
        ctx.fill(
            Path(CGRect(x: wx, y: wy, width: ww, height: wh)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.03, green: 0.02, blue: 0.07),
                Color(red: 0.04, green: 0.03, blue: 0.09),
                Color(red: 0.06, green: 0.04, blue: 0.08),
            ]), startPoint: CGPoint(x: wx, y: wy), endPoint: CGPoint(x: wx, y: wy + wh)))

        // A few stars visible
        var rng = SplitMix64(seed: 0x1968_57A4)
        for _ in 0..<12 {
            let sx = wx + Double.random(in: 5...(ww - 5), using: &rng)
            let sy = wy + Double.random(in: 5...(wh * 0.4), using: &rng)
            let sb = Double.random(in: 0.15...0.5, using: &rng)
            let ss = Double.random(in: 0.5...1.2, using: &rng)
            let twink = sin(t * Double.random(in: 0.5...2.0, using: &rng) + Double.random(in: 0...6.28, using: &rng)) * 0.15 + 0.85
            ctx.fill(
                Ellipse().path(in: CGRect(x: sx - ss/2, y: sy - ss/2, width: ss, height: ss)),
                with: .color(.white.opacity(sb * twink)))
        }

        // Window cross-bar
        ctx.fill(Path(CGRect(x: wx + ww/2 - 1.5, y: wy, width: 3, height: wh)),
            with: .color(Color(red: 0.07, green: 0.05, blue: 0.03)))
        ctx.fill(Path(CGRect(x: wx, y: wy + wh/2 - 1.5, width: ww, height: 3)),
            with: .color(Color(red: 0.07, green: 0.05, blue: 0.03)))
    }

    // MARK: - Thin curtains

    private func drawCurtains(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let wx = w * 0.35
        let wy = h * 0.10
        let ww = w * 0.30
        let wh = h * 0.48

        // Left curtain - slightly translucent, swaying
        let sway = sin(t * 0.15) * 3
        ctx.drawLayer { l in
            l.opacity = 0.35
            var left = Path()
            left.move(to: CGPoint(x: wx - 8, y: wy))
            left.addLine(to: CGPoint(x: wx + ww * 0.15 + sway, y: wy))
            left.addCurve(
                to: CGPoint(x: wx + ww * 0.12 + sway * 0.5, y: wy + wh),
                control1: CGPoint(x: wx + ww * 0.18, y: wy + wh * 0.4),
                control2: CGPoint(x: wx + ww * 0.08, y: wy + wh * 0.7))
            left.addLine(to: CGPoint(x: wx - 8, y: wy + wh))
            left.closeSubpath()
            l.fill(left, with: .color(Color(red: 0.18, green: 0.14, blue: 0.10)))
        }

        // Right curtain
        ctx.drawLayer { l in
            l.opacity = 0.35
            var right = Path()
            right.move(to: CGPoint(x: wx + ww + 8, y: wy))
            right.addLine(to: CGPoint(x: wx + ww * 0.85 - sway, y: wy))
            right.addCurve(
                to: CGPoint(x: wx + ww * 0.88 - sway * 0.5, y: wy + wh),
                control1: CGPoint(x: wx + ww * 0.82, y: wy + wh * 0.4),
                control2: CGPoint(x: wx + ww * 0.92, y: wy + wh * 0.7))
            right.addLine(to: CGPoint(x: wx + ww + 8, y: wy + wh))
            right.closeSubpath()
            l.fill(right, with: .color(Color(red: 0.18, green: 0.14, blue: 0.10)))
        }

        // Curtain rod
        ctx.fill(
            Path(CGRect(x: wx - 15, y: wy - 3, width: ww + 30, height: 3)),
            with: .color(Color(red: 0.55, green: 0.40, blue: 0.20).opacity(0.4)))
    }

    // MARK: - Neon VACANCY sign glow

    private func drawVacancyGlow(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let wx = w * 0.35
        let wy = h * 0.12
        let ww = w * 0.30
        let wh = h * 0.42

        // Neon flicker
        let flicker = sin(t * 3.7) * 0.04 + sin(t * 7.1) * 0.02 + sin(t * 11.3) * 0.01
        let baseGlow = 0.12 + flicker

        // Pink/red neon wash coming through window
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 40))
            let glowRect = CGRect(x: wx + ww * 0.2, y: wy + wh * 0.3, width: ww * 0.6, height: wh * 0.4)
            l.fill(Ellipse().path(in: glowRect),
                with: .color(Color(red: 1.0, green: 0.15, blue: 0.25).opacity(baseGlow)))
        }

        // Neon glow on wall beneath window
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 25))
            let wallGlow = CGRect(x: wx + ww * 0.1, y: wy + wh, width: ww * 0.8, height: h * 0.12)
            l.fill(Ellipse().path(in: wallGlow),
                with: .color(Color(red: 0.9, green: 0.12, blue: 0.2).opacity(baseGlow * 0.5)))
        }

        // Faint "VACANCY" text visible through curtain gap — just a pink smudge
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 8))
            let textY = wy + wh * 0.45
            let textX = wx + ww * 0.32
            // Simple letter-shaped blocks hinting at text
            for (i, cw) in [8.0, 7.0, 9.0, 7.0, 8.0, 8.0, 8.0].enumerated() {
                let cx = textX + Double(i) * 11
                l.fill(
                    Path(CGRect(x: cx, y: textY, width: cw, height: 10)),
                    with: .color(Color(red: 1.1, green: 0.2, blue: 0.35).opacity(baseGlow * 1.5)))
            }
        }
    }

    // MARK: - Bed with patterned bedspread

    private func drawBed(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let bx = w * 0.05
        let by = h * 0.52
        let bw = w * 0.55
        let bh = h * 0.28

        // Bed frame - dark wood
        ctx.fill(
            Path(CGRect(x: bx - 3, y: by - 2, width: bw + 6, height: bh + 5)),
            with: .color(Color(red: 0.10, green: 0.06, blue: 0.04)))

        // Mattress base
        ctx.fill(
            Path(CGRect(x: bx, y: by, width: bw, height: bh)),
            with: .color(Color(red: 0.15, green: 0.10, blue: 0.07)))

        // Patterned bedspread — mid-century geometric (warm orange/gold/brown)
        var rng = SplitMix64(seed: 0x1968_BED0)
        let patW = 18.0
        let patH = 14.0
        for row in 0..<Int(bh / patH) + 1 {
            for col in 0..<Int(bw / patW) + 1 {
                let px = bx + Double(col) * patW
                let py = by + Double(row) * patH
                if px > bx + bw || py > by + bh { continue }

                let patType = Int.random(in: 0..<3, using: &rng)
                let hueShift = Double.random(in: -0.02...0.02, using: &rng)

                if patType == 0 {
                    // Diamond
                    var diamond = Path()
                    diamond.move(to: CGPoint(x: px + patW/2, y: py + 2))
                    diamond.addLine(to: CGPoint(x: px + patW - 2, y: py + patH/2))
                    diamond.addLine(to: CGPoint(x: px + patW/2, y: py + patH - 2))
                    diamond.addLine(to: CGPoint(x: px + 2, y: py + patH/2))
                    diamond.closeSubpath()
                    ctx.fill(diamond, with: .color(Color(red: 0.55 + hueShift, green: 0.30, blue: 0.10).opacity(0.3)))
                } else if patType == 1 {
                    // Small circle
                    let cr = min(patW, patH) * 0.3
                    ctx.fill(
                        Ellipse().path(in: CGRect(x: px + patW/2 - cr, y: py + patH/2 - cr, width: cr*2, height: cr*2)),
                        with: .color(Color(red: 0.65 + hueShift, green: 0.38, blue: 0.12).opacity(0.25)))
                } else {
                    // Horizontal bars
                    ctx.fill(
                        Path(CGRect(x: px + 2, y: py + patH * 0.3, width: patW - 4, height: 2)),
                        with: .color(Color(red: 0.50 + hueShift, green: 0.28, blue: 0.08).opacity(0.2)))
                    ctx.fill(
                        Path(CGRect(x: px + 2, y: py + patH * 0.6, width: patW - 4, height: 2)),
                        with: .color(Color(red: 0.50 + hueShift, green: 0.28, blue: 0.08).opacity(0.2)))
                }
            }
        }

        // Pillow
        let pillowX = bx + bw * 0.02
        let pillowY = by + 4
        let pillowW = bw * 0.22
        let pillowH = bh * 0.35
        ctx.fill(
            RoundedRectangle(cornerRadius: 6).path(in: CGRect(x: pillowX, y: pillowY, width: pillowW, height: pillowH)),
            with: .color(Color(red: 0.22, green: 0.18, blue: 0.14)))
        // Pillow highlight
        ctx.fill(
            RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: pillowX + 3, y: pillowY + 2, width: pillowW * 0.6, height: pillowH * 0.4)),
            with: .color(Color(red: 0.28, green: 0.22, blue: 0.17).opacity(0.4)))

        // Headboard
        ctx.fill(
            Path(CGRect(x: bx - 2, y: by - h * 0.08, width: 8, height: h * 0.08 + 4)),
            with: .color(Color(red: 0.08, green: 0.05, blue: 0.03)))
    }

    // MARK: - Nightstand

    private func drawNightstand(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let nx = w * 0.62
        let ny = h * 0.55
        let nw = w * 0.10
        let nh = h * 0.18

        // Nightstand body
        ctx.fill(
            Path(CGRect(x: nx, y: ny, width: nw, height: nh)),
            with: .color(Color(red: 0.11, green: 0.07, blue: 0.04)))

        // Drawer line
        ctx.fill(
            Path(CGRect(x: nx + 3, y: ny + nh * 0.45, width: nw - 6, height: 1)),
            with: .color(Color(red: 0.06, green: 0.04, blue: 0.03).opacity(0.6)))

        // Drawer knob
        ctx.fill(
            Ellipse().path(in: CGRect(x: nx + nw/2 - 2, y: ny + nh * 0.55, width: 4, height: 3)),
            with: .color(Color(red: 0.45, green: 0.32, blue: 0.15).opacity(0.5)))
    }

    // MARK: - Warm table lamp

    private func drawLamp(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let lx = w * 0.66
        let ly = h * 0.35
        let breathe = sin(t * 0.4) * 0.015 + 1.0

        // Lamp glow — warm amber puddle of light
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 60))
            let glowR = 90.0 * breathe
            l.fill(
                Ellipse().path(in: CGRect(x: lx - glowR, y: ly - glowR * 0.6, width: glowR * 2, height: glowR * 1.2)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.95, green: 0.65, blue: 0.20).opacity(0.20 * breathe),
                        Color(red: 0.85, green: 0.50, blue: 0.15).opacity(0.08),
                        .clear
                    ]),
                    center: CGPoint(x: lx, y: ly),
                    startRadius: 0, endRadius: glowR))
        }

        // Lamp shade — trapezoid
        let shadeTop = ly - 15
        let shadeBot = ly + 12
        let topW = 22.0
        let botW = 32.0
        var shade = Path()
        shade.move(to: CGPoint(x: lx - topW/2, y: shadeTop))
        shade.addLine(to: CGPoint(x: lx + topW/2, y: shadeTop))
        shade.addLine(to: CGPoint(x: lx + botW/2, y: shadeBot))
        shade.addLine(to: CGPoint(x: lx - botW/2, y: shadeBot))
        shade.closeSubpath()
        ctx.fill(shade, with: .color(Color(red: 0.55, green: 0.38, blue: 0.15).opacity(0.5)))

        // Inner glow through shade
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 4))
            l.fill(shade, with: .color(Color(red: 0.85, green: 0.55, blue: 0.15).opacity(0.12 * breathe)))
        }

        // Lamp base — simple cylinder
        ctx.fill(
            Path(CGRect(x: lx - 3, y: shadeBot, width: 6, height: h * 0.55 - shadeBot + h * 0.02)),
            with: .color(Color(red: 0.45, green: 0.30, blue: 0.12).opacity(0.5)))
        // Base foot
        ctx.fill(
            Ellipse().path(in: CGRect(x: lx - 10, y: h * 0.55 - 3, width: 20, height: 6)),
            with: .color(Color(red: 0.40, green: 0.28, blue: 0.12).opacity(0.4)))
    }

    // MARK: - Rotary phone

    private func drawPhone(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let px = w * 0.635
        let py = h * 0.52

        // Phone body — dark rounded shape
        ctx.fill(
            RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: px, y: py, width: 28, height: 14)),
            with: .color(Color(red: 0.05, green: 0.04, blue: 0.03)))

        // Handset cradle
        var cradle = Path()
        cradle.move(to: CGPoint(x: px + 2, y: py - 2))
        cradle.addCurve(
            to: CGPoint(x: px + 26, y: py - 2),
            control1: CGPoint(x: px + 8, y: py - 8),
            control2: CGPoint(x: px + 20, y: py - 8))
        ctx.stroke(cradle, with: .color(Color(red: 0.04, green: 0.03, blue: 0.02)), lineWidth: 3)

        // Rotary dial hint
        ctx.fill(
            Ellipse().path(in: CGRect(x: px + 9, y: py + 2, width: 10, height: 10)),
            with: .color(Color(red: 0.08, green: 0.06, blue: 0.04)))
        ctx.stroke(
            Ellipse().path(in: CGRect(x: px + 10, y: py + 3, width: 8, height: 8)),
            with: .color(Color(red: 0.12, green: 0.09, blue: 0.06).opacity(0.4)), lineWidth: 0.5)
    }

    // MARK: - Suitcase on luggage rack

    private func drawSuitcase(ctx: inout GraphicsContext, w: Double, h: Double) {
        let sx = w * 0.78
        let sy = h * 0.58
        let sw: Double = 65
        let sh: Double = 40

        // Luggage rack legs
        ctx.fill(Path(CGRect(x: sx + 5, y: sy + sh, width: 3, height: 18)),
            with: .color(Color(red: 0.30, green: 0.22, blue: 0.10).opacity(0.3)))
        ctx.fill(Path(CGRect(x: sx + sw - 8, y: sy + sh, width: 3, height: 18)),
            with: .color(Color(red: 0.30, green: 0.22, blue: 0.10).opacity(0.3)))

        // Suitcase body
        ctx.fill(
            RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: sx, y: sy, width: sw, height: sh)),
            with: .color(Color(red: 0.18, green: 0.12, blue: 0.06)))

        // Suitcase clasp line
        ctx.fill(
            Path(CGRect(x: sx, y: sy + sh/2 - 0.5, width: sw, height: 1)),
            with: .color(Color(red: 0.25, green: 0.18, blue: 0.08).opacity(0.4)))

        // Clasps
        for cx in [sx + sw * 0.25, sx + sw * 0.75] {
            ctx.fill(
                Path(CGRect(x: cx - 3, y: sy + sh/2 - 2, width: 6, height: 4)),
                with: .color(Color(red: 0.50, green: 0.38, blue: 0.15).opacity(0.35)))
        }

        // Handle
        var handle = Path()
        handle.move(to: CGPoint(x: sx + sw * 0.35, y: sy))
        handle.addCurve(
            to: CGPoint(x: sx + sw * 0.65, y: sy),
            control1: CGPoint(x: sx + sw * 0.38, y: sy - 8),
            control2: CGPoint(x: sx + sw * 0.62, y: sy - 8))
        ctx.stroke(handle, with: .color(Color(red: 0.14, green: 0.09, blue: 0.05).opacity(0.5)), lineWidth: 2)
    }

    // MARK: - Carpet

    private func drawCarpet(ctx: inout GraphicsContext, w: Double, h: Double) {
        let floorY = h * 0.72

        // Floor
        ctx.fill(
            Path(CGRect(x: 0, y: floorY, width: w, height: h - floorY)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.10, green: 0.07, blue: 0.05),
                Color(red: 0.08, green: 0.06, blue: 0.04),
            ]), startPoint: CGPoint(x: 0, y: floorY), endPoint: CGPoint(x: 0, y: h)))

        // Carpet texture — subtle pattern
        var rng = SplitMix64(seed: 0x1968_CA40)
        for _ in 0..<80 {
            let cx = Double.random(in: 0...w, using: &rng)
            let cy = Double.random(in: floorY...(h - 5), using: &rng)
            let cw = Double.random(in: 3...12, using: &rng)
            let co = Double.random(in: 0.02...0.06, using: &rng)
            ctx.fill(
                Path(CGRect(x: cx, y: cy, width: cw, height: 1.5)),
                with: .color(Color(red: 0.14, green: 0.08, blue: 0.05).opacity(co)))
        }
    }

    // MARK: - Headlight sweeps across ceiling

    private func drawHeadlights(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        // Automatic ambient headlights (periodic)
        let autoInterval = 12.0
        let autoPhase = fmod(t, autoInterval)
        if autoPhase < 4.0 {
            let progress = autoPhase / 4.0
            drawSingleSweep(ctx: &ctx, w: w, h: h, progress: progress, brightness: 0.08)
        }

        // Tap-triggered headlights
        for sweep in sweeps {
            let age = t - sweep.birth
            if age < 0 || age > 3.5 { continue }
            let progress = age / 3.5 * sweep.speed
            if progress > 1 { continue }
            drawSingleSweep(ctx: &ctx, w: w, h: h, progress: progress, brightness: sweep.brightness)
        }
    }

    private func drawSingleSweep(ctx: inout GraphicsContext, w: Double, h: Double, progress: Double, brightness: Double) {
        let fade = progress < 0.1 ? progress / 0.1 : (progress > 0.7 ? (1.0 - progress) / 0.3 : 1.0)

        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 30))
            // Beam sweeps from left to right across ceiling
            let beamX = -w * 0.2 + progress * w * 1.4
            let beamW = w * 0.25
            let beamH = h * 0.12
            l.fill(
                Ellipse().path(in: CGRect(x: beamX - beamW/2, y: 0, width: beamW, height: beamH)),
                with: .color(Color(red: 0.95, green: 0.85, blue: 0.55).opacity(brightness * fade)))

            // Secondary beam on wall
            let wallBeamY = h * 0.15 + progress * h * 0.15
            l.fill(
                Ellipse().path(in: CGRect(x: beamX - beamW * 0.3, y: wallBeamY, width: beamW * 0.6, height: h * 0.2)),
                with: .color(Color(red: 0.90, green: 0.80, blue: 0.50).opacity(brightness * fade * 0.4)))
        }
    }

    // MARK: - Floating dust motes in lamplight

    private func drawDust(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        var rng = SplitMix64(seed: 0x1968_D057)
        let lampX = w * 0.66
        let lampY = h * 0.42

        for _ in 0..<25 {
            let baseX = lampX + Double.random(in: -80...80, using: &rng)
            let baseY = lampY + Double.random(in: -40...60, using: &rng)
            let drift = Double.random(in: 0.3...0.8, using: &rng)
            let phase = Double.random(in: 0...6.28, using: &rng)
            let sz = Double.random(in: 0.6...1.5, using: &rng)
            let bright = Double.random(in: 0.08...0.25, using: &rng)

            let x = baseX + sin(t * drift + phase) * 12
            let y = baseY + cos(t * drift * 0.7 + phase * 1.3) * 8 - t * 0.3
            let yMod = fmod(y - lampY + 100, 120) + lampY - 60

            // Only visible near lamp
            let dist = hypot(x - lampX, yMod - lampY)
            let falloff = max(0, 1.0 - dist / 100)
            if falloff <= 0 { continue }

            ctx.fill(
                Ellipse().path(in: CGRect(x: x - sz/2, y: yMod - sz/2, width: sz, height: sz)),
                with: .color(Color(red: 0.95, green: 0.75, blue: 0.35).opacity(bright * falloff)))
        }
    }
}
