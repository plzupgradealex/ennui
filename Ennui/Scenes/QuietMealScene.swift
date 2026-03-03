import SwiftUI

// Quiet Meal — You are standing outside a strip-mall restaurant at dusk,
// looking in through the plate glass. Two friends sit across from each other
// at a small table. One gestures with chopsticks, the other covers their
// mouth laughing. The food is nothing special — bowls, plates, cups of water.
// The fluorescent light inside is warm where it shouldn't be, because it's
// the company that makes it warm. A neon "OPEN" sign glows in the corner of
// the window. Outside, where you stand, it's blue-grey evening. Condensation
// fogs the window edges. If you tap, a raindrop slides down the glass — 
// because of course it's raining gently, the way it always seems to be
// in memories like this. The friends don't notice you. They don't need to.
// They are simply together, and that is enough.

struct QuietMealScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()
    @State private var ready = false
    private let px: Double = 3.0

    // ── Data ──

    struct Raindrop: Identifiable {
        let id = UUID()
        var x, y: Double
        let speed: Double
        let birth: Double
        let wobblePhase: Double
    }

    struct CondensationDot {
        let x, y, r, opacity: Double
    }

    // ── State ──

    @State private var raindrops: [Raindrop] = []
    @State private var condensation: [CondensationDot] = []
    @State private var bgRaindrops: [(x: Double, y: Double, speed: Double, phase: Double)] = []

    // ── Body ──

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawExterior(ctx: &ctx, size: size, t: t)
                drawRainBackground(ctx: &ctx, size: size, t: t)
                drawWindow(ctx: &ctx, size: size, t: t)
                drawInterior(ctx: &ctx, size: size, t: t)
                drawFriendLeft(ctx: &ctx, size: size, t: t)
                drawFriendRight(ctx: &ctx, size: size, t: t)
                drawTable(ctx: &ctx, size: size, t: t)
                drawFood(ctx: &ctx, size: size, t: t)
                drawOpenSign(ctx: &ctx, size: size, t: t)
                drawWindowGlass(ctx: &ctx, size: size, t: t)
                drawCondensation(ctx: &ctx, size: size, t: t)
                drawWindowRaindrops(ctx: &ctx, size: size, t: t)
                drawWindowFrame(ctx: &ctx, size: size, t: t)
                drawExteriorForeground(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.1, green: 0.12, blue: 0.2))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            let t = Date().timeIntervalSince(startDate)
            // Add a raindrop on the glass
            var rng = SplitMix64(seed: UInt64(interaction.tapCount) &+ 42)
            let drop = Raindrop(
                x: 0.15 + nextDouble(&rng) * 0.7,
                y: 0.1 + nextDouble(&rng) * 0.2,
                speed: 0.04 + nextDouble(&rng) * 0.04,
                birth: t,
                wobblePhase: nextDouble(&rng) * .pi * 2
            )
            raindrops.append(drop)
            if raindrops.count > 12 { raindrops.removeFirst() }
        }
    }

    // ── Setup ──

    private func setup() {
        var rng = SplitMix64(seed: 2024)

        // Condensation dots around window edges
        for _ in 0..<120 {
            let edge = Int(nextDouble(&rng) * 4)
            let x: Double
            let y: Double
            switch edge {
            case 0: // top
                x = 0.12 + nextDouble(&rng) * 0.76
                y = 0.1 + nextDouble(&rng) * 0.08
            case 1: // bottom
                x = 0.12 + nextDouble(&rng) * 0.76
                y = 0.78 + nextDouble(&rng) * 0.08
            case 2: // left
                x = 0.12 + nextDouble(&rng) * 0.08
                y = 0.1 + nextDouble(&rng) * 0.76
            default: // right
                x = 0.82 + nextDouble(&rng) * 0.08
                y = 0.1 + nextDouble(&rng) * 0.76
            }
            condensation.append(CondensationDot(
                x: x, y: y,
                r: 1 + nextDouble(&rng) * 3,
                opacity: 0.03 + nextDouble(&rng) * 0.06
            ))
        }

        // Background rain
        for _ in 0..<60 {
            bgRaindrops.append((
                x: nextDouble(&rng),
                y: nextDouble(&rng),
                speed: 0.3 + nextDouble(&rng) * 0.5,
                phase: nextDouble(&rng)
            ))
        }

        ready = true
    }

    // ── Helpers ──

    private func snap(_ v: Double) -> Double { floor(v / px) * px }

    private func windowRect(size: CGSize) -> CGRect {
        CGRect(x: snap(size.width * 0.12), y: snap(size.height * 0.08),
               width: snap(size.width * 0.76), height: snap(size.height * 0.78))
    }

    // ── Drawing ──

    private func drawExterior(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Dusk sky gradient — banded
        let bands = 5
        for i in 0..<bands {
            let frac = Double(i) / Double(bands)
            let r = 0.12 + frac * 0.05
            let g = 0.14 + frac * 0.04
            let b = 0.22 + frac * 0.06
            let bh = size.height / Double(bands)
            let rect = CGRect(x: 0, y: snap(Double(i) * bh), width: size.width, height: snap(bh + px))
            ctx.fill(Rectangle().path(in: rect),
                     with: .color(Color(red: r, green: g, blue: b)))
        }

        // Sidewalk at bottom
        let sideY = snap(size.height * 0.86)
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: sideY, width: size.width, height: size.height - sideY)),
                 with: .color(Color(red: 0.18, green: 0.17, blue: 0.2)))

        // Wet sidewalk reflection — cool with a hint of interior warmth
        let reflAlpha = sin(t * 0.3) * 0.01 + 0.03
        ctx.fill(Rectangle().path(in: CGRect(x: snap(size.width * 0.2), y: snap(sideY + px),
                                              width: snap(size.width * 0.6), height: snap(size.height * 0.06))),
                 with: .color(Color(red: 0.45, green: 0.45, blue: 0.4).opacity(reflAlpha)))
    }

    private func drawRainBackground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for drop in bgRaindrops {
            let y = ((drop.y + t * drop.speed).truncatingRemainder(dividingBy: 1.0))
            let x = drop.x + sin(y * 3 + drop.phase) * 0.005
            let dx = snap(x * size.width)
            let dy = snap(y * size.height)
            let len = snap(px * 2)
            ctx.fill(Rectangle().path(in: CGRect(x: dx, y: dy, width: 1, height: len)),
                     with: .color(Color(red: 0.5, green: 0.55, blue: 0.65).opacity(0.12)))
        }
    }

    private func drawWindow(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Window opening — muted interior base, warmth comes from the light
        let wr = windowRect(size: size)
        ctx.fill(Rectangle().path(in: wr),
                 with: .color(Color(red: 0.55, green: 0.52, blue: 0.45).opacity(0.3)))
    }

    private func drawInterior(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wr = windowRect(size: size)

        // Back wall — muted cream, not yellow
        ctx.fill(Rectangle().path(in: CGRect(x: wr.minX, y: wr.minY,
                                              width: wr.width, height: wr.height * 0.45)),
                 with: .color(Color(red: 0.55, green: 0.52, blue: 0.48).opacity(0.18)))

        // Floor — cool dark tone
        ctx.fill(Rectangle().path(in: CGRect(x: wr.minX, y: wr.minY + wr.height * 0.65,
                                              width: wr.width, height: wr.height * 0.35)),
                 with: .color(Color(red: 0.25, green: 0.22, blue: 0.22).opacity(0.25)))

        // Fluorescent light fixture on ceiling — warm hum
        let lightW = snap(wr.width * 0.35)
        let lightH = snap(px * 2)
        let lightX = snap(wr.midX - lightW * 0.5)
        let lightY = snap(wr.minY + px * 4)
        let flicker = sin(t * 8) > -0.95 ? 1.0 : 0.85
        ctx.fill(Rectangle().path(in: CGRect(x: lightX, y: lightY, width: lightW, height: lightH)),
                 with: .color(Color(red: 0.92, green: 0.88, blue: 0.78).opacity(0.4 * flicker)))

        // Light cone downward — subtle, warmth is focused
        var cone = Path()
        cone.move(to: CGPoint(x: lightX, y: lightY + lightH))
        cone.addLine(to: CGPoint(x: lightX - wr.width * 0.08, y: wr.minY + wr.height * 0.65))
        cone.addLine(to: CGPoint(x: lightX + lightW + wr.width * 0.08, y: wr.minY + wr.height * 0.65))
        cone.addLine(to: CGPoint(x: lightX + lightW, y: lightY + lightH))
        cone.closeSubpath()
        ctx.fill(cone, with: .color(Color(red: 0.9, green: 0.85, blue: 0.7).opacity(0.025 * flicker)))
    }

    private func drawFriendLeft(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wr = windowRect(size: size)
        // Left friend — sitting, slightly leaning back
        let cx = snap(wr.minX + wr.width * 0.35)
        let cy = snap(wr.minY + wr.height * 0.42)

        // Body / torso (seen from the side-ish, facing right)
        let torsoW = snap(px * 6)
        let torsoH = snap(px * 8)
        ctx.fill(Rectangle().path(in: CGRect(x: cx - torsoW * 0.5, y: cy, width: torsoW, height: torsoH)),
                 with: .color(Color(red: 0.35, green: 0.4, blue: 0.55).opacity(0.55))) // dark blue shirt

        // Head
        let headSize = snap(px * 5)
        let headY = snap(cy - headSize - px)
        ctx.fill(Ellipse().path(in: CGRect(x: cx - headSize * 0.5, y: headY, width: headSize, height: headSize)),
                 with: .color(Color(red: 0.85, green: 0.7, blue: 0.55).opacity(0.5)))

        // Hair
        ctx.fill(Rectangle().path(in: CGRect(x: cx - headSize * 0.5, y: headY, width: headSize, height: snap(headSize * 0.35))),
                 with: .color(Color(red: 0.15, green: 0.12, blue: 0.1).opacity(0.5)))

        // Arm — reaching toward table, gesturing gently
        let gesture = sin(t * 0.6) * px * 1.5
        let armX = snap(cx + torsoW * 0.3)
        let armY = snap(cy + torsoH * 0.2 + gesture)
        ctx.fill(Rectangle().path(in: CGRect(x: armX, y: armY, width: snap(px * 5), height: snap(px * 2))),
                 with: .color(Color(red: 0.85, green: 0.7, blue: 0.55).opacity(0.45)))
    }

    private func drawFriendRight(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wr = windowRect(size: size)
        // Right friend — leaning in slightly, covering mouth when laughing
        let cx = snap(wr.minX + wr.width * 0.65)
        let cy = snap(wr.minY + wr.height * 0.42)

        // Torso
        let torsoW = snap(px * 6)
        let torsoH = snap(px * 8)
        ctx.fill(Rectangle().path(in: CGRect(x: cx - torsoW * 0.5, y: cy, width: torsoW, height: torsoH)),
                 with: .color(Color(red: 0.5, green: 0.38, blue: 0.35).opacity(0.55))) // warm brown sweater

        // Head — slight bob when "laughing"
        let laughCycle = sin(t * 0.8)
        let headBob = laughCycle > 0.7 ? snap(px * 0.5) : 0
        let headSize = snap(px * 5)
        let headY = snap(cy - headSize - px + headBob)
        ctx.fill(Ellipse().path(in: CGRect(x: cx - headSize * 0.5, y: headY, width: headSize, height: headSize)),
                 with: .color(Color(red: 0.85, green: 0.7, blue: 0.55).opacity(0.5)))

        // Hair
        ctx.fill(Rectangle().path(in: CGRect(x: cx - headSize * 0.5, y: headY, width: headSize, height: snap(headSize * 0.35))),
                 with: .color(Color(red: 0.12, green: 0.1, blue: 0.08).opacity(0.5)))

        // Hand near mouth when laughing — subtle
        if laughCycle > 0.6 {
            let handX = snap(cx - headSize * 0.1)
            let handY = snap(headY + headSize * 0.6)
            ctx.fill(Rectangle().path(in: CGRect(x: handX, y: handY, width: snap(px * 3), height: snap(px * 2))),
                     with: .color(Color(red: 0.85, green: 0.7, blue: 0.55).opacity(0.4)))
        }

        // Arm resting
        let armX = snap(cx - torsoW * 0.3 - px * 4)
        let armY = snap(cy + torsoH * 0.3)
        ctx.fill(Rectangle().path(in: CGRect(x: armX, y: armY, width: snap(px * 5), height: snap(px * 2))),
                 with: .color(Color(red: 0.85, green: 0.7, blue: 0.55).opacity(0.45)))
    }

    private func drawTable(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wr = windowRect(size: size)
        // Simple table between the two friends
        let tx = snap(wr.minX + wr.width * 0.38)
        let ty = snap(wr.minY + wr.height * 0.58)
        let tw = snap(wr.width * 0.24)
        let th = snap(px * 2)

        // Table top
        ctx.fill(Rectangle().path(in: CGRect(x: tx, y: ty, width: tw, height: th)),
                 with: .color(Color(red: 0.55, green: 0.42, blue: 0.3).opacity(0.45)))

        // Table legs
        ctx.fill(Rectangle().path(in: CGRect(x: tx + px * 2, y: ty + th, width: px, height: snap(px * 6))),
                 with: .color(Color(red: 0.45, green: 0.35, blue: 0.25).opacity(0.35)))
        ctx.fill(Rectangle().path(in: CGRect(x: tx + tw - px * 3, y: ty + th, width: px, height: snap(px * 6))),
                 with: .color(Color(red: 0.45, green: 0.35, blue: 0.25).opacity(0.35)))
    }

    private func drawFood(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wr = windowRect(size: size)
        let ty = snap(wr.minY + wr.height * 0.55)

        // Left plate/bowl
        let lx = snap(wr.minX + wr.width * 0.39)
        ctx.fill(Ellipse().path(in: CGRect(x: lx, y: ty, width: snap(px * 5), height: snap(px * 2.5))),
                 with: .color(Color.white.opacity(0.2)))
        // Food suggestion — warm blob
        ctx.fill(Ellipse().path(in: CGRect(x: lx + px, y: ty + px * 0.3, width: snap(px * 3), height: snap(px * 1.5))),
                 with: .color(Color(red: 0.7, green: 0.5, blue: 0.3).opacity(0.2)))

        // Right plate/bowl
        let rx = snap(wr.minX + wr.width * 0.55)
        ctx.fill(Ellipse().path(in: CGRect(x: rx, y: ty, width: snap(px * 5), height: snap(px * 2.5))),
                 with: .color(Color.white.opacity(0.2)))
        ctx.fill(Ellipse().path(in: CGRect(x: rx + px, y: ty + px * 0.3, width: snap(px * 3), height: snap(px * 1.5))),
                 with: .color(Color(red: 0.65, green: 0.55, blue: 0.35).opacity(0.2)))

        // Water glasses
        let glassH = snap(px * 3)
        let glassW = snap(px * 1.5)
        ctx.fill(Rectangle().path(in: CGRect(x: snap(lx + px * 5.5), y: ty - px, width: glassW, height: glassH)),
                 with: .color(Color(red: 0.6, green: 0.75, blue: 0.85).opacity(0.15)))
        ctx.fill(Rectangle().path(in: CGRect(x: snap(rx - px * 2), y: ty - px, width: glassW, height: glassH)),
                 with: .color(Color(red: 0.6, green: 0.75, blue: 0.85).opacity(0.15)))

        // Tiny steam wisps from the bowls
        let steam1 = sin(t * 1.2) * px
        let steam2 = sin(t * 1.2 + 1) * px
        ctx.fill(Rectangle().path(in: CGRect(x: snap(lx + px * 2 + steam1), y: snap(ty - px * 2), width: px, height: px)),
                 with: .color(.white.opacity(0.06)))
        ctx.fill(Rectangle().path(in: CGRect(x: snap(rx + px * 2 + steam2), y: snap(ty - px * 2.5), width: px, height: px)),
                 with: .color(.white.opacity(0.06)))
    }

    private func drawOpenSign(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wr = windowRect(size: size)
        // Neon "OPEN" sign in lower-right of window
        let sx = snap(wr.maxX - wr.width * 0.18)
        let sy = snap(wr.maxY - wr.height * 0.15)
        let signW = snap(px * 12)
        let signH = snap(px * 5)

        // Sign background
        ctx.fill(Rectangle().path(in: CGRect(x: sx, y: sy, width: signW, height: signH)),
                 with: .color(Color(red: 0.05, green: 0.05, blue: 0.08).opacity(0.4)))

        // Neon glow — warm red/orange
        let flicker = sin(t * 6) > -0.9 ? 1.0 : 0.4
        let glow = 0.4 * flicker

        // O
        ctx.fill(Rectangle().path(in: CGRect(x: sx + px, y: sy + px, width: px * 2, height: px * 3)),
                 with: .color(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(glow)))
        // P
        ctx.fill(Rectangle().path(in: CGRect(x: sx + px * 4, y: sy + px, width: px, height: px * 3)),
                 with: .color(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(glow)))
        ctx.fill(Rectangle().path(in: CGRect(x: sx + px * 5, y: sy + px, width: px, height: px * 1.5)),
                 with: .color(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(glow)))
        // E
        ctx.fill(Rectangle().path(in: CGRect(x: sx + px * 7, y: sy + px, width: px, height: px * 3)),
                 with: .color(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(glow)))
        ctx.fill(Rectangle().path(in: CGRect(x: sx + px * 8, y: sy + px, width: px, height: px)),
                 with: .color(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(glow)))
        // N
        ctx.fill(Rectangle().path(in: CGRect(x: sx + px * 10, y: sy + px, width: px, height: px * 3)),
                 with: .color(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(glow)))
        ctx.fill(Rectangle().path(in: CGRect(x: sx + px * 11, y: sy + px, width: px, height: px * 3)),
                 with: .color(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(glow)))

        // Neon glow halo
        let haloRect = CGRect(x: sx - px * 2, y: sy - px * 2, width: signW + px * 4, height: signH + px * 4)
        ctx.fill(Rectangle().path(in: haloRect),
                 with: .color(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(0.03 * flicker)))
    }

    private func drawWindowGlass(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Glass overlay — cool blue tint, the barrier between you and the warmth
        let wr = windowRect(size: size)
        ctx.fill(Rectangle().path(in: wr),
                 with: .color(Color(red: 0.4, green: 0.5, blue: 0.7).opacity(0.1)))

        // Reflection streak — a diagonal glint
        let streakAngle = 0.2
        var streak = Path()
        let sx = wr.minX + wr.width * 0.15
        let sy = wr.minY
        streak.move(to: CGPoint(x: snap(sx), y: snap(sy)))
        streak.addLine(to: CGPoint(x: snap(sx + wr.width * 0.03), y: snap(sy)))
        streak.addLine(to: CGPoint(x: snap(sx + wr.width * streakAngle + wr.width * 0.03), y: snap(wr.maxY)))
        streak.addLine(to: CGPoint(x: snap(sx + wr.width * streakAngle), y: snap(wr.maxY)))
        streak.closeSubpath()
        ctx.fill(streak, with: .color(.white.opacity(0.02)))
    }

    private func drawCondensation(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for dot in condensation {
            let x = dot.x * size.width
            let y = dot.y * size.height
            let breathe = sin(t * 0.2 + dot.x * 10) * 0.01
            let rect = CGRect(x: snap(x - dot.r), y: snap(y - dot.r),
                              width: snap(dot.r * 2), height: snap(dot.r * 2))
            ctx.fill(Ellipse().path(in: rect),
                     with: .color(Color(red: 0.8, green: 0.85, blue: 0.9).opacity(dot.opacity + breathe)))
        }
    }

    private func drawWindowRaindrops(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for drop in raindrops {
            let age = t - drop.birth
            guard age > 0 else { continue }
            let travel = age * drop.speed
            let x = snap((drop.x + sin(age * 2 + drop.wobblePhase) * 0.005) * size.width)
            let y = snap((drop.y + travel) * size.height)
            guard y < size.height * 0.85 else { continue }

            // Drop body
            let dropH = snap(px * 2.5)
            let dropW = snap(px * 1.5)
            ctx.fill(Ellipse().path(in: CGRect(x: x, y: y, width: dropW, height: dropH)),
                     with: .color(Color(red: 0.7, green: 0.75, blue: 0.85).opacity(0.2)))

            // Trail
            let trailH = snap(min(age * 20, 40))
            if trailH > px {
                ctx.fill(Rectangle().path(in: CGRect(x: x + dropW * 0.3, y: y - trailH, width: px * 0.5, height: trailH)),
                         with: .color(Color(red: 0.7, green: 0.75, blue: 0.85).opacity(0.06)))
            }

            // Tiny refraction — the drop distorts the interior light
            ctx.fill(Ellipse().path(in: CGRect(x: x + px * 0.3, y: y + px * 0.3, width: px, height: px * 0.8)),
                     with: .color(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.08)))
        }
    }

    private func drawWindowFrame(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wr = windowRect(size: size)
        let frameW = snap(px * 3)

        // Frame — dark metal
        let frameColor = Color(red: 0.2, green: 0.2, blue: 0.22)

        // Top
        ctx.fill(Rectangle().path(in: CGRect(x: wr.minX - frameW, y: wr.minY - frameW,
                                              width: wr.width + frameW * 2, height: frameW)),
                 with: .color(frameColor))
        // Bottom
        ctx.fill(Rectangle().path(in: CGRect(x: wr.minX - frameW, y: wr.maxY,
                                              width: wr.width + frameW * 2, height: frameW)),
                 with: .color(frameColor))
        // Left
        ctx.fill(Rectangle().path(in: CGRect(x: wr.minX - frameW, y: wr.minY,
                                              width: frameW, height: wr.height)),
                 with: .color(frameColor))
        // Right
        ctx.fill(Rectangle().path(in: CGRect(x: wr.maxX, y: wr.minY,
                                              width: frameW, height: wr.height)),
                 with: .color(frameColor))

        // Center vertical divider
        let divX = snap(wr.midX - px)
        ctx.fill(Rectangle().path(in: CGRect(x: divX, y: wr.minY, width: snap(px * 2), height: wr.height)),
                 with: .color(frameColor.opacity(0.7)))

        // Wall around window
        let wallColor = Color(red: 0.22, green: 0.2, blue: 0.18)
        // Left wall
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: 0, width: wr.minX - frameW, height: size.height * 0.86)),
                 with: .color(wallColor))
        // Right wall
        ctx.fill(Rectangle().path(in: CGRect(x: wr.maxX + frameW, y: 0,
                                              width: size.width - wr.maxX - frameW, height: size.height * 0.86)),
                 with: .color(wallColor))
        // Above window
        ctx.fill(Rectangle().path(in: CGRect(x: wr.minX - frameW, y: 0,
                                              width: wr.width + frameW * 2, height: wr.minY - frameW)),
                 with: .color(wallColor))
        // Below window (to sidewalk)
        ctx.fill(Rectangle().path(in: CGRect(x: wr.minX - frameW, y: wr.maxY + frameW,
                                              width: wr.width + frameW * 2,
                                              height: size.height * 0.86 - wr.maxY - frameW)),
                 with: .color(wallColor))
    }

    private func drawExteriorForeground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Awning above window
        let wr = windowRect(size: size)
        let awningH = snap(px * 4)
        var awning = Path()
        awning.move(to: CGPoint(x: wr.minX - px * 4, y: snap(wr.minY - px * 5)))
        awning.addLine(to: CGPoint(x: wr.maxX + px * 4, y: snap(wr.minY - px * 5)))
        awning.addLine(to: CGPoint(x: wr.maxX + px * 6, y: snap(wr.minY - px * 5 + awningH)))
        awning.addLine(to: CGPoint(x: wr.minX - px * 6, y: snap(wr.minY - px * 5 + awningH)))
        awning.closeSubpath()
        ctx.fill(awning, with: .color(Color(red: 0.3, green: 0.15, blue: 0.12).opacity(0.6)))

        // Awning stripes
        let stripeCount = 8
        let stripeW = (wr.width + px * 12) / Double(stripeCount)
        for i in stride(from: 0, to: stripeCount, by: 2) {
            let sx = snap(wr.minX - px * 6 + Double(i) * stripeW)
            ctx.fill(Rectangle().path(in: CGRect(x: sx, y: snap(wr.minY - px * 5),
                                                  width: snap(stripeW), height: awningH)),
                     with: .color(Color(red: 0.4, green: 0.18, blue: 0.15).opacity(0.3)))
        }
    }
}
