// CelestialScrollHall3DScene — Moonlit Chinese study hall with scrolls and incense.
// Lacquered columns, hanging scrolls, lattice window, silk lanterns, calligraphy desk,
// plum blossom petals, incense smoke, floating glowing characters.
// Tap to release burst of glowing glyph characters.

import SwiftUI
import SceneKit

struct CelestialScrollHall3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        CelestialScrollHall3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct CelestialScrollHall3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var glyphSystem: SCNParticleSystem?
        var petalSystem: SCNParticleSystem?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.02, green: 0.025, blue: 0.04, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = false
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        guard let ps = c.glyphSystem else { return }
        let oldRate = ps.birthRate
        ps.birthRate = 80
        ps.particleVelocity = 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            ps.birthRate = oldRate
            ps.particleVelocity = 0.25
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.02, green: 0.025, blue: 0.04, alpha: 1)
        scene.fogStartDistance = 8
        scene.fogEndDistance = 20
        scene.fogColor = NSColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1)

        addLighting(to: scene)
        addFloor(to: scene)
        addCeiling(to: scene)
        addWalls(to: scene)
        addColumns(to: scene)
        addScrollShelves(to: scene)
        addHangingScrolls(to: scene)
        addLatticeWindow(to: scene)
        addLanterns(to: scene)
        addCalligraphyDesk(to: scene)
        addIncenseSmoke(to: scene)
        addPlumBlossomPetals(to: scene, coord: coord)
        addFloatingGlyphs(to: scene, coord: coord)
        addDustMotes(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Materials

    private func lacquerMaterial(r: CGFloat, g: CGFloat, b: CGFloat, shininess: CGFloat = 60) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(red: r, green: g, blue: b, alpha: 1)
        m.specular.contents = NSColor(red: 0.4, green: 0.25, blue: 0.15, alpha: 1)
        m.shininess = shininess
        return m
    }

    private func woodMaterial(r: CGFloat, g: CGFloat, b: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(red: r, green: g, blue: b, alpha: 1)
        m.roughness.contents = NSColor(white: 0.7, alpha: 1)
        return m
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        // Very dim warm ambient — a room lit mainly by lanterns and moonlight
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 20
        ambient.light!.color = NSColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Moonlight through the window — cool blue directional
        let moon = SCNNode()
        moon.light = SCNLight()
        moon.light!.type = .directional
        moon.light!.intensity = 50
        moon.light!.color = NSColor(red: 0.55, green: 0.6, blue: 0.8, alpha: 1)
        moon.light!.castsShadow = true
        moon.light!.shadowRadius = 4
        moon.light!.shadowSampleCount = 8
        moon.light!.shadowColor = NSColor(red: 0, green: 0, blue: 0.05, alpha: 0.5)
        moon.eulerAngles = SCNVector3(-Float.pi / 5, Float.pi / 6, 0)
        scene.rootNode.addChildNode(moon)

        // Warm candlelight spots near lanterns
        let candlePositions: [(Float, Float, Float)] = [
            (-1.8, 2.3, -1.5), (1.8, 2.3, -1.5),
            (0, 2.5, -3.0), (-1.0, 2.1, -5.0), (1.0, 2.1, -5.0)
        ]
        for (i, (x, y, z)) in candlePositions.enumerated() {
            let candle = SCNNode()
            candle.light = SCNLight()
            candle.light!.type = .omni
            candle.light!.intensity = 60
            candle.light!.color = NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1)
            candle.light!.attenuationStartDistance = 0.5
            candle.light!.attenuationEndDistance = 5.0
            candle.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(candle)

            // Gentle flicker animation
            let period = 2.5 + Double(i) * 0.7
            let dim = SCNAction.customAction(duration: period) { node, elapsed in
                let t = elapsed / CGFloat(period)
                let flicker = 50 + 20 * sin(t * .pi * 6) * sin(t * .pi * 2.3 + 0.5)
                node.light?.intensity = CGFloat(flicker)
            }
            candle.runAction(SCNAction.repeatForever(dim))
        }
    }

    // MARK: - Floor

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.06
        floor.reflectionFalloffEnd = 3.0
        let mat = woodMaterial(r: 0.12, g: 0.07, b: 0.04)
        floor.materials = [mat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))
    }

    // MARK: - Ceiling

    private func addCeiling(to scene: SCNScene) {
        let ceiling = SCNPlane(width: 12, height: 16)
        let mat = woodMaterial(r: 0.08, g: 0.05, b: 0.03)
        mat.isDoubleSided = true
        ceiling.materials = [mat]
        let node = SCNNode(geometry: ceiling)
        node.position = SCNVector3(0, 3.8, -4)
        node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(node)

        // Ceiling beams
        let beamMat = woodMaterial(r: 0.1, g: 0.06, b: 0.035)
        for z in stride(from: Float(0), through: -8, by: -2) {
            let beam = SCNBox(width: 8, height: 0.15, length: 0.2, chamferRadius: 0.02)
            beam.materials = [beamMat]
            let n = SCNNode(geometry: beam)
            n.position = SCNVector3(0, 3.7, z)
            scene.rootNode.addChildNode(n)
        }
    }

    // MARK: - Walls

    private func addWalls(to scene: SCNScene) {
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = NSColor(red: 0.06, green: 0.04, blue: 0.03, alpha: 1)
        wallMat.isDoubleSided = true

        // Back wall
        let backWall = SCNPlane(width: 12, height: 4)
        backWall.materials = [wallMat]
        let backNode = SCNNode(geometry: backWall)
        backNode.position = SCNVector3(0, 2, -9)
        scene.rootNode.addChildNode(backNode)

        // Side walls
        for side: Float in [-1, 1] {
            let sideWall = SCNPlane(width: 18, height: 4)
            sideWall.materials = [wallMat]
            let sideNode = SCNNode(geometry: sideWall)
            sideNode.position = SCNVector3(side * 4.5, 2, -4)
            sideNode.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
            scene.rootNode.addChildNode(sideNode)
        }
    }

    // MARK: - Columns

    private func addColumns(to scene: SCNScene) {
        let colMat = lacquerMaterial(r: 0.4, g: 0.1, b: 0.06, shininess: 80)
        let goldMat = SCNMaterial()
        goldMat.diffuse.contents = NSColor(red: 0.7, green: 0.55, blue: 0.2, alpha: 1)
        goldMat.emission.contents = NSColor(red: 0.15, green: 0.1, blue: 0.02, alpha: 1)

        let positions: [(Float, Float)] = [
            (-3.0, -1.0), (3.0, -1.0),
            (-3.0, -4.0), (3.0, -4.0),
            (-3.0, -7.0), (3.0, -7.0)
        ]
        for (x, z) in positions {
            // Main column body
            let cyl = SCNCylinder(radius: 0.12, height: 3.8)
            cyl.materials = [colMat]
            let node = SCNNode(geometry: cyl)
            node.position = SCNVector3(x, 1.9, z)
            scene.rootNode.addChildNode(node)

            // Gold bands at top and bottom
            for bandY: Float in [0.08, 3.72] {
                let band = SCNCylinder(radius: 0.14, height: 0.06)
                band.materials = [goldMat]
                let bandNode = SCNNode(geometry: band)
                bandNode.position = SCNVector3(x, bandY, z)
                scene.rootNode.addChildNode(bandNode)
            }

            // Column capital (simplified bracket)
            let cap = SCNBox(width: 0.35, height: 0.08, length: 0.35, chamferRadius: 0.02)
            cap.materials = [colMat]
            let capNode = SCNNode(geometry: cap)
            capNode.position = SCNVector3(x, 3.78, z)
            scene.rootNode.addChildNode(capNode)
        }
    }

    // MARK: - Scroll shelves along back wall

    private func addScrollShelves(to scene: SCNScene) {
        var rng = SplitMix64(seed: 8888)
        let shelfMat = woodMaterial(r: 0.1, g: 0.065, b: 0.04)
        let shelfZ: Float = -8.5

        // Two shelf units on either side
        for sideX: Float in [-2.0, 2.0] {
            let unitW: Float = 2.2
            let unitH: Float = 3.0

            // Shelf back panel
            let back = SCNPlane(width: CGFloat(unitW), height: CGFloat(unitH))
            back.materials = [woodMaterial(r: 0.07, g: 0.045, b: 0.025)]
            let backN = SCNNode(geometry: back)
            backN.position = SCNVector3(sideX, 1.6, shelfZ + 0.01)
            scene.rootNode.addChildNode(backN)

            // Shelf planks
            for row in 0..<5 {
                let plankY = Float(row) * 0.6 + 0.3
                let plank = SCNBox(width: CGFloat(unitW), height: 0.04, length: 0.25, chamferRadius: 0)
                plank.materials = [shelfMat]
                let n = SCNNode(geometry: plank)
                n.position = SCNVector3(sideX, plankY, shelfZ + 0.12)
                scene.rootNode.addChildNode(n)

                // Scroll tubes on each shelf
                let scrollCount = 4 + Int(rng.nextDouble() * 4)
                var scrollX = sideX - unitW / 2 + 0.15
                for _ in 0..<scrollCount {
                    let sw: Float = 0.06 + Float(rng.nextDouble()) * 0.05
                    let sh: Float = 0.35 + Float(rng.nextDouble()) * 0.2

                    // Scroll tube colors — bamboo, parchment, crimson, jade
                    let tone = rng.nextDouble()
                    let sr, sg, sb: CGFloat
                    if tone < 0.3 {
                        sr = 0.15; sg = 0.18; sb = 0.1  // bamboo
                    } else if tone < 0.55 {
                        sr = 0.25; sg = 0.2; sb = 0.12  // parchment
                    } else if tone < 0.75 {
                        sr = 0.3; sg = 0.08; sb = 0.06  // crimson
                    } else {
                        sr = 0.1; sg = 0.18; sb = 0.15  // jade
                    }

                    let scrollMat = SCNMaterial()
                    scrollMat.diffuse.contents = NSColor(red: sr, green: sg, blue: sb, alpha: 1)

                    let tube = SCNCylinder(radius: CGFloat(sw / 2), height: CGFloat(sh))
                    tube.materials = [scrollMat]
                    let tubeNode = SCNNode(geometry: tube)
                    tubeNode.position = SCNVector3(scrollX, plankY + 0.04 + sh / 2, shelfZ + 0.12)
                    scene.rootNode.addChildNode(tubeNode)

                    // Small cap on top
                    let capMat = SCNMaterial()
                    capMat.diffuse.contents = NSColor(red: sr + 0.05, green: sg + 0.03, blue: sb + 0.02, alpha: 1)
                    let cap = SCNCylinder(radius: CGFloat(sw / 2 + 0.01), height: 0.02)
                    cap.materials = [capMat]
                    let capN = SCNNode(geometry: cap)
                    capN.position = SCNVector3(scrollX, plankY + 0.04 + sh, shelfZ + 0.12)
                    scene.rootNode.addChildNode(capN)

                    scrollX += sw + 0.04
                    if scrollX > sideX + unitW / 2 - 0.1 { break }
                }
            }
        }
    }

    // MARK: - Hanging scrolls (decorative wall scrolls)

    private func addHangingScrolls(to scene: SCNScene) {
        var rng = SplitMix64(seed: 7777)
        let scrollPositions: [(Float, Float)] = [(-1.0, -8.8), (0, -8.8), (1.0, -8.8)]

        for (x, z) in scrollPositions {
            let scrollW: CGFloat = 0.5
            let scrollH: CGFloat = 1.6

            // Scroll paper — warm ivory with faint glow
            let paper = SCNPlane(width: scrollW, height: scrollH)
            let paperMat = SCNMaterial()
            let ivory: CGFloat = CGFloat(0.88 + rng.nextDouble() * 0.08)
            paperMat.diffuse.contents = NSColor(red: ivory, green: ivory * 0.93, blue: ivory * 0.82, alpha: 1)
            paperMat.emission.contents = NSColor(red: 0.6, green: 0.5, blue: 0.25, alpha: 0.15)
            paperMat.isDoubleSided = true
            paper.materials = [paperMat]
            let paperNode = SCNNode(geometry: paper)
            paperNode.position = SCNVector3(x, 2.4, z)
            scene.rootNode.addChildNode(paperNode)

            // Scroll rod at top
            let rod = SCNCylinder(radius: 0.02, height: CGFloat(scrollW + 0.1))
            let rodMat = woodMaterial(r: 0.12, g: 0.08, b: 0.04)
            rod.materials = [rodMat]
            let rodNode = SCNNode(geometry: rod)
            rodNode.position = SCNVector3(x, 3.22, z)
            rodNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            scene.rootNode.addChildNode(rodNode)

            // Bottom weight rod
            let btmRod = SCNCylinder(radius: 0.015, height: CGFloat(scrollW + 0.06))
            btmRod.materials = [rodMat]
            let btmNode = SCNNode(geometry: btmRod)
            btmNode.position = SCNVector3(x, 1.6, z)
            btmNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            scene.rootNode.addChildNode(btmNode)

            // Gentle sway animation
            let sway = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(0.015), duration: 3.0 + rng.nextDouble() * 2)
            let swayBack = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(-0.015), duration: 3.0 + rng.nextDouble() * 2)
            paperNode.runAction(SCNAction.repeatForever(SCNAction.sequence([sway, swayBack])))
        }
    }

    // MARK: - Lattice window with moonlight

    private func addLatticeWindow(to scene: SCNScene) {
        let winX: Float = -4.3
        let winY: Float = 2.2
        let winZ: Float = -4.0
        let winW: CGFloat = 0.08
        let winH: CGFloat = 2.0
        let winD: CGFloat = 1.5

        let latticeMat = woodMaterial(r: 0.15, g: 0.09, b: 0.05)

        // Window frame
        let frameH = SCNBox(width: winD, height: 0.06, length: winW, chamferRadius: 0)
        frameH.materials = [latticeMat]
        for y: Float in [winY - Float(winH) / 2, winY + Float(winH) / 2] {
            let n = SCNNode(geometry: frameH)
            n.position = SCNVector3(winX, y, winZ)
            n.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
            scene.rootNode.addChildNode(n)
        }
        let frameV = SCNBox(width: winW, height: winH, length: 0.06, chamferRadius: 0)
        frameV.materials = [latticeMat]
        for dz: Float in [-Float(winD) / 2, Float(winD) / 2] {
            let n = SCNNode(geometry: frameV)
            n.position = SCNVector3(winX, winY, winZ + dz)
            scene.rootNode.addChildNode(n)
        }

        // Lattice bars (ice-crack simplified grid)
        let barMat = woodMaterial(r: 0.12, g: 0.07, b: 0.04)
        for col in 1..<4 {
            let bar = SCNBox(width: 0.02, height: winH - 0.1, length: 0.02, chamferRadius: 0)
            bar.materials = [barMat]
            let n = SCNNode(geometry: bar)
            let dz = -Float(winD) / 2 + Float(col) * Float(winD) / 4
            n.position = SCNVector3(winX, winY, winZ + dz)
            scene.rootNode.addChildNode(n)
        }
        for row in 1..<5 {
            let bar = SCNBox(width: 0.02, height: 0.02, length: winD - 0.1, chamferRadius: 0)
            bar.materials = [barMat]
            let n = SCNNode(geometry: bar)
            let dy = -Float(winH) / 2 + Float(row) * Float(winH) / 5
            n.position = SCNVector3(winX, winY + dy, winZ)
            scene.rootNode.addChildNode(n)
        }

        // Moonlit glow plane behind window
        let glowPlane = SCNPlane(width: winD + 0.2, height: winH + 0.2)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = NSColor(red: 0.35, green: 0.4, blue: 0.6, alpha: 0.25)
        glowMat.emission.contents = NSColor(red: 0.2, green: 0.25, blue: 0.45, alpha: 1)
        glowMat.isDoubleSided = true
        glowMat.transparency = 0.4
        glowPlane.materials = [glowMat]
        let glowNode = SCNNode(geometry: glowPlane)
        glowNode.position = SCNVector3(winX - 0.15, winY, winZ)
        glowNode.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        scene.rootNode.addChildNode(glowNode)

        // Moonbeam spotlight casting through window
        let moonbeam = SCNNode()
        moonbeam.light = SCNLight()
        moonbeam.light!.type = .spot
        moonbeam.light!.intensity = 40
        moonbeam.light!.color = NSColor(red: 0.5, green: 0.55, blue: 0.75, alpha: 1)
        moonbeam.light!.spotInnerAngle = 20
        moonbeam.light!.spotOuterAngle = 45
        moonbeam.light!.castsShadow = true
        moonbeam.light!.shadowRadius = 3
        moonbeam.position = SCNVector3(winX + 0.5, winY + 0.5, winZ)
        moonbeam.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi / 3, 0)
        scene.rootNode.addChildNode(moonbeam)
    }

    // MARK: - Silk lanterns

    private func addLanterns(to scene: SCNScene) {
        var rng = SplitMix64(seed: 5555)
        let lanternPositions: [(Float, Float, Float)] = [
            (-1.8, 3.0, -1.5), (1.8, 3.0, -1.5),
            (0, 3.2, -3.0), (-1.5, 2.9, -5.0), (1.5, 2.9, -5.0),
            (-0.5, 3.1, -6.5), (0.5, 3.1, -6.5)
        ]

        for (i, (x, y, z)) in lanternPositions.enumerated() {
            let parent = SCNNode()
            parent.position = SCNVector3(x, y, z)

            // Silk body — ellipsoid with warm glow
            let body = SCNSphere(radius: 0.18)
            body.segmentCount = 16
            let bodyMat = SCNMaterial()
            bodyMat.diffuse.contents = NSColor(red: 0.85, green: 0.45, blue: 0.12, alpha: 0.85)
            bodyMat.emission.contents = NSColor(red: 0.9, green: 0.55, blue: 0.15, alpha: 0.6)
            bodyMat.transparency = 0.7
            body.materials = [bodyMat]
            let bodyNode = SCNNode(geometry: body)
            bodyNode.scale = SCNVector3(1, 1.4, 1) // Elongate into lantern shape
            parent.addChildNode(bodyNode)

            // Top cap and bottom cap (small dark rings)
            let capMat = woodMaterial(r: 0.15, g: 0.08, b: 0.04)
            for capY: Float in [0.22, -0.22] {
                let cap = SCNCylinder(radius: 0.06, height: 0.03)
                cap.materials = [capMat]
                let capN = SCNNode(geometry: cap)
                capN.position = SCNVector3(0, capY, 0)
                parent.addChildNode(capN)
            }

            // Hanging cord
            let cord = SCNCylinder(radius: 0.005, height: CGFloat(3.8 - y + 0.2))
            let cordMat = SCNMaterial()
            cordMat.diffuse.contents = NSColor(red: 0.3, green: 0.15, blue: 0.05, alpha: 1)
            cord.materials = [cordMat]
            let cordNode = SCNNode(geometry: cord)
            cordNode.position = SCNVector3(0, Float(cord.height / 2) + 0.22, 0)
            parent.addChildNode(cordNode)

            // Tassel beneath
            let tassel = SCNCone(topRadius: 0.01, bottomRadius: 0.04, height: 0.1)
            let tasselMat = SCNMaterial()
            tasselMat.diffuse.contents = NSColor(red: 0.7, green: 0.35, blue: 0.1, alpha: 1)
            tassel.materials = [tasselMat]
            let tasselNode = SCNNode(geometry: tassel)
            tasselNode.position = SCNVector3(0, -0.27, 0)
            parent.addChildNode(tasselNode)

            // Point light inside lantern
            let glow = SCNNode()
            glow.light = SCNLight()
            glow.light!.type = .omni
            glow.light!.intensity = 40
            glow.light!.color = NSColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 1)
            glow.light!.attenuationStartDistance = 0.1
            glow.light!.attenuationEndDistance = 3.0
            parent.addChildNode(glow)

            // Gentle sway animation
            let swayAmt = CGFloat(0.03 + rng.nextDouble() * 0.02)
            let swayDur = 3.5 + rng.nextDouble() * 2.0
            let swayLeft = SCNAction.rotateBy(x: 0, y: 0, z: swayAmt, duration: swayDur / 2)
            swayLeft.timingMode = .easeInEaseOut
            let swayRight = SCNAction.rotateBy(x: 0, y: 0, z: -swayAmt, duration: swayDur / 2)
            swayRight.timingMode = .easeInEaseOut
            parent.runAction(SCNAction.repeatForever(SCNAction.sequence([swayLeft, swayRight])))

            scene.rootNode.addChildNode(parent)
        }
    }

    // MARK: - Calligraphy desk

    private func addCalligraphyDesk(to scene: SCNScene) {
        let deskMat = lacquerMaterial(r: 0.12, g: 0.07, b: 0.04, shininess: 40)
        let deskY: Float = 0.7
        let deskW: Float = 1.6
        let deskD: Float = 0.7
        let deskZ: Float = -1.5

        // Desk surface
        let top = SCNBox(width: CGFloat(deskW), height: 0.04, length: CGFloat(deskD), chamferRadius: 0.01)
        top.materials = [deskMat]
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, deskY, deskZ)
        scene.rootNode.addChildNode(topNode)

        // Desk legs — elegantly tapered
        let legMat = woodMaterial(r: 0.1, g: 0.06, b: 0.035)
        for (lx, lz) in [(-0.65, deskZ - 0.25), (0.65, deskZ - 0.25), (-0.65, deskZ + 0.25), (0.65, deskZ + 0.25)] as [(Float, Float)] {
            let leg = SCNBox(width: 0.05, height: CGFloat(deskY), length: 0.05, chamferRadius: 0.01)
            leg.materials = [legMat]
            let legN = SCNNode(geometry: leg)
            legN.position = SCNVector3(lx, deskY / 2, lz)
            scene.rootNode.addChildNode(legN)
        }

        // Open scroll on desk
        let scrollPaper = SCNPlane(width: 0.6, height: 0.35)
        let scrollMat = SCNMaterial()
        scrollMat.diffuse.contents = NSColor(red: 0.75, green: 0.68, blue: 0.52, alpha: 1)
        scrollMat.emission.contents = NSColor(red: 0.15, green: 0.12, blue: 0.06, alpha: 1)
        scrollMat.isDoubleSided = true
        scrollPaper.materials = [scrollMat]
        let scrollNode = SCNNode(geometry: scrollPaper)
        scrollNode.position = SCNVector3(-0.1, deskY + 0.025, deskZ)
        scrollNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(scrollNode)

        // Scroll end rollers
        let rollerMat = woodMaterial(r: 0.1, g: 0.065, b: 0.04)
        for rx: Float in [-0.4, 0.2] {
            let roller = SCNCylinder(radius: 0.015, height: 0.38)
            roller.materials = [rollerMat]
            let rn = SCNNode(geometry: roller)
            rn.position = SCNVector3(rx, deskY + 0.035, deskZ)
            rn.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            scene.rootNode.addChildNode(rn)
        }

        // Ink stone
        let inkStone = SCNBox(width: 0.1, height: 0.03, length: 0.08, chamferRadius: 0.01)
        let inkMat = SCNMaterial()
        inkMat.diffuse.contents = NSColor(red: 0.04, green: 0.035, blue: 0.03, alpha: 1)
        inkStone.materials = [inkMat]
        let inkNode = SCNNode(geometry: inkStone)
        inkNode.position = SCNVector3(0.45, deskY + 0.04, deskZ - 0.1)
        scene.rootNode.addChildNode(inkNode)

        // Brush resting on a brush holder
        let brush = SCNCylinder(radius: 0.008, height: 0.2)
        let brushMat = woodMaterial(r: 0.25, g: 0.15, b: 0.08)
        brush.materials = [brushMat]
        let brushNode = SCNNode(geometry: brush)
        brushNode.position = SCNVector3(0.5, deskY + 0.06, deskZ + 0.1)
        brushNode.eulerAngles = SCNVector3(0, 0, Float.pi / 6)
        scene.rootNode.addChildNode(brushNode)

        // Small incense holder on desk
        let holder = SCNCylinder(radius: 0.04, height: 0.03)
        let holderMat = SCNMaterial()
        holderMat.diffuse.contents = NSColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1)
        holder.materials = [holderMat]
        let holderNode = SCNNode(geometry: holder)
        holderNode.position = SCNVector3(-0.55, deskY + 0.035, deskZ)
        scene.rootNode.addChildNode(holderNode)

        // Incense stick
        let stick = SCNCylinder(radius: 0.003, height: 0.2)
        let stickMat = SCNMaterial()
        stickMat.diffuse.contents = NSColor(red: 0.35, green: 0.2, blue: 0.1, alpha: 1)
        stick.materials = [stickMat]
        let stickNode = SCNNode(geometry: stick)
        stickNode.position = SCNVector3(-0.55, deskY + 0.14, deskZ)
        scene.rootNode.addChildNode(stickNode)

        // Glowing tip
        let tipGlow = SCNSphere(radius: 0.008)
        let tipMat = SCNMaterial()
        tipMat.diffuse.contents = NSColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1)
        tipMat.emission.contents = NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1)
        tipGlow.materials = [tipMat]
        let tipNode = SCNNode(geometry: tipGlow)
        tipNode.position = SCNVector3(-0.55, deskY + 0.24, deskZ)
        scene.rootNode.addChildNode(tipNode)

        // Tip glow pulsing
        let pulse = SCNAction.sequence([
            SCNAction.fadeOpacity(to: 0.6, duration: 1.5),
            SCNAction.fadeOpacity(to: 1.0, duration: 1.5)
        ])
        tipNode.runAction(SCNAction.repeatForever(pulse))
    }

    // MARK: - Incense smoke

    private func addIncenseSmoke(to scene: SCNScene) {
        let ps = SCNParticleSystem()
        ps.birthRate = 6
        ps.particleLifeSpan = 6.0
        ps.particleLifeSpanVariation = 2.0
        ps.emitterShape = SCNSphere(radius: 0.01)
        ps.particleSize = 0.03
        ps.particleSizeVariation = 0.01
        ps.particleColor = NSColor(red: 0.7, green: 0.65, blue: 0.6, alpha: 0.3)
        ps.particleColorVariation = SCNVector4(0.05, 0.05, 0.05, 0.1)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.12
        ps.particleVelocityVariation = 0.04
        ps.spreadingAngle = 15
        ps.particleAngularVelocity = 0.3
        ps.particleAngularVelocityVariation = 0.2
        ps.blendMode = .additive
        let deskY: Float = 0.7
        let smokeNode = SCNNode()
        smokeNode.position = SCNVector3(-0.55, deskY + 0.25, -1.5)
        scene.rootNode.addChildNode(smokeNode)
        smokeNode.addParticleSystem(ps)
    }

    // MARK: - Plum blossom petals

    private func addPlumBlossomPetals(to scene: SCNScene, coord: Coordinator) {
        let ps = SCNParticleSystem()
        ps.birthRate = 1.5
        ps.particleLifeSpan = 12.0
        ps.particleLifeSpanVariation = 4.0
        ps.emitterShape = SCNBox(width: 6, height: 0.5, length: 8, chamferRadius: 0)
        ps.particleSize = 0.025
        ps.particleSizeVariation = 0.01
        ps.particleColor = NSColor(red: 0.85, green: 0.55, blue: 0.65, alpha: 0.7)
        ps.particleColorVariation = SCNVector4(0.1, 0.15, 0.1, 0.2)
        ps.isAffectedByGravity = true
        ps.acceleration = SCNVector3(0.02, -0.03, 0)  // Very gentle drift and fall
        ps.particleVelocity = 0.05
        ps.particleVelocityVariation = 0.03
        ps.spreadingAngle = 180
        ps.particleAngularVelocity = 1.5
        ps.particleAngularVelocityVariation = 1.0
        let petalNode = SCNNode()
        petalNode.position = SCNVector3(0, 3.5, -4)
        scene.rootNode.addChildNode(petalNode)
        petalNode.addParticleSystem(ps)
        coord.petalSystem = ps
    }

    // MARK: - Floating glyphs (glowing Chinese characters)

    private func addFloatingGlyphs(to scene: SCNScene, coord: Coordinator) {
        var rng = SplitMix64(seed: 9999)

        // Particle system for ambient golden motes
        let ps = SCNParticleSystem()
        ps.birthRate = 4
        ps.particleLifeSpan = 8.0
        ps.particleLifeSpanVariation = 3.0
        ps.emitterShape = SCNBox(width: 5, height: 1, length: 6, chamferRadius: 0)
        ps.particleSize = 0.015
        ps.particleSizeVariation = 0.008
        ps.particleColor = NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.8)
        ps.particleColorVariation = SCNVector4(0, 0.1, 0.2, 0.2)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.25
        ps.particleVelocityVariation = 0.1
        ps.spreadingAngle = 25
        ps.blendMode = .additive
        let psNode = SCNNode()
        psNode.position = SCNVector3(0, 1.2, -4)
        scene.rootNode.addChildNode(psNode)
        psNode.addParticleSystem(ps)
        coord.glyphSystem = ps

        // Individual billboard glyph planes (larger, with actual character feel)
        let hanzi = ["愛", "善", "勇", "仁", "和", "福", "夢", "光", "星", "花", "春", "心", "美", "安", "暖", "月"]

        for i in 0..<16 {
            let plane = SCNPlane(width: 0.14, height: 0.14)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: 1.0, green: 0.88, blue: 0.35, alpha: 0.9)
            mat.emission.contents = NSColor(red: 0.8, green: 0.6, blue: 0.1, alpha: 0.8)
            mat.isDoubleSided = true
            mat.transparency = 0.8
            plane.materials = [mat]

            let node = SCNNode(geometry: plane)
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            node.constraints = [constraint]

            let x = Float(rng.nextDouble() * 5 - 2.5)
            let y = Float(rng.nextDouble() * 2.0 + 0.5)
            let z = Float(rng.nextDouble() * -7 - 1)
            node.position = SCNVector3(x, y, z)
            node.opacity = 0

            // Float upward, fade in, pause, fade out, reset
            let riseDur = 6.0 + rng.nextDouble() * 5.0
            let startDelay = rng.nextDouble() * 8.0
            let wait = SCNAction.wait(duration: startDelay)
            let fadeIn = SCNAction.fadeOpacity(to: 0.85, duration: 1.5)
            let floatUp = SCNAction.moveBy(x: CGFloat((rng.nextDouble() - 0.5) * 0.5), y: 1.8, z: 0, duration: riseDur)
            floatUp.timingMode = .easeInEaseOut
            let fadeOut = SCNAction.fadeOut(duration: 1.5)
            let reset = SCNAction.run { n in n.position = SCNVector3(x, y, z) }
            let cycle = SCNAction.sequence([wait, fadeIn, floatUp, fadeOut, reset])
            node.runAction(SCNAction.repeatForever(cycle))

            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Dust motes in moonlight

    private func addDustMotes(to scene: SCNScene) {
        let ps = SCNParticleSystem()
        ps.birthRate = 8
        ps.particleLifeSpan = 10.0
        ps.particleLifeSpanVariation = 4.0
        ps.emitterShape = SCNBox(width: 2, height: 2, length: 2, chamferRadius: 0)
        ps.particleSize = 0.005
        ps.particleSizeVariation = 0.003
        ps.particleColor = NSColor(red: 0.9, green: 0.85, blue: 0.7, alpha: 0.4)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.02
        ps.particleVelocityVariation = 0.01
        ps.spreadingAngle = 180
        ps.blendMode = .additive
        let dustNode = SCNNode()
        dustNode.position = SCNVector3(-2.5, 2.0, -4)  // Near the window where moonlight enters
        scene.rootNode.addChildNode(dustNode)
        dustNode.addParticleSystem(ps)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 1.4, -3.5)
        scene.rootNode.addChildNode(pivot)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 25
        cameraNode.camera!.fieldOfView = 58
        cameraNode.camera!.wantsHDR = true
        cameraNode.camera!.bloomIntensity = 0.3
        cameraNode.camera!.bloomBlurRadius = 8
        cameraNode.camera!.bloomThreshold = 0.7
        cameraNode.camera!.wantsDepthOfField = true
        cameraNode.camera!.focusDistance = 5
        cameraNode.camera!.focalBlurSampleCount = 4
        cameraNode.camera!.fStop = 2.8
        cameraNode.position = SCNVector3(0, 0.6, 6)
        cameraNode.eulerAngles = SCNVector3(-0.05, 0, 0)
        pivot.addChildNode(cameraNode)

        // Very slow orbit
        let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 120)
        pivot.runAction(SCNAction.repeatForever(orbit))
    }
}
