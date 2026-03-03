import SwiftUI

struct NonsenseLullabiesScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    struct WashBlob {
        let x, y, size, hue, saturation: Double
        let driftX, driftY, phase: Double
    }

    struct NurseryShape {
        let x, y, size: Double
        let kind: Int // 0=moon, 1=star, 2=house, 3=cat, 4=bird, 5=flower
        let bobPhase, bobSpeed: Double
        let hue, saturation, brightness: Double
    }

    struct DripLine {
        let x, yStart, length, speed, thickness: Double
        let hue: Double
    }

    struct TapSplash {
        let x, y, birth, hue: Double
    }

    @State private var washes: [WashBlob] = []
    @State private var shapes: [NurseryShape] = []
    @State private var drips: [DripLine] = []
    @State private var tapSplashes: [TapSplash] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawPaperTexture(ctx: &ctx, size: size, t: t)
                drawWatercolourWashes(ctx: &ctx, size: size, t: t)
                drawDrips(ctx: &ctx, size: size, t: t)
                drawNurseryShapes(ctx: &ctx, size: size, t: t)
                drawTapSplashes(ctx: &ctx, size: size, t: t)
                drawSoftVignette(ctx: &ctx, size: size)
            }
        }
        .background(Color(red: 0.96, green: 0.94, blue: 0.90))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: generate)
        .onChange(of: interaction.tapCount) { _, _ in handleTap() }
    }

    private func generate() {
        var rng = SplitMix64(seed: 1992)

        // Watercolour wash blobs — large soft colour areas
        washes = (0..<12).map { _ in
            WashBlob(
                x: nextDouble(&rng),
                y: nextDouble(&rng),
                size: 80 + nextDouble(&rng) * 200,
                hue: nextDouble(&rng),
                saturation: 0.2 + nextDouble(&rng) * 0.35,
                driftX: (nextDouble(&rng) - 0.5) * 0.003,
                driftY: (nextDouble(&rng) - 0.5) * 0.002,
                phase: nextDouble(&rng) * .pi * 2
            )
        }

        // Simple nursery shapes floating gently
        shapes = (0..<18).map { _ in
            NurseryShape(
                x: 0.05 + nextDouble(&rng) * 0.9,
                y: 0.05 + nextDouble(&rng) * 0.9,
                size: 12 + nextDouble(&rng) * 28,
                kind: Int(nextDouble(&rng) * 6),
                bobPhase: nextDouble(&rng) * .pi * 2,
                bobSpeed: 0.3 + nextDouble(&rng) * 0.5,
                hue: nextDouble(&rng),
                saturation: 0.3 + nextDouble(&rng) * 0.4,
                brightness: 0.5 + nextDouble(&rng) * 0.3
            )
        }

        // Paint drips — thin watercolour runs
        drips = (0..<8).map { _ in
            DripLine(
                x: nextDouble(&rng) * 1.0,
                yStart: nextDouble(&rng) * 0.3,
                length: 0.15 + nextDouble(&rng) * 0.4,
                speed: 0.01 + nextDouble(&rng) * 0.02,
                thickness: 1 + nextDouble(&rng) * 3,
                hue: nextDouble(&rng)
            )
        }

        ready = true
    }

    private func handleTap() {
        var rng = SplitMix64(seed: UInt64(interaction.tapCount * 47 + 11))
        let splash = TapSplash(
            x: 0.15 + nextDouble(&rng) * 0.7,
            y: 0.15 + nextDouble(&rng) * 0.7,
            birth: Date().timeIntervalSince(startDate),
            hue: nextDouble(&rng)
        )
        tapSplashes.append(splash)
        if tapSplashes.count > 6 { tapSplashes.removeFirst() }
    }

    // MARK: - Warm paper background

    private func drawPaperTexture(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Subtle warm cream gradient to suggest textured paper
        let warmShift = sin(t * 0.02) * 0.01
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.97 + warmShift, green: 0.95 + warmShift * 0.5, blue: 0.91),
                Color(red: 0.95 + warmShift, green: 0.92, blue: 0.88),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: size.width, y: size.height)
        ))

        // Faint speckle texture
        var rng = SplitMix64(seed: 5555)
        for _ in 0..<50 {
            let sx = nextDouble(&rng) * size.width
            let sy = nextDouble(&rng) * size.height
            let ss = 1 + nextDouble(&rng) * 3
            ctx.fill(Ellipse().path(in: CGRect(x: sx, y: sy, width: ss, height: ss)),
                     with: .color(Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.15)))
        }
    }

    // MARK: - Watercolour washes (soft drifting colour pools)

    private func drawWatercolourWashes(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for wash in washes {
            let wx = (wash.x + sin(t * 0.05 + wash.phase) * 0.03 + t * wash.driftX) * size.width
            let wy = (wash.y + cos(t * 0.04 + wash.phase) * 0.02 + t * wash.driftY) * size.height
            let breathe = sin(t * 0.1 + wash.phase) * 0.1 + 1.0
            let s = wash.size * breathe

            ctx.drawLayer { l in
                l.addFilter(.blur(radius: s * 0.5))
                l.fill(Ellipse().path(in: CGRect(x: wx - s / 2, y: wy - s / 2, width: s, height: s * 0.7)),
                       with: .color(Color(hue: wash.hue, saturation: wash.saturation, brightness: 0.85).opacity(0.08)))
            }
        }
    }

    // MARK: - Paint drips (thin watercolour lines slowly running down)

    private func drawDrips(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for drip in drips {
            let dx = drip.x * size.width + sin(t * 0.2 + drip.hue * 6.28) * 3
            let dy = drip.yStart * size.height
            let visibleLen = fmod(t * drip.speed, drip.length + 0.2) * size.height
            let actualLen = min(visibleLen, drip.length * size.height)

            if actualLen > 0 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: drip.thickness * 0.6))
                    var line = Path()
                    line.move(to: CGPoint(x: dx, y: dy))
                    // Gentle wobble
                    let midX = dx + sin(t * 0.3 + drip.hue * 3) * 4
                    line.addQuadCurve(to: CGPoint(x: dx + 1, y: dy + actualLen),
                                      control: CGPoint(x: midX, y: dy + actualLen * 0.5))
                    l.stroke(line, with: .color(Color(hue: drip.hue, saturation: 0.25, brightness: 0.7).opacity(0.1)),
                             lineWidth: drip.thickness)
                }
            }
        }
    }

    // MARK: - Nursery shapes (simple hand-drawn forms floating gently)

    private func drawNurseryShapes(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for shape in shapes {
            let bob = sin(t * shape.bobSpeed + shape.bobPhase) * 6
            let sway = sin(t * shape.bobSpeed * 0.7 + shape.bobPhase * 1.3) * 4
            let sx = shape.x * size.width + sway
            let sy = shape.y * size.height + bob
            let s = shape.size
            let col = Color(hue: shape.hue, saturation: shape.saturation, brightness: shape.brightness)
            let alpha = 0.35 + sin(t * 0.15 + shape.bobPhase) * 0.08

            switch shape.kind {
            case 0: // Moon (crescent)
                ctx.fill(Ellipse().path(in: CGRect(x: sx - s / 2, y: sy - s / 2, width: s, height: s)),
                         with: .color(col.opacity(alpha)))
                // Cut-out for crescent effect
                ctx.fill(Ellipse().path(in: CGRect(x: sx - s * 0.2, y: sy - s * 0.5, width: s * 0.7, height: s * 0.85)),
                         with: .color(Color(red: 0.96, green: 0.94, blue: 0.90).opacity(alpha * 0.7)))

            case 1: // Star (five-pointed)
                var star = Path()
                for i in 0..<10 {
                    let angle = Double(i) / 10.0 * .pi * 2 - .pi / 2
                    let r = i % 2 == 0 ? s * 0.5 : s * 0.2
                    let px = sx + cos(angle) * r
                    let py = sy + sin(angle) * r
                    if i == 0 { star.move(to: CGPoint(x: px, y: py)) }
                    else { star.addLine(to: CGPoint(x: px, y: py)) }
                }
                star.closeSubpath()
                ctx.fill(star, with: .color(col.opacity(alpha)))

            case 2: // House (simple triangle + rectangle)
                let hw = s * 0.7, hh = s * 0.5
                // Walls
                ctx.fill(Rectangle().path(in: CGRect(x: sx - hw / 2, y: sy - hh / 2, width: hw, height: hh)),
                         with: .color(col.opacity(alpha)))
                // Roof
                var roof = Path()
                roof.move(to: CGPoint(x: sx - hw * 0.6, y: sy - hh / 2))
                roof.addLine(to: CGPoint(x: sx, y: sy - hh))
                roof.addLine(to: CGPoint(x: sx + hw * 0.6, y: sy - hh / 2))
                roof.closeSubpath()
                ctx.fill(roof, with: .color(col.opacity(alpha * 0.8)))
                // Door
                ctx.fill(Rectangle().path(in: CGRect(x: sx - 2, y: sy - 2, width: 4, height: hh * 0.4)),
                         with: .color(Color(red: 0.3, green: 0.25, blue: 0.2).opacity(alpha * 0.5)))

            case 3: // Cat (round head + pointed ears + body)
                // Body
                ctx.fill(Ellipse().path(in: CGRect(x: sx - s * 0.3, y: sy - s * 0.15, width: s * 0.6, height: s * 0.4)),
                         with: .color(col.opacity(alpha)))
                // Head
                ctx.fill(Ellipse().path(in: CGRect(x: sx - s * 0.2, y: sy - s * 0.4, width: s * 0.35, height: s * 0.3)),
                         with: .color(col.opacity(alpha)))
                // Ears
                var ear1 = Path()
                ear1.move(to: CGPoint(x: sx - s * 0.15, y: sy - s * 0.35))
                ear1.addLine(to: CGPoint(x: sx - s * 0.1, y: sy - s * 0.55))
                ear1.addLine(to: CGPoint(x: sx - s * 0.02, y: sy - s * 0.35))
                ear1.closeSubpath()
                ctx.fill(ear1, with: .color(col.opacity(alpha)))
                var ear2 = Path()
                ear2.move(to: CGPoint(x: sx + s * 0.02, y: sy - s * 0.35))
                ear2.addLine(to: CGPoint(x: sx + s * 0.08, y: sy - s * 0.52))
                ear2.addLine(to: CGPoint(x: sx + s * 0.15, y: sy - s * 0.32))
                ear2.closeSubpath()
                ctx.fill(ear2, with: .color(col.opacity(alpha)))
                // Tail
                var tail = Path()
                tail.move(to: CGPoint(x: sx + s * 0.25, y: sy))
                tail.addQuadCurve(to: CGPoint(x: sx + s * 0.45, y: sy - s * 0.15),
                                  control: CGPoint(x: sx + s * 0.42, y: sy + s * 0.1))
                ctx.stroke(tail, with: .color(col.opacity(alpha)), lineWidth: 2)

            case 4: // Bird (simple arc body + wing)
                // Body
                ctx.fill(Ellipse().path(in: CGRect(x: sx - s * 0.25, y: sy - s * 0.12, width: s * 0.5, height: s * 0.25)),
                         with: .color(col.opacity(alpha)))
                // Head
                ctx.fill(Ellipse().path(in: CGRect(x: sx + s * 0.12, y: sy - s * 0.25, width: s * 0.18, height: s * 0.18)),
                         with: .color(col.opacity(alpha)))
                // Wing flap
                let wingAngle = sin(t * 2.5 + shape.bobPhase) * 0.3
                var wing = Path()
                wing.move(to: CGPoint(x: sx, y: sy - s * 0.1))
                wing.addQuadCurve(to: CGPoint(x: sx - s * 0.2, y: sy - s * 0.05),
                                  control: CGPoint(x: sx - s * 0.15, y: sy - s * 0.3 + wingAngle * s))
                ctx.stroke(wing, with: .color(col.opacity(alpha * 0.8)), lineWidth: 2)
                // Beak
                var beak = Path()
                beak.move(to: CGPoint(x: sx + s * 0.28, y: sy - s * 0.17))
                beak.addLine(to: CGPoint(x: sx + s * 0.36, y: sy - s * 0.15))
                beak.addLine(to: CGPoint(x: sx + s * 0.28, y: sy - s * 0.13))
                beak.closeSubpath()
                ctx.fill(beak, with: .color(Color(red: 0.8, green: 0.5, blue: 0.2).opacity(alpha)))

            default: // Flower
                // Stem
                ctx.fill(Rectangle().path(in: CGRect(x: sx - 0.5, y: sy, width: 1.5, height: s * 0.5)),
                         with: .color(Color(red: 0.3, green: 0.55, blue: 0.3).opacity(alpha * 0.6)))
                // Petals
                for p in 0..<5 {
                    let pAngle = Double(p) / 5.0 * .pi * 2 + t * 0.05
                    let px = sx + cos(pAngle) * s * 0.2
                    let py = sy - s * 0.05 + sin(pAngle) * s * 0.2
                    ctx.fill(Ellipse().path(in: CGRect(x: px - s * 0.1, y: py - s * 0.08, width: s * 0.2, height: s * 0.16)),
                             with: .color(col.opacity(alpha * 0.9)))
                }
                // Center
                ctx.fill(Ellipse().path(in: CGRect(x: sx - s * 0.06, y: sy - s * 0.11, width: s * 0.12, height: s * 0.12)),
                         with: .color(Color(red: 0.9, green: 0.75, blue: 0.3).opacity(alpha)))
            }
        }
    }

    // MARK: - Tap splashes (watercolour blooms)

    private func drawTapSplashes(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for splash in tapSplashes {
            let age = t - splash.birth
            guard age < 5.0 else { continue }
            let fade = 1.0 - age / 5.0
            let expand = age * 15 + 20
            let sx = splash.x * size.width
            let sy = splash.y * size.height

            ctx.drawLayer { l in
                l.addFilter(.blur(radius: expand * 0.6))
                l.fill(Ellipse().path(in: CGRect(x: sx - expand, y: sy - expand * 0.7,
                                                  width: expand * 2, height: expand * 1.4)),
                       with: .color(Color(hue: splash.hue, saturation: 0.3, brightness: 0.8).opacity(0.08 * fade)))
            }

            // Scattered droplets around the splash
            var rng = SplitMix64(seed: UInt64(splash.birth * 1000))
            for _ in 0..<6 {
                let dx = (nextDouble(&rng) - 0.5) * expand * 2
                let dy = (nextDouble(&rng) - 0.5) * expand * 1.5
                let ds = 2 + nextDouble(&rng) * 4
                ctx.fill(Ellipse().path(in: CGRect(x: sx + dx - ds / 2, y: sy + dy - ds / 2, width: ds, height: ds)),
                         with: .color(Color(hue: splash.hue, saturation: 0.25, brightness: 0.7).opacity(0.12 * fade)))
            }
        }
    }

    // MARK: - Soft vignette (darker edges, like an illustration in a book)

    private func drawSoftVignette(ctx: inout GraphicsContext, size: CGSize) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 60))
            let edge: Double = 30
            // Top
            l.fill(Rectangle().path(in: CGRect(x: 0, y: -20, width: size.width, height: edge)),
                   with: .color(Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.2)))
            // Bottom
            l.fill(Rectangle().path(in: CGRect(x: 0, y: size.height - edge + 20, width: size.width, height: edge)),
                   with: .color(Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.2)))
            // Left
            l.fill(Rectangle().path(in: CGRect(x: -20, y: 0, width: edge, height: size.height)),
                   with: .color(Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.15)))
            // Right
            l.fill(Rectangle().path(in: CGRect(x: size.width - edge + 20, y: 0, width: edge, height: size.height)),
                   with: .color(Color(red: 0.85, green: 0.82, blue: 0.78).opacity(0.15)))
        }
    }
}
