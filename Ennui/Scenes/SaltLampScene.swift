import SwiftUI

// Salt Lamp — a 90s vintage room bathed in the warm amber glow of a
// Himalayan salt lamp. You see the room: a bookshelf, a worn armchair,
// a side table with a mug, a plant, a rug. On the far wall a round
// mirror catches the salt lamp's reflection — a small glowing jewel.
// Dust motes drift through the warm light. The glow breathes.
// Tap to intensify the warmth momentarily.

struct SaltLampScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    struct BookData {
        let x, width, height, hue, saturation, brightness: Double
    }
    struct DustMote {
        let x, y, size, speed, phase, brightness: Double
    }
    struct PlantLeaf {
        let angle, length, curve, phase: Double
    }
    struct WarmthPulse {
        let birth: Double
        let seed: UInt64
    }

    @State private var books: [BookData] = []
    @State private var dustMotes: [DustMote] = []
    @State private var plantLeaves: [PlantLeaf] = []
    @State private var warmthPulses: [WarmthPulse] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawRoom(ctx: &ctx, size: size, t: t)
                drawLampGlow(ctx: &ctx, size: size, t: t)
                drawFloor(ctx: &ctx, size: size, t: t)
                drawRug(ctx: &ctx, size: size, t: t)
                drawBookshelf(ctx: &ctx, size: size, t: t)
                drawArmchair(ctx: &ctx, size: size, t: t)
                drawSideTable(ctx: &ctx, size: size, t: t)
                drawPlant(ctx: &ctx, size: size, t: t)
                drawMirror(ctx: &ctx, size: size, t: t)
                drawCurtains(ctx: &ctx, size: size, t: t)
                drawDust(ctx: &ctx, size: size, t: t)
                drawWarmthPulse(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.025, green: 0.02, blue: 0.015))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            let t = Date().timeIntervalSince(startDate)
            warmthPulses.append(WarmthPulse(birth: t, seed: UInt64(t * 1000) & 0xFFFFFF))
            if warmthPulses.count > 5 { warmthPulses.removeFirst() }
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 1997) // peak salt lamp era

        // Books on shelf
        var bx = 0.0
        var bookArr: [BookData] = []
        while bx < 1.0 {
            let w = Double.random(in: 0.025...0.055, using: &rng)
            let h = Double.random(in: 0.55...0.92, using: &rng)
            bookArr.append(BookData(
                x: bx, width: w, height: h,
                hue: Double.random(in: 0.0...0.12, using: &rng),
                saturation: Double.random(in: 0.3...0.7, using: &rng),
                brightness: Double.random(in: 0.12...0.28, using: &rng)
            ))
            bx += w + Double.random(in: 0.002...0.008, using: &rng)
        }
        books = bookArr

        dustMotes = (0..<35).map { _ in
            DustMote(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0.1...0.85, using: &rng),
                size: Double.random(in: 0.8...2.5, using: &rng),
                speed: Double.random(in: 0.003...0.012, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng),
                brightness: Double.random(in: 0.15...0.40, using: &rng)
            )
        }

        plantLeaves = (0..<9).map { _ in
            PlantLeaf(
                angle: Double.random(in: -1.2...1.2, using: &rng),
                length: Double.random(in: 0.03...0.07, using: &rng),
                curve: Double.random(in: -0.3...0.3, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng)
            )
        }

        ready = true
    }

    // MARK: - Room walls and ceiling

    private func drawRoom(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = sin(t * 0.06) * 0.005
        // Back wall — warm dark with subtle variation
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.06 + w, green: 0.045, blue: 0.03),
                Color(red: 0.055, green: 0.04 + w, blue: 0.028),
                Color(red: 0.05, green: 0.038, blue: 0.025),
                Color(red: 0.045, green: 0.035, blue: 0.022),
            ]), startPoint: CGPoint(x: size.width * 0.3, y: 0),
                endPoint: CGPoint(x: size.width * 0.7, y: size.height)))

        // Wainscoting line — subtle horizontal division
        let wainY = size.height * 0.62
        var wainLine = Path()
        wainLine.move(to: CGPoint(x: 0, y: wainY))
        wainLine.addLine(to: CGPoint(x: size.width, y: wainY))
        ctx.stroke(wainLine, with: .color(Color(red: 0.08, green: 0.06, blue: 0.04).opacity(0.3)), lineWidth: 1.5)

        // Lower wall slightly different tone
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: wainY, width: size.width, height: size.height * 0.18)),
            with: .color(Color(red: 0.04, green: 0.032, blue: 0.02).opacity(0.4)))
    }

    // MARK: - The salt lamp's ambient glow filling the room

    private func drawLampGlow(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // The lamp sits on the side table at right of frame
        // Its glow radiates from there and fills the room
        let lampX = size.width * 0.78
        let lampY = size.height * 0.58

        let breathe = sin(t * 0.18) * 0.06 + 0.94

        // Large room-filling warm glow
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: max(size.width, size.height) * 0.2))
            let r = max(size.width, size.height) * 0.7
            l.fill(Ellipse().path(in: CGRect(x: lampX - r, y: lampY - r * 0.8,
                                              width: r * 2, height: r * 1.6)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.2, green: 0.55, blue: 0.18).opacity(0.14 * breathe),
                        Color(red: 0.9, green: 0.4, blue: 0.12).opacity(0.07 * breathe),
                        Color(red: 0.5, green: 0.2, blue: 0.08).opacity(0.03 * breathe),
                        Color.clear,
                    ]),
                    center: CGPoint(x: lampX, y: lampY),
                    startRadius: 0,
                    endRadius: r
                ))
        }

        // Tighter warm core near the lamp itself
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 40))
            let cr = size.height * 0.18
            l.fill(Ellipse().path(in: CGRect(x: lampX - cr, y: lampY - cr,
                                              width: cr * 2, height: cr * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.4, green: 0.6, blue: 0.2).opacity(0.18 * breathe),
                        Color(red: 1.0, green: 0.4, blue: 0.12).opacity(0.06 * breathe),
                        Color.clear,
                    ]),
                    center: CGPoint(x: lampX, y: lampY),
                    startRadius: 0,
                    endRadius: cr
                ))
        }

        // Subtle warm light on the ceiling
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 60))
            let ceilX = lampX - size.width * 0.05
            let ceilR = size.width * 0.25
            l.fill(Ellipse().path(in: CGRect(x: ceilX - ceilR, y: -ceilR * 0.3,
                                              width: ceilR * 2, height: ceilR)),
                with: .color(Color(red: 0.8, green: 0.35, blue: 0.12).opacity(0.04 * breathe)))
        }
    }

    // MARK: - Floor

    private func drawFloor(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let floorY = size.height * 0.80
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.055, green: 0.04, blue: 0.025),
                Color(red: 0.045, green: 0.033, blue: 0.02),
                Color(red: 0.035, green: 0.025, blue: 0.015),
            ]), startPoint: CGPoint(x: 0, y: floorY),
                endPoint: CGPoint(x: 0, y: size.height)))

        // Floorboard lines
        for i in 0..<4 {
            let y = floorY + Double(i + 1) * (size.height - floorY) / 5.0
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(line, with: .color(Color(red: 0.07, green: 0.05, blue: 0.03).opacity(0.2)), lineWidth: 0.5)
        }

        // Warm light pool on floor from lamp
        let breathe = sin(t * 0.18) * 0.04 + 0.96
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 50))
            let poolX = size.width * 0.72
            let poolW = size.width * 0.25
            let poolH = (size.height - floorY) * 1.2
            l.fill(Ellipse().path(in: CGRect(x: poolX - poolW / 2, y: floorY - poolH * 0.1,
                                              width: poolW, height: poolH)),
                with: .color(Color(red: 0.8, green: 0.35, blue: 0.1).opacity(0.06 * breathe)))
        }
    }

    // MARK: - Rug

    private func drawRug(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let rugX = size.width * 0.22
        let rugY = size.height * 0.82
        let rugW = size.width * 0.40
        let rugH = size.height * 0.12

        // Main rug shape — faded Persian/Oriental
        let rugRect = CGRect(x: rugX, y: rugY, width: rugW, height: rugH)
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in: rugRect),
            with: .color(Color(red: 0.10, green: 0.05, blue: 0.04).opacity(0.5)))

        // Border
        let borderInset = 4.0
        let innerRect = CGRect(x: rugX + borderInset, y: rugY + borderInset,
                                width: rugW - borderInset * 2, height: rugH - borderInset * 2)
        ctx.stroke(RoundedRectangle(cornerRadius: 2).path(in: innerRect),
            with: .color(Color(red: 0.18, green: 0.08, blue: 0.05).opacity(0.25)), lineWidth: 1)

        // Inner border
        let inner2 = CGRect(x: rugX + borderInset * 2.5, y: rugY + borderInset * 2.5,
                             width: rugW - borderInset * 5, height: rugH - borderInset * 5)
        ctx.stroke(RoundedRectangle(cornerRadius: 1).path(in: inner2),
            with: .color(Color(red: 0.15, green: 0.06, blue: 0.04).opacity(0.18)), lineWidth: 0.5)

        // Central medallion suggestion
        let medX = rugX + rugW * 0.5
        let medY = rugY + rugH * 0.5
        let medR = min(rugW, rugH) * 0.2
        ctx.fill(Ellipse().path(in: CGRect(x: medX - medR, y: medY - medR * 0.6,
                                            width: medR * 2, height: medR * 1.2)),
            with: .color(Color(red: 0.14, green: 0.06, blue: 0.04).opacity(0.2)))
    }

    // MARK: - Bookshelf (left side)

    private func drawBookshelf(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let shelfX = size.width * 0.04
        let shelfW = size.width * 0.24
        let shelfTopY = size.height * 0.15
        let shelfBotY = size.height * 0.78
        let breathe = sin(t * 0.18) * 0.04 + 0.96

        // Shelf frame — dark wood
        let frameColor = Color(red: 0.06, green: 0.04, blue: 0.025)
        ctx.fill(Rectangle().path(in: CGRect(x: shelfX, y: shelfTopY, width: shelfW, height: shelfBotY - shelfTopY)),
            with: .color(frameColor.opacity(0.6)))

        // Three shelf levels
        let shelfCount = 3
        let shelfH = (shelfBotY - shelfTopY) / Double(shelfCount)

        for s in 0..<shelfCount {
            let sy = shelfTopY + Double(s) * shelfH
            let shelfLineY = sy + shelfH - 2

            // Shelf plank
            ctx.fill(Rectangle().path(in: CGRect(x: shelfX, y: shelfLineY, width: shelfW, height: 3)),
                with: .color(Color(red: 0.08, green: 0.055, blue: 0.035).opacity(0.7)))

            // Books on this shelf
            let bookSpaceY = sy + 4
            let bookSpaceH = shelfH - 8

            for book in books {
                let bx = shelfX + 3 + book.x * (shelfW - 6)
                guard bx + book.width * shelfW < shelfX + shelfW - 2 else { continue }
                let bw = book.width * shelfW
                let bh = bookSpaceH * book.height
                let by = bookSpaceY + bookSpaceH - bh

                ctx.fill(Rectangle().path(in: CGRect(x: bx, y: by, width: bw, height: bh)),
                    with: .color(Color(hue: book.hue, saturation: book.saturation,
                                       brightness: book.brightness * breathe).opacity(0.7)))

                // Spine highlight
                ctx.fill(Rectangle().path(in: CGRect(x: bx, y: by, width: 1, height: bh)),
                    with: .color(Color(red: 0.9, green: 0.5, blue: 0.2).opacity(0.04 * breathe)))
            }
        }

        // Warm light hitting the shelf face
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 30))
            l.fill(Rectangle().path(in: CGRect(x: shelfX + shelfW * 0.5, y: shelfTopY,
                                                width: shelfW * 0.6, height: shelfBotY - shelfTopY)),
                with: .color(Color(red: 0.7, green: 0.3, blue: 0.1).opacity(0.03 * breathe)))
        }
    }

    // MARK: - Armchair (center-left)

    private func drawArmchair(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width * 0.38
        let botY = size.height * 0.80
        let seatW = size.width * 0.16
        let seatH = size.height * 0.12
        let backH = size.height * 0.16
        let armW = seatW * 0.15

        let chairColor = Color(red: 0.07, green: 0.04, blue: 0.03)

        // Back
        let backRect = CGRect(x: cx - seatW * 0.4, y: botY - seatH - backH,
                               width: seatW * 0.8, height: backH)
        ctx.fill(RoundedRectangle(cornerRadius: 6).path(in: backRect),
            with: .color(chairColor.opacity(0.65)))

        // Seat
        let seatRect = CGRect(x: cx - seatW / 2, y: botY - seatH, width: seatW, height: seatH)
        ctx.fill(RoundedRectangle(cornerRadius: 4).path(in: seatRect),
            with: .color(chairColor.opacity(0.7)))

        // Arms
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in:
            CGRect(x: cx - seatW / 2 - armW, y: botY - seatH - backH * 0.3,
                   width: armW, height: seatH + backH * 0.3)),
            with: .color(chairColor.opacity(0.6)))
        ctx.fill(RoundedRectangle(cornerRadius: 3).path(in:
            CGRect(x: cx + seatW / 2, y: botY - seatH - backH * 0.3,
                   width: armW, height: seatH + backH * 0.3)),
            with: .color(chairColor.opacity(0.6)))

        // Cushion highlight from lamp glow
        let breathe = sin(t * 0.18) * 0.04 + 0.96
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 10))
            l.fill(RoundedRectangle(cornerRadius: 4).path(in:
                CGRect(x: cx - seatW * 0.1, y: botY - seatH + 2, width: seatW * 0.4, height: seatH * 0.5)),
                with: .color(Color(red: 0.7, green: 0.3, blue: 0.1).opacity(0.04 * breathe)))
        }
    }

    // MARK: - Side table with salt lamp (right side)

    private func drawSideTable(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let tableX = size.width * 0.72
        let tableTopY = size.height * 0.62
        let tableW = size.width * 0.13
        let tableH = size.height * 0.18

        // Table top
        ctx.fill(Rectangle().path(in: CGRect(x: tableX, y: tableTopY, width: tableW, height: 3)),
            with: .color(Color(red: 0.08, green: 0.055, blue: 0.035).opacity(0.7)))

        // Legs
        let legW = 2.5
        ctx.fill(Rectangle().path(in: CGRect(x: tableX + 4, y: tableTopY, width: legW, height: tableH)),
            with: .color(Color(red: 0.06, green: 0.04, blue: 0.025).opacity(0.5)))
        ctx.fill(Rectangle().path(in: CGRect(x: tableX + tableW - 6, y: tableTopY, width: legW, height: tableH)),
            with: .color(Color(red: 0.06, green: 0.04, blue: 0.025).opacity(0.5)))

        // Salt lamp on table — small glowing form
        let lampCx = tableX + tableW * 0.45
        let lampBotY = tableTopY - 1
        let lampW = tableW * 0.35
        let lampH = size.height * 0.06

        let breathe = sin(t * 0.18) * 0.08 + 0.92

        // Lamp body — small organic crystalline shape
        var lampShape = Path()
        lampShape.move(to: CGPoint(x: lampCx, y: lampBotY - lampH))
        lampShape.addCurve(
            to: CGPoint(x: lampCx + lampW * 0.45, y: lampBotY - lampH * 0.35),
            control1: CGPoint(x: lampCx + lampW * 0.25, y: lampBotY - lampH * 0.9),
            control2: CGPoint(x: lampCx + lampW * 0.5, y: lampBotY - lampH * 0.6))
        lampShape.addCurve(
            to: CGPoint(x: lampCx + lampW * 0.3, y: lampBotY),
            control1: CGPoint(x: lampCx + lampW * 0.42, y: lampBotY - lampH * 0.15),
            control2: CGPoint(x: lampCx + lampW * 0.35, y: lampBotY))
        lampShape.addLine(to: CGPoint(x: lampCx - lampW * 0.3, y: lampBotY))
        lampShape.addCurve(
            to: CGPoint(x: lampCx - lampW * 0.45, y: lampBotY - lampH * 0.35),
            control1: CGPoint(x: lampCx - lampW * 0.35, y: lampBotY),
            control2: CGPoint(x: lampCx - lampW * 0.42, y: lampBotY - lampH * 0.15))
        lampShape.addCurve(
            to: CGPoint(x: lampCx, y: lampBotY - lampH),
            control1: CGPoint(x: lampCx - lampW * 0.5, y: lampBotY - lampH * 0.6),
            control2: CGPoint(x: lampCx - lampW * 0.25, y: lampBotY - lampH * 0.9))
        lampShape.closeSubpath()

        // Lamp inner glow
        ctx.drawLayer { l in
            l.clip(to: lampShape)
            let gradRect = CGRect(x: lampCx - lampW, y: lampBotY - lampH,
                                   width: lampW * 2, height: lampH)
            l.fill(Rectangle().path(in: gradRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.5, green: 0.8, blue: 0.3).opacity(0.85 * breathe),
                        Color(red: 1.3, green: 0.6, blue: 0.2).opacity(0.9 * breathe),
                        Color(red: 1.1, green: 0.4, blue: 0.12).opacity(0.95 * breathe),
                    ]),
                    startPoint: CGPoint(x: lampCx, y: lampBotY - lampH),
                    endPoint: CGPoint(x: lampCx, y: lampBotY)
                ))
        }

        // Small bright bloom around the lamp
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 12))
            let bloomR = lampH * 0.8
            l.fill(Ellipse().path(in: CGRect(x: lampCx - bloomR, y: lampBotY - lampH * 0.6 - bloomR * 0.5,
                                              width: bloomR * 2, height: bloomR)),
                with: .color(Color(red: 1.5, green: 0.7, blue: 0.25).opacity(0.2 * breathe)))
        }

        // Mug next to lamp
        let mugX = lampCx + lampW * 0.8
        let mugW = tableW * 0.14
        let mugH = size.height * 0.025
        ctx.fill(RoundedRectangle(cornerRadius: 2).path(in:
            CGRect(x: mugX, y: lampBotY - mugH, width: mugW, height: mugH)),
            with: .color(Color(red: 0.08, green: 0.06, blue: 0.04).opacity(0.5)))

        // Tiny steam wisps from mug
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 4))
            for i in 0..<2 {
                let steamPhase = fmod(t * 0.3 + Double(i) * 1.5, 3.0)
                let rise = steamPhase / 3.0
                let fade = max(0, 1.0 - rise)
                let sx = mugX + mugW * 0.5 + sin(t * 0.5 + Double(i) * 2) * 3
                let sy = lampBotY - mugH - rise * size.height * 0.03
                let s = 3.0 + rise * 4
                l.fill(Ellipse().path(in: CGRect(x: sx - s / 2, y: sy - s / 2, width: s, height: s)),
                    with: .color(Color(red: 0.5, green: 0.4, blue: 0.3).opacity(0.06 * fade)))
            }
        }
    }

    // MARK: - Plant in the corner

    private func drawPlant(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let potX = size.width * 0.88
        let potY = size.height * 0.78
        let potW = size.width * 0.06
        let potH = size.height * 0.05

        // Pot
        var pot = Path()
        pot.move(to: CGPoint(x: potX - potW * 0.4, y: potY - potH))
        pot.addLine(to: CGPoint(x: potX + potW * 0.4, y: potY - potH))
        pot.addLine(to: CGPoint(x: potX + potW * 0.3, y: potY))
        pot.addLine(to: CGPoint(x: potX - potW * 0.3, y: potY))
        pot.closeSubpath()
        ctx.fill(pot, with: .color(Color(red: 0.10, green: 0.06, blue: 0.04).opacity(0.6)))

        // Leaves
        for leaf in plantLeaves {
            let sway = sin(t * 0.15 + leaf.phase) * 0.03
            let angle = leaf.angle + sway
            let len = leaf.length * size.height
            let endX = potX + cos(angle) * len
            let endY = potY - potH - sin(max(0.3, abs(angle))) * len

            var stem = Path()
            stem.move(to: CGPoint(x: potX, y: potY - potH))
            stem.addQuadCurve(
                to: CGPoint(x: endX, y: endY),
                control: CGPoint(x: potX + cos(angle) * len * 0.4 + leaf.curve * 15,
                                 y: potY - potH - len * 0.6))
            ctx.stroke(stem, with: .color(
                Color(hue: 0.33, saturation: 0.45, brightness: 0.15).opacity(0.5)),
                lineWidth: 1.5)
        }
    }

    // MARK: - Mirror on the far wall showing lamp reflection

    private func drawMirror(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let mirrorCx = size.width * 0.52
        let mirrorCy = size.height * 0.34
        let mirrorR = min(size.width, size.height) * 0.09

        // Mirror frame — dark wood circle
        let frameR = mirrorR + 4
        ctx.fill(Ellipse().path(in: CGRect(x: mirrorCx - frameR, y: mirrorCy - frameR,
                                            width: frameR * 2, height: frameR * 2)),
            with: .color(Color(red: 0.08, green: 0.05, blue: 0.03).opacity(0.7)))

        // Mirror surface — slightly reflective dark
        ctx.fill(Ellipse().path(in: CGRect(x: mirrorCx - mirrorR, y: mirrorCy - mirrorR,
                                            width: mirrorR * 2, height: mirrorR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.06, green: 0.05, blue: 0.04),
                    Color(red: 0.04, green: 0.035, blue: 0.025),
                ]),
                center: CGPoint(x: mirrorCx - mirrorR * 0.2, y: mirrorCy - mirrorR * 0.2),
                startRadius: 0,
                endRadius: mirrorR
            ))

        // Salt lamp reflection in mirror — small warm glow
        let breathe = sin(t * 0.18) * 0.08 + 0.92
        let reflX = mirrorCx + mirrorR * 0.25
        let reflY = mirrorCy + mirrorR * 0.15
        let reflR = mirrorR * 0.25

        ctx.drawLayer { l in
            // Clip to mirror circle
            l.clip(to: Ellipse().path(in: CGRect(x: mirrorCx - mirrorR, y: mirrorCy - mirrorR,
                                                  width: mirrorR * 2, height: mirrorR * 2)))
            // Warm glow of the lamp reflection
            l.drawLayer { gl in
                gl.addFilter(.blur(radius: 8))
                gl.fill(Ellipse().path(in: CGRect(x: reflX - reflR * 2, y: reflY - reflR * 2,
                                                   width: reflR * 4, height: reflR * 4)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 1.3, green: 0.6, blue: 0.2).opacity(0.3 * breathe),
                            Color(red: 0.8, green: 0.35, blue: 0.1).opacity(0.1 * breathe),
                            Color.clear,
                        ]),
                        center: CGPoint(x: reflX, y: reflY),
                        startRadius: 0,
                        endRadius: reflR * 2
                    ))
            }

            // Tiny bright lamp core in reflection
            l.drawLayer { cl in
                cl.addFilter(.blur(radius: 3))
                cl.fill(Ellipse().path(in: CGRect(x: reflX - reflR * 0.3, y: reflY - reflR * 0.4,
                                                   width: reflR * 0.6, height: reflR * 0.6)),
                    with: .color(Color(red: 1.5, green: 0.8, blue: 0.3).opacity(0.4 * breathe)))
            }
        }

        // Specular highlight on mirror glass
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 4))
            let hlX = mirrorCx - mirrorR * 0.3
            let hlY = mirrorCy - mirrorR * 0.3
            l.fill(Ellipse().path(in: CGRect(x: hlX - 4, y: hlY - 6, width: 8, height: 12)),
                with: .color(Color(red: 0.3, green: 0.25, blue: 0.2).opacity(0.08)))
        }
    }

    // MARK: - Curtains (far right edge)

    private func drawCurtains(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let curtainX = size.width * 0.92
        let curtainTopY = size.height * 0.08
        let curtainBotY = size.height * 0.75
        let curtainW = size.width * 0.08
        let sway = sin(t * 0.08) * 3

        // Heavy drape
        var drape = Path()
        drape.move(to: CGPoint(x: curtainX, y: curtainTopY))
        drape.addLine(to: CGPoint(x: size.width, y: curtainTopY))
        drape.addLine(to: CGPoint(x: size.width, y: curtainBotY))
        drape.addLine(to: CGPoint(x: curtainX + sway, y: curtainBotY))
        drape.closeSubpath()
        ctx.fill(drape, with: .color(Color(red: 0.06, green: 0.035, blue: 0.025).opacity(0.6)))

        // Fold lines
        for i in 1...3 {
            let fx = curtainX + Double(i) * curtainW / 4.0 + sway * Double(i) / 4.0
            var fold = Path()
            fold.move(to: CGPoint(x: fx, y: curtainTopY + 10))
            fold.addLine(to: CGPoint(x: fx + sin(t * 0.06) * 1, y: curtainBotY - 10))
            ctx.stroke(fold, with: .color(Color(red: 0.04, green: 0.025, blue: 0.015).opacity(0.25)), lineWidth: 0.5)
        }

        // Warm light catching curtain edge
        let breathe = sin(t * 0.18) * 0.04 + 0.96
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 15))
            l.fill(Rectangle().path(in: CGRect(x: curtainX - 5, y: curtainTopY,
                                                width: 10, height: curtainBotY - curtainTopY)),
                with: .color(Color(red: 0.7, green: 0.3, blue: 0.1).opacity(0.04 * breathe)))
        }
    }

    // MARK: - Dust motes in the warm light

    private func drawDust(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let lampX = size.width * 0.78
        let lampY = size.height * 0.58

        for mote in dustMotes {
            let x = fmod(mote.x + sin(t * 0.08 + mote.phase) * 0.02 + t * mote.speed * 0.1 + 10, 1.0) * size.width
            let y = fmod(mote.y + cos(t * 0.05 + mote.phase) * 0.015 - t * mote.speed * 0.05 + 10, 1.0) * size.height

            // Brighter when near the lamp
            let dist = hypot(x - lampX, y - lampY) / max(size.width, size.height)
            let proximity = max(0, 1.0 - dist * 2.5)
            let twinkle = sin(t * 0.6 + mote.phase) * 0.3 + 0.7
            let alpha = mote.brightness * twinkle * (0.3 + proximity * 0.7)

            let s = mote.size
            let rect = CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)
            ctx.fill(Ellipse().path(in: rect),
                with: .color(Color(red: 1.0, green: 0.7, blue: 0.4).opacity(alpha)))
        }
    }

    // MARK: - Warmth pulse on tap

    private func drawWarmthPulse(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let lampX = size.width * 0.78
        let lampY = size.height * 0.58

        var totalIntensity = 0.0
        for pulse in warmthPulses {
            let age = t - pulse.birth
            guard age >= 0 && age < 5.0 else { continue }
            let envelope: Double
            if age < 0.3 {
                envelope = age / 0.3
            } else {
                envelope = max(0, 1.0 - (age - 0.3) / 4.7)
            }
            totalIntensity += envelope
        }

        // Ambient warmth bloom (enhanced)
        if totalIntensity > 0 {
            let intensity = min(totalIntensity, 1.2)
            let r = max(size.width, size.height) * 0.7
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: r * 0.4))
                l.fill(Ellipse().path(in: CGRect(x: lampX - r, y: lampY - r * 0.8,
                                                  width: r * 2, height: r * 1.6)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 1.4, green: 0.6, blue: 0.2).opacity(0.12 * intensity),
                            Color(red: 0.9, green: 0.35, blue: 0.12).opacity(0.05 * intensity),
                            Color.clear,
                        ]),
                        center: CGPoint(x: lampX, y: lampY),
                        startRadius: 0,
                        endRadius: r
                    ))
            }

            // Mirror reflection brightens
            let mirrorX = size.width * 0.30
            let mirrorY = size.height * 0.38
            let mirrorR = min(size.width, size.height) * 0.09
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 15))
                l.fill(Ellipse().path(in: CGRect(x: mirrorX - mirrorR * 0.6,
                                                  y: mirrorY - mirrorR * 0.6,
                                                  width: mirrorR * 1.2, height: mirrorR * 1.2)),
                    with: .color(Color(red: 1.3, green: 0.6, blue: 0.2).opacity(0.08 * intensity)))
            }
        }

        // Floating ember motes rising from lamp
        for pulse in warmthPulses {
            let age = t - pulse.birth
            guard age >= 0 && age < 5.0 else { continue }
            var rng = SplitMix64(seed: pulse.seed)

            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 4))
                for _ in 0..<14 {
                    let angle = nextDouble(&rng) * .pi - .pi / 2  // mostly upward
                    let drift = nextDouble(&rng) * 0.5 + 0.3
                    let riseRate = nextDouble(&rng) * 20 + 12
                    let wobblePhase = nextDouble(&rng) * .pi * 2
                    let wobbleAmp = nextDouble(&rng) * 20 + 10
                    let sz = nextDouble(&rng) * 2.0 + 1.5
                    let lifespan = nextDouble(&rng) * 2.0 + 2.5
                    guard age < lifespan else { continue }
                    let mp = age / lifespan
                    let moteFade = mp < 0.1 ? mp / 0.1 : max(0, 1.0 - (mp - 0.1) / 0.9)
                    let spread = mp * drift * 80
                    let mx = lampX + cos(angle) * spread + sin(age * 0.7 + wobblePhase) * wobbleAmp
                    let my = lampY - age * riseRate + sin(age * 1.1 + wobblePhase) * 5
                    let pulse = sin(age * 2.5 + wobblePhase) * 0.3 + 0.7
                    let s = sz * moteFade * pulse
                    let warmth = nextDouble(&rng)
                    let color = warmth > 0.5
                        ? Color(red: 1.4, green: 0.7, blue: 0.25)
                        : Color(red: 1.2, green: 0.55, blue: 0.2)
                    l.fill(Ellipse().path(in: CGRect(x: mx - s, y: my - s, width: s * 2, height: s * 2)),
                        with: .color(color.opacity(moteFade * 0.45 * pulse)))
                }
            }
        }
    }
}
