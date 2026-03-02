import SwiftUI

struct SaltLampScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    struct LavaBlob {
        let baseX, baseY: Double
        let sizeBase: Double
        let riseSpeed, wanderFreq, wanderAmp, phase: Double
        let warmth: Double // 0=deep orange, 1=pale peach
    }

    @State private var blobs: [LavaBlob] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawGlow(ctx: &ctx, size: size, t: t)
                drawLampBody(ctx: &ctx, size: size, t: t)
                drawBlobs(ctx: &ctx, size: size, t: t)
                drawHighlight(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.03, green: 0.02, blue: 0.02))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
    }

    private func setup() {
        blobs = (0..<18).map { _ in
            LavaBlob(
                baseX: .random(in: 0.35...0.65),
                baseY: .random(in: 0.0...1.0),
                sizeBase: .random(in: 20...70),
                riseSpeed: .random(in: 0.01...0.04),
                wanderFreq: .random(in: 0.3...0.8),
                wanderAmp: .random(in: 0.02...0.06),
                phase: .random(in: 0...(.pi * 2)),
                warmth: .random(in: 0...1)
            )
        }
        ready = true
    }

    // MARK: - Ambient outer glow

    private func drawGlow(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx: Double = size.width * 0.5
        let cy: Double = size.height * 0.5
        let pulse: Double = sin(t * 0.2) * 0.05 + 1.0
        let glowR: Double = max(size.width, size.height) * 0.55 * pulse

        ctx.drawLayer { layerCtx in
            layerCtx.addFilter(.blur(radius: glowR * 0.4))
            let rect = CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)
            layerCtx.fill(
                Ellipse().path(in: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.95, green: 0.45, blue: 0.15).opacity(0.15),
                        Color(red: 0.85, green: 0.3, blue: 0.1).opacity(0.06),
                        Color.clear,
                    ]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: glowR
                )
            )
        }
    }

    // MARK: - Lamp body shape

    private func drawLampBody(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx: Double = size.width * 0.5
        let lampW: Double = size.width * 0.22
        let topY: Double = size.height * 0.15
        let botY: Double = size.height * 0.85
        let midY: Double = size.height * 0.5

        // Organic lamp shape — wider at bottom, tapers at top
        var shape = Path()
        shape.move(to: CGPoint(x: cx, y: topY))

        // Right side
        shape.addCurve(
            to: CGPoint(x: cx + lampW * 0.5, y: midY),
            control1: CGPoint(x: cx + lampW * 0.3, y: topY + (midY - topY) * 0.3),
            control2: CGPoint(x: cx + lampW * 0.55, y: topY + (midY - topY) * 0.7)
        )
        shape.addCurve(
            to: CGPoint(x: cx + lampW * 0.4, y: botY),
            control1: CGPoint(x: cx + lampW * 0.52, y: midY + (botY - midY) * 0.4),
            control2: CGPoint(x: cx + lampW * 0.45, y: midY + (botY - midY) * 0.8)
        )

        // Bottom
        shape.addLine(to: CGPoint(x: cx - lampW * 0.4, y: botY))

        // Left side
        shape.addCurve(
            to: CGPoint(x: cx - lampW * 0.5, y: midY),
            control1: CGPoint(x: cx - lampW * 0.45, y: midY + (botY - midY) * 0.8),
            control2: CGPoint(x: cx - lampW * 0.52, y: midY + (botY - midY) * 0.4)
        )
        shape.addCurve(
            to: CGPoint(x: cx, y: topY),
            control1: CGPoint(x: cx - lampW * 0.55, y: topY + (midY - topY) * 0.7),
            control2: CGPoint(x: cx - lampW * 0.3, y: topY + (midY - topY) * 0.3)
        )
        shape.closeSubpath()

        // Inner warm glow
        let innerPulse: Double = sin(t * 0.15) * 0.04 + 0.96
        ctx.drawLayer { layerCtx in
            layerCtx.clip(to: shape)
            let gradRect = CGRect(x: cx - lampW, y: topY, width: lampW * 2, height: botY - topY)
            layerCtx.fill(
                Rectangle().path(in: gradRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.98, green: 0.65, blue: 0.25).opacity(0.9 * innerPulse),
                        Color(red: 0.95, green: 0.45, blue: 0.15).opacity(0.85 * innerPulse),
                        Color(red: 0.85, green: 0.30, blue: 0.10).opacity(0.9 * innerPulse),
                        Color(red: 0.70, green: 0.20, blue: 0.08).opacity(0.95 * innerPulse),
                    ]),
                    startPoint: CGPoint(x: cx, y: topY),
                    endPoint: CGPoint(x: cx, y: botY)
                )
            )
        }

        // Outline
        ctx.stroke(shape, with: .color(Color(red: 0.6, green: 0.3, blue: 0.15).opacity(0.2)), lineWidth: 1.5)
    }

    // MARK: - Internal lava blobs

    private func drawBlobs(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx: Double = size.width * 0.5
        let lampW: Double = size.width * 0.22
        let topY: Double = size.height * 0.15
        let botY: Double = size.height * 0.85
        let lampH: Double = botY - topY

        // Clip to lamp region
        var clipShape = Path()
        clipShape.addEllipse(in: CGRect(x: cx - lampW * 0.48, y: topY + lampH * 0.05,
                                         width: lampW * 0.96, height: lampH * 0.9))

        ctx.drawLayer { layerCtx in
            layerCtx.clip(to: clipShape)

            for blob in blobs {
                // Rise and loop
                let yFrac: Double = fmod(blob.baseY + t * blob.riseSpeed, 1.0)
                let xWander: Double = sin(t * blob.wanderFreq + blob.phase) * blob.wanderAmp
                let bx: Double = (blob.baseX + xWander) * size.width
                let by: Double = topY + (1.0 - yFrac) * lampH

                // Size breathes
                let breathe: Double = sin(t * 0.4 + blob.phase) * 0.2 + 1.0
                let s: Double = blob.sizeBase * breathe

                // Fade at top and bottom
                let edgeFade: Double = min(yFrac / 0.15, (1.0 - yFrac) / 0.15, 1.0)

                // Color: deep orange to pale peach
                let w: Double = blob.warmth
                let r: Double = 0.95 - w * 0.1
                let g: Double = 0.35 + w * 0.3
                let b: Double = 0.1 + w * 0.15
                let blobColor = Color(red: r, green: g, blue: b)

                let rect = CGRect(x: bx - s / 2, y: by - s / 2, width: s, height: s)

                layerCtx.drawLayer { blobCtx in
                    blobCtx.addFilter(.blur(radius: s * 0.3))
                    blobCtx.opacity = 0.6 * edgeFade
                    blobCtx.fill(
                        Ellipse().path(in: rect),
                        with: .radialGradient(
                            Gradient(colors: [blobColor.opacity(0.9), blobColor.opacity(0.3), blobColor.opacity(0)]),
                            center: CGPoint(x: bx, y: by),
                            startRadius: 0,
                            endRadius: s * 0.5
                        )
                    )
                }
            }
        }
    }

    // MARK: - Specular highlight

    private func drawHighlight(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx: Double = size.width * 0.5
        let topY: Double = size.height * 0.15
        let lampW: Double = size.width * 0.22

        let hlX: Double = cx - lampW * 0.15
        let hlY: Double = topY + size.height * 0.15
        let hlW: Double = lampW * 0.12
        let hlH: Double = size.height * 0.2

        let pulse: Double = sin(t * 0.25) * 0.1 + 0.9

        ctx.drawLayer { layerCtx in
            layerCtx.addFilter(.blur(radius: 8))
            layerCtx.opacity = 0.15 * pulse
            let rect = CGRect(x: hlX - hlW / 2, y: hlY, width: hlW, height: hlH)
            layerCtx.fill(Ellipse().path(in: rect), with: .color(.white))
        }
    }
}
