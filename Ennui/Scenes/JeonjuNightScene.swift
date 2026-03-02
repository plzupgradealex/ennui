import SwiftUI

// Jeonju Night — A Sega Genesis / Mega Drive–style pixel scene of a quiet
// Korean neighbourhood at night, sometime around 1993. Hanok-roofed houses
// with warm yellow window glow, a convenience store (편의점) with a flickering
// fluorescent sign, telephone wires sagging across a lavender sky, a distant
// mountain silhouette, cicadas implied by the summer stillness. A small TV
// antenna on one roof catches moonlight. A cat sits on a wall. Moths circle
// a street lamp. The Seoul '88 Olympic rings appear as a faded mural on a
// concrete wall — barely visible, a memory of when the whole country watched.
// Everything is rendered in chunky 4px pixel blocks, limited palette, flat
// fills, no blur — honest Genesis hardware aesthetic at 320×224 scaled up.
// Tap to flicker a window on or off — someone's going to sleep, or someone
// just woke up. Gentle. Warm. The neighbourhood is fine.

struct JeonjuNightScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()
    @State private var ready = false
    private let px: Double = 4.0

    // ── Data types ──

    struct HanokHouse {
        let x, y, w, h: Double
        let roofOverhang: Double
        let wallR, wallG, wallB: Double
        let roofR, roofG, roofB: Double
        let windowCount: Int
        let windowY: Double
        let hasAntenna: Bool
        let hasCat: Bool
    }

    struct WindowLight {
        let houseIdx: Int
        let nx, ny, w, h: Double    // normalised within house
        let flickerPhase: Double
        let warmth: Double           // 0..1, how amber vs white
    }

    struct TelephoneWire {
        let x1, x2, sagY, baseY: Double
    }

    struct StarData {
        let x, y, size, twinklePhase, twinkleRate: Double
    }

    struct MothData {
        let baseX, baseY, orbitR, speed, phase, size: Double
    }

    struct FlickerEvent: Identifiable {
        let id = UUID()
        let windowIdx: Int
        let birth: Double
    }

    // ── State ──

    @State private var houses: [HanokHouse] = []
    @State private var windows: [WindowLight] = []
    @State private var wires: [TelephoneWire] = []
    @State private var stars: [StarData] = []
    @State private var moths: [MothData] = []
    @State private var flickerEvents: [FlickerEvent] = []
    @State private var windowStates: [Bool] = []  // on/off per window

    // ── Body ──

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawMountain(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawMoon(ctx: &ctx, size: size, t: t)
                drawWires(ctx: &ctx, size: size, t: t)
                drawHouses(ctx: &ctx, size: size, t: t)
                drawWindows(ctx: &ctx, size: size, t: t)
                drawConvenienceStore(ctx: &ctx, size: size, t: t)
                drawOlympicMural(ctx: &ctx, size: size, t: t)
                drawStreetLamp(ctx: &ctx, size: size, t: t)
                drawMoths(ctx: &ctx, size: size, t: t)
                drawCats(ctx: &ctx, size: size, t: t)
                drawGround(ctx: &ctx, size: size, t: t)
                drawScanlines(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.06, green: 0.04, blue: 0.12))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard !windows.isEmpty else { return }
            let t = Date().timeIntervalSince(startDate)
            // Toggle a random lit window
            let litIndices = windowStates.enumerated().filter { $0.element }.map { $0.offset }
            let unlitIndices = windowStates.enumerated().filter { !$0.element }.map { $0.offset }
            let targetIdx: Int
            if litIndices.count > unlitIndices.count, let idx = litIndices.randomElement() {
                targetIdx = idx
            } else if let idx = unlitIndices.randomElement() {
                targetIdx = idx
            } else if let idx = litIndices.randomElement() {
                targetIdx = idx
            } else { return }
            windowStates[targetIdx].toggle()
            flickerEvents.append(FlickerEvent(windowIdx: targetIdx, birth: t))
            if flickerEvents.count > 8 { flickerEvents.removeFirst() }
        }
    }

    // ── Setup ──

    private func setup() {
        var rng = SplitMix64(seed: 1988)

        // Houses — a row of hanok-inspired buildings
        let houseCount = 6
        var cx = 0.02
        for i in 0..<houseCount {
            let w = 0.1 + nextDouble(&rng) * 0.08
            let h = 0.12 + nextDouble(&rng) * 0.06
            let isHanok = nextDouble(&rng) > 0.3
            let house = HanokHouse(
                x: cx, y: 0.55, w: w, h: h,
                roofOverhang: isHanok ? 0.025 : 0.008,
                wallR: isHanok ? 0.85 + nextDouble(&rng) * 0.1 : 0.5 + nextDouble(&rng) * 0.15,
                wallG: isHanok ? 0.78 + nextDouble(&rng) * 0.08 : 0.48 + nextDouble(&rng) * 0.1,
                wallB: isHanok ? 0.65 + nextDouble(&rng) * 0.1 : 0.45 + nextDouble(&rng) * 0.1,
                roofR: isHanok ? 0.25 + nextDouble(&rng) * 0.1 : 0.35 + nextDouble(&rng) * 0.1,
                roofG: isHanok ? 0.2 + nextDouble(&rng) * 0.08 : 0.3 + nextDouble(&rng) * 0.08,
                roofB: isHanok ? 0.18 + nextDouble(&rng) * 0.06 : 0.32 + nextDouble(&rng) * 0.08,
                windowCount: 2 + Int(nextDouble(&rng) * 2),
                windowY: 0.4 + nextDouble(&rng) * 0.2,
                hasAntenna: i == 2 || (nextDouble(&rng) > 0.7),
                hasCat: i == 4
            )
            houses.append(house)

            // Windows for this house
            for wi in 0..<house.windowCount {
                let nx = (Double(wi) + 0.5) / Double(house.windowCount)
                let isLit = nextDouble(&rng) > 0.35
                windows.append(WindowLight(
                    houseIdx: i,
                    nx: nx * 0.7 + 0.15,
                    ny: house.windowY,
                    w: 0.15, h: 0.18,
                    flickerPhase: nextDouble(&rng) * .pi * 2,
                    warmth: 0.6 + nextDouble(&rng) * 0.4
                ))
                windowStates.append(isLit)
            }

            cx += w + 0.012 + nextDouble(&rng) * 0.015
        }

        // Telephone wires
        for i in 0..<3 {
            wires.append(TelephoneWire(
                x1: 0.0, x2: 1.0,
                sagY: 0.015 + nextDouble(&rng) * 0.01,
                baseY: 0.38 + Double(i) * 0.018
            ))
        }

        // Stars
        for _ in 0..<80 {
            stars.append(StarData(
                x: nextDouble(&rng), y: nextDouble(&rng) * 0.4,
                size: 1 + nextDouble(&rng) * 2,
                twinklePhase: nextDouble(&rng) * .pi * 2,
                twinkleRate: 0.3 + nextDouble(&rng) * 1.2
            ))
        }

        // Moths around the street lamp
        for _ in 0..<5 {
            moths.append(MothData(
                baseX: 0.78, baseY: 0.42,
                orbitR: 0.01 + nextDouble(&rng) * 0.02,
                speed: 1.5 + nextDouble(&rng) * 2.0,
                phase: nextDouble(&rng) * .pi * 2,
                size: 2 + nextDouble(&rng) * 2
            ))
        }

        ready = true
    }

    // ── Helpers ──

    private func snap(_ v: Double) -> Double { floor(v / px) * px }

    // ── Draw functions ──

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Genesis-style gradient — banded, not smooth
        let bands = 8
        let bandH = size.height * 0.6 / Double(bands)
        for i in 0..<bands {
            let frac = Double(i) / Double(bands)
            let r = 0.06 + frac * 0.08
            let g = 0.04 + frac * 0.06
            let b = 0.12 + frac * 0.15
            let y = snap(Double(i) * bandH)
            let rect = CGRect(x: 0, y: y, width: size.width, height: snap(bandH + px))
            ctx.fill(Rectangle().path(in: rect),
                     with: .color(Color(red: r, green: g, blue: b)))
        }
    }

    private func drawMountain(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 7777)
        let groundY = size.height * 0.55
        // Distant mountain silhouette — jagged pixel blocks
        var path = Path()
        path.move(to: CGPoint(x: 0, y: groundY))
        var mx = 0.0
        while mx < size.width + px * 2 {
            let h = 30.0 + nextDouble(&rng) * 80.0
            let peakY = snap(groundY - h)
            path.addLine(to: CGPoint(x: snap(mx), y: peakY))
            mx += px * (3 + nextDouble(&rng) * 5)
        }
        path.addLine(to: CGPoint(x: size.width, y: groundY))
        path.closeSubpath()
        ctx.fill(path, with: .color(Color(red: 0.1, green: 0.08, blue: 0.18)))
    }

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for s in stars {
            let twinkle = sin(t * s.twinkleRate + s.twinklePhase) * 0.3 + 0.7
            let x = snap(s.x * size.width)
            let y = snap(s.y * size.height)
            let sz = snap(max(s.size, px))
            let rect = CGRect(x: x, y: y, width: sz, height: sz)
            ctx.fill(Rectangle().path(in: rect),
                     with: .color(Color(red: 0.9, green: 0.85, blue: 0.7).opacity(twinkle)))
        }
    }

    private func drawMoon(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let mx = snap(size.width * 0.82)
        let my = snap(size.height * 0.12)
        let r = px * 6
        // Moon body
        let moonRect = CGRect(x: mx - r, y: my - r, width: r * 2, height: r * 2)
        ctx.fill(Ellipse().path(in: moonRect),
                 with: .color(Color(red: 0.95, green: 0.92, blue: 0.8)))
        // Crescent shadow — shift a dark circle to create crescent
        let shadowRect = CGRect(x: mx - r + px * 3, y: my - r - px, width: r * 2, height: r * 2)
        ctx.fill(Ellipse().path(in: shadowRect),
                 with: .color(Color(red: 0.08, green: 0.06, blue: 0.15)))
        // Subtle glow around moon
        let glowRect = CGRect(x: mx - r * 2.5, y: my - r * 2.5, width: r * 5, height: r * 5)
        ctx.fill(Ellipse().path(in: glowRect),
                 with: .color(Color(red: 0.95, green: 0.9, blue: 0.7).opacity(0.06)))
    }

    private func drawWires(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for wire in wires {
            let y0 = snap(wire.baseY * size.height)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y0))
            // Pixel catenary — step through and sag
            let steps = Int(size.width / px)
            for step in 0...steps {
                let frac = Double(step) / Double(steps)
                let sag = sin(frac * .pi) * wire.sagY * size.height
                let wx = snap(frac * size.width)
                let wy = snap(y0 + sag)
                path.addLine(to: CGPoint(x: wx, y: wy))
            }
            ctx.stroke(path, with: .color(Color(red: 0.15, green: 0.12, blue: 0.2).opacity(0.7)),
                       lineWidth: px * 0.5)
        }
    }

    private func drawHouses(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for (i, h) in houses.enumerated() {
            let hx = snap(h.x * size.width)
            let hy = snap(h.y * size.height)
            let hw = snap(h.w * size.width)
            let hh = snap(h.h * size.height)

            // Wall
            let wallRect = CGRect(x: hx, y: hy - hh, width: hw, height: hh)
            ctx.fill(Rectangle().path(in: wallRect),
                     with: .color(Color(red: h.wallR * 0.25, green: h.wallG * 0.22, blue: h.wallB * 0.2)))

            // Roof — hanok style: curved upward at edges
            let overhang = snap(h.roofOverhang * size.width)
            let roofH = snap(hh * 0.22)
            var roofPath = Path()
            let roofTop = hy - hh - roofH
            let roofLeft = hx - overhang
            let roofRight = hx + hw + overhang
            // Simple pixel-friendly curve: step up at edges
            roofPath.move(to: CGPoint(x: roofLeft, y: snap(hy - hh + px)))
            roofPath.addLine(to: CGPoint(x: roofLeft, y: snap(roofTop + roofH * 0.3)))
            roofPath.addLine(to: CGPoint(x: snap(hx + hw * 0.15), y: roofTop))
            roofPath.addLine(to: CGPoint(x: snap(hx + hw * 0.85), y: roofTop))
            roofPath.addLine(to: CGPoint(x: roofRight, y: snap(roofTop + roofH * 0.3)))
            roofPath.addLine(to: CGPoint(x: roofRight, y: snap(hy - hh + px)))
            roofPath.closeSubpath()
            ctx.fill(roofPath, with: .color(Color(red: h.roofR, green: h.roofG, blue: h.roofB)))

            // TV antenna
            if h.hasAntenna {
                let ax = snap(hx + hw * 0.6)
                let ay = snap(roofTop)
                let antennaH = snap(hh * 0.35)
                // Pole
                ctx.fill(Rectangle().path(in: CGRect(x: ax, y: ay - antennaH, width: px, height: antennaH)),
                         with: .color(Color(red: 0.3, green: 0.28, blue: 0.35)))
                // Arms
                ctx.fill(Rectangle().path(in: CGRect(x: ax - px * 3, y: ay - antennaH, width: px * 7, height: px)),
                         with: .color(Color(red: 0.3, green: 0.28, blue: 0.35)))
                ctx.fill(Rectangle().path(in: CGRect(x: ax - px * 2, y: ay - antennaH + px * 2, width: px * 5, height: px)),
                         with: .color(Color(red: 0.3, green: 0.28, blue: 0.35)))
            }
        }
    }

    private func drawWindows(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for (idx, win) in windows.enumerated() {
            guard win.houseIdx < houses.count else { continue }
            let h = houses[win.houseIdx]
            let hx = h.x * size.width
            let hy = h.y * size.height
            let hw = h.w * size.width
            let hh = h.h * size.height

            let wx = snap(hx + win.nx * hw - win.w * hw * 0.5)
            let wy = snap(hy - hh + win.ny * hh)
            let ww = snap(win.w * hw)
            let wh = snap(win.h * hh)

            let isOn = idx < windowStates.count && windowStates[idx]

            // Flicker check
            var flickerAlpha = 1.0
            for ev in flickerEvents {
                if ev.windowIdx == idx {
                    let age = t - ev.birth
                    if age < 0.5 {
                        flickerAlpha = sin(age * 30) * 0.5 + 0.5
                    }
                }
            }

            if isOn {
                // Warm window glow
                let warmR = 0.95 * win.warmth + 0.8 * (1 - win.warmth)
                let warmG = 0.75 * win.warmth + 0.85 * (1 - win.warmth)
                let warmB = 0.3 * win.warmth + 0.7 * (1 - win.warmth)
                let shimmer = sin(t * 0.8 + win.flickerPhase) * 0.05 + 0.95

                let windowRect = CGRect(x: wx, y: wy, width: ww, height: wh)
                ctx.fill(Rectangle().path(in: windowRect),
                         with: .color(Color(red: warmR, green: warmG, blue: warmB)
                            .opacity(0.7 * shimmer * flickerAlpha)))

                // Window frame (dark cross)
                ctx.fill(Rectangle().path(in: CGRect(x: wx + ww * 0.5 - px * 0.5, y: wy, width: px, height: wh)),
                         with: .color(Color(red: 0.12, green: 0.1, blue: 0.15)))
                ctx.fill(Rectangle().path(in: CGRect(x: wx, y: wy + wh * 0.5 - px * 0.5, width: ww, height: px)),
                         with: .color(Color(red: 0.12, green: 0.1, blue: 0.15)))

                // Light spill on ground
                let spillW = ww * 1.5
                let spillH = px * 3
                let spillX = wx + ww * 0.5 - spillW * 0.5
                let spillY = h.y * size.height
                ctx.fill(Rectangle().path(in: CGRect(x: snap(spillX), y: snap(spillY), width: snap(spillW), height: spillH)),
                         with: .color(Color(red: warmR, green: warmG, blue: warmB).opacity(0.12 * shimmer * flickerAlpha)))
            } else {
                // Dark window
                let windowRect = CGRect(x: wx, y: wy, width: ww, height: wh)
                ctx.fill(Rectangle().path(in: windowRect),
                         with: .color(Color(red: 0.08, green: 0.06, blue: 0.12).opacity(0.8)))
            }
        }
    }

    private func drawConvenienceStore(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Small convenience store at right side — fluorescent-lit
        let sx = snap(size.width * 0.6)
        let sy = snap(size.height * 0.55)
        let sw = snap(size.width * 0.12)
        let sh = snap(size.height * 0.1)

        // Building
        ctx.fill(Rectangle().path(in: CGRect(x: sx, y: sy - sh, width: sw, height: sh)),
                 with: .color(Color(red: 0.35, green: 0.38, blue: 0.4)))

        // Fluorescent sign — flickers slightly
        let signFlicker = sin(t * 12.0) > -0.8 ? 1.0 : 0.3  // occasional brief flicker
        let signH = snap(sh * 0.2)
        let signRect = CGRect(x: sx + px, y: sy - sh - signH, width: sw - px * 2, height: signH)
        ctx.fill(Rectangle().path(in: signRect),
                 with: .color(Color(red: 0.3, green: 0.7, blue: 0.95).opacity(0.7 * signFlicker)))

        // Hangul text suggestion rendered as pixel blocks (편의점 feel)
        // Just a few bright pixel dashes to suggest characters
        let charY = snap(sy - sh - signH + px)
        let charStartX = sx + px * 3
        for ci in 0..<6 {
            let cx = snap(charStartX + Double(ci) * px * 3)
            if ci % 2 == 0 {
                ctx.fill(Rectangle().path(in: CGRect(x: cx, y: charY, width: px * 2, height: px)),
                         with: .color(.white.opacity(0.8 * signFlicker)))
                ctx.fill(Rectangle().path(in: CGRect(x: cx, y: charY + px, width: px, height: px)),
                         with: .color(.white.opacity(0.7 * signFlicker)))
            } else {
                ctx.fill(Rectangle().path(in: CGRect(x: cx, y: charY, width: px, height: px * 2)),
                         with: .color(.white.opacity(0.75 * signFlicker)))
            }
        }

        // Store window — brighter interior
        let winRect = CGRect(x: sx + px * 2, y: sy - sh + px * 2, width: sw - px * 4, height: sh - px * 4)
        ctx.fill(Rectangle().path(in: winRect),
                 with: .color(Color(red: 0.7, green: 0.85, blue: 0.9).opacity(0.4 * signFlicker)))

        // Door
        let doorW = snap(sw * 0.2)
        let doorH = snap(sh * 0.55)
        let doorRect = CGRect(x: sx + sw * 0.5 - doorW * 0.5, y: sy - doorH, width: doorW, height: doorH)
        ctx.fill(Rectangle().path(in: doorRect),
                 with: .color(Color(red: 0.5, green: 0.6, blue: 0.65).opacity(0.5)))

        // Ground light spill
        let spillRect = CGRect(x: sx - px * 2, y: sy, width: sw + px * 4, height: px * 4)
        ctx.fill(Rectangle().path(in: spillRect),
                 with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.08 * signFlicker)))
    }

    private func drawOlympicMural(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Faded Seoul '88 mural on a wall — five small circles (Olympic rings)
        // Very subtle, like it's been there for years and nobody notices anymore
        let mx = snap(size.width * 0.4)
        let my = snap(size.height * 0.5)
        let ringR = px * 1.5
        let gap = px * 3.5
        let alpha = 0.08 + sin(t * 0.15) * 0.02  // barely visible

        let ringColors: [(Double, Double, Double)] = [
            (0.2, 0.4, 0.8),   // blue
            (0.9, 0.85, 0.2),  // yellow
            (0.15, 0.15, 0.15),// black (dark)
            (0.2, 0.7, 0.3),   // green
            (0.85, 0.25, 0.2), // red
        ]

        // Top row: blue, black, red (positions 0, 2, 4)
        // Bottom row: yellow, green (positions 1, 3)
        for (i, col) in ringColors.enumerated() {
            let row = (i == 1 || i == 3) ? 1 : 0
            let col_idx = i < 2 ? i : (i < 4 ? i - 1 : i - 2)
            let cx_val: Double
            let cy_val: Double
            if row == 0 {
                cx_val = mx + Double(col_idx) * gap
                cy_val = my
            } else {
                cx_val = mx + gap * 0.5 + Double(col_idx) * gap
                cy_val = my + ringR * 1.2
            }
            // Draw ring as pixel outline
            let rRect = CGRect(x: snap(cx_val - ringR), y: snap(cy_val - ringR),
                              width: snap(ringR * 2), height: snap(ringR * 2))
            ctx.stroke(Ellipse().path(in: rRect),
                       with: .color(Color(red: col.0, green: col.1, blue: col.2).opacity(alpha)),
                       lineWidth: px * 0.5)
        }

        // Tiny "88" below
        let numY = snap(my + ringR * 3)
        let numX = snap(mx + gap)
        // Two small 8-shaped pixel glyphs
        for n in 0..<2 {
            let nx = numX + Double(n) * px * 4
            // Top circle of 8
            ctx.fill(Rectangle().path(in: CGRect(x: snap(nx), y: numY, width: px * 2, height: px)),
                     with: .color(.white.opacity(alpha)))
            ctx.fill(Rectangle().path(in: CGRect(x: snap(nx), y: numY + px * 2, width: px * 2, height: px)),
                     with: .color(.white.opacity(alpha)))
            ctx.fill(Rectangle().path(in: CGRect(x: snap(nx - px * 0.5), y: numY + px, width: px, height: px)),
                     with: .color(.white.opacity(alpha)))
            ctx.fill(Rectangle().path(in: CGRect(x: snap(nx + px * 2 - px * 0.5), y: numY + px, width: px, height: px)),
                     with: .color(.white.opacity(alpha)))
            // Bottom circle of 8
            ctx.fill(Rectangle().path(in: CGRect(x: snap(nx), y: numY + px * 3, width: px * 2, height: px)),
                     with: .color(.white.opacity(alpha)))
            ctx.fill(Rectangle().path(in: CGRect(x: snap(nx - px * 0.5), y: numY + px * 4, width: px, height: px)),
                     with: .color(.white.opacity(alpha)))
            ctx.fill(Rectangle().path(in: CGRect(x: snap(nx + px * 2 - px * 0.5), y: numY + px * 4, width: px, height: px)),
                     with: .color(.white.opacity(alpha)))
        }
    }

    private func drawStreetLamp(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let lx = snap(size.width * 0.78)
        let groundY = snap(size.height * 0.55)
        let poleH = snap(size.height * 0.16)

        // Pole
        ctx.fill(Rectangle().path(in: CGRect(x: lx, y: groundY - poleH, width: px, height: poleH)),
                 with: .color(Color(red: 0.25, green: 0.22, blue: 0.3)))

        // Lamp head
        let lampW = px * 4
        let lampH = px * 2
        ctx.fill(Rectangle().path(in: CGRect(x: lx - lampW * 0.5 + px * 0.5, y: groundY - poleH - lampH, width: lampW, height: lampH)),
                 with: .color(Color(red: 0.3, green: 0.28, blue: 0.35)))

        // Light glow
        let glowPulse = sin(t * 0.5) * 0.02 + 0.98
        let glowR = px * 12
        let glowRect = CGRect(x: lx - glowR * 0.5, y: groundY - poleH - glowR * 0.5,
                              width: glowR, height: glowR)
        ctx.fill(Ellipse().path(in: glowRect),
                 with: .color(Color(red: 0.95, green: 0.85, blue: 0.5).opacity(0.08 * glowPulse)))

        // Bright center
        let coreRect = CGRect(x: lx - px, y: groundY - poleH - px * 2, width: px * 3, height: px * 2)
        ctx.fill(Rectangle().path(in: coreRect),
                 with: .color(Color(red: 0.95, green: 0.9, blue: 0.6).opacity(0.6 * glowPulse)))
    }

    private func drawMoths(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for m in moths {
            let angle = t * m.speed + m.phase
            let mx = snap(m.baseX * size.width + cos(angle) * m.orbitR * size.width)
            let my = snap(m.baseY * size.height + sin(angle * 1.3) * m.orbitR * size.height * 0.6)
            let wingFlap = abs(sin(t * 8 + m.phase))
            let sz = snap(m.size * (0.5 + wingFlap * 0.5))
            let rect = CGRect(x: mx, y: my, width: max(sz, px), height: max(px, sz * 0.5))
            ctx.fill(Rectangle().path(in: rect),
                     with: .color(Color(red: 0.8, green: 0.75, blue: 0.6).opacity(0.5 + wingFlap * 0.3)))
        }
    }

    private func drawCats(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Cat sitting on the wall of house 4 (if it has one)
        for (i, h) in houses.enumerated() {
            guard h.hasCat else { continue }
            let hx = h.x * size.width
            let hy = h.y * size.height
            let hw = h.w * size.width
            let hh = h.h * size.height

            let cx = snap(hx + hw * 0.8)
            let cy = snap(hy - hh - px * 2)

            // Body
            ctx.fill(Rectangle().path(in: CGRect(x: cx, y: cy, width: px * 3, height: px * 2)),
                     with: .color(Color(red: 0.2, green: 0.18, blue: 0.25)))
            // Head
            ctx.fill(Rectangle().path(in: CGRect(x: cx + px, y: cy - px * 2, width: px * 2, height: px * 2)),
                     with: .color(Color(red: 0.2, green: 0.18, blue: 0.25)))
            // Ears
            ctx.fill(Rectangle().path(in: CGRect(x: cx + px, y: cy - px * 3, width: px, height: px)),
                     with: .color(Color(red: 0.2, green: 0.18, blue: 0.25)))
            ctx.fill(Rectangle().path(in: CGRect(x: cx + px * 2, y: cy - px * 3, width: px, height: px)),
                     with: .color(Color(red: 0.2, green: 0.18, blue: 0.25)))
            // Eyes — tiny bright pixels, blink occasionally
            let blink = sin(t * 0.3 + Double(i))
            if blink > -0.95 {  // eyes open most of the time
                ctx.fill(Rectangle().path(in: CGRect(x: cx + px, y: cy - px, width: px * 0.5, height: px * 0.5)),
                         with: .color(Color(red: 0.6, green: 0.8, blue: 0.3).opacity(0.7)))
                ctx.fill(Rectangle().path(in: CGRect(x: cx + px * 2, y: cy - px, width: px * 0.5, height: px * 0.5)),
                         with: .color(Color(red: 0.6, green: 0.8, blue: 0.3).opacity(0.7)))
            }
            // Tail
            ctx.fill(Rectangle().path(in: CGRect(x: cx - px, y: cy + px, width: px, height: px)),
                     with: .color(Color(red: 0.2, green: 0.18, blue: 0.25)))
            ctx.fill(Rectangle().path(in: CGRect(x: cx - px * 2, y: cy, width: px, height: px)),
                     with: .color(Color(red: 0.2, green: 0.18, blue: 0.25)))
        }
    }

    private func drawGround(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let groundY = snap(size.height * 0.55)
        // Dark ground
        let groundRect = CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)
        ctx.fill(Rectangle().path(in: groundRect),
                 with: .color(Color(red: 0.08, green: 0.06, blue: 0.1)))

        // Road/path slightly lighter stripe
        let roadY = snap(groundY + px * 2)
        let roadH = snap(size.height * 0.04)
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: roadY, width: size.width, height: roadH)),
                 with: .color(Color(red: 0.12, green: 0.1, blue: 0.14)))

        // Dashed center line
        var dx = 0.0
        while dx < size.width {
            let dashRect = CGRect(x: snap(dx), y: snap(roadY + roadH * 0.45), width: px * 3, height: px * 0.5)
            ctx.fill(Rectangle().path(in: dashRect),
                     with: .color(Color(red: 0.4, green: 0.38, blue: 0.3).opacity(0.25)))
            dx += px * 8
        }
    }

    private func drawScanlines(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // CRT/Genesis scanline overlay
        var y = 0.0
        while y < size.height {
            if Int(y / px) % 2 == 0 {
                let lineRect = CGRect(x: 0, y: y, width: size.width, height: max(1, px * 0.3))
                ctx.fill(Rectangle().path(in: lineRect),
                         with: .color(.black.opacity(0.08)))
            }
            y += px
        }
    }
}
