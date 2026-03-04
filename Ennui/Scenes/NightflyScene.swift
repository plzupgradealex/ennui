// NightflyScene — Inspired by all four of Donald Fagen's solo albums.
// SceneKit 3D scene.
//
// "The Nightfly" (1982)  — late-night radio studio interior: mixing console,
//   ribbon microphone on a boom arm, reel-to-reel deck with spinning reels,
//   VU meter segment bars, pulsing ON AIR sign.
// "Kamakiriad" (1993)    — aerodynamic steam-powered vehicle idling on the
//   wet street below, running light glowing blue, exhaust wisps rising.
// "Morph the Cat" (2006) — rolling Manhattan fog, a cat on a nearby rooftop
//   with amber eyes and a slowly swaying tail.
// "Sunken Condos" (2012) — dark NYC towers studded with warm lit windows,
//   sodium-orange street lamp pooling on rain-slicked asphalt.
//
// Tap to broadcast a signal — three radio rings ripple outward from the window.

import SwiftUI
import SceneKit

struct NightflyScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        NightflySceneRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct NightflySceneRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var reelLeft: SCNNode?
        var reelRight: SCNNode?
        var onAirLight: SCNNode?
        var lastTapCount = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.backgroundColor = NSColor(red: 0.015, green: 0.02, blue: 0.05, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60
        scnView.allowsCameraControl = false

        buildScene(scene, coord: context.coordinator)
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        guard let scene = nsView.scene else { return }

        // Three radio rings ripple outward from the window opening
        for i in 0 ..< 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.22) {
                let ring = SCNTorus(ringRadius: 0.15, pipeRadius: 0.014)
                ring.firstMaterial?.diffuse.contents = NSColor.clear
                ring.firstMaterial?.emission.contents = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.9)
                ring.firstMaterial?.isDoubleSided = true
                let ringNode = SCNNode(geometry: ring)
                ringNode.position = SCNVector3(0, 1.3, -2.4)
                ringNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
                scene.rootNode.addChildNode(ringNode)

                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.8
                ringNode.scale = SCNVector3(10, 10, 10)
                ring.firstMaterial?.emission.contents = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.0)
                SCNTransaction.commit()

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    ringNode.removeFromParentNode()
                }
            }
        }

        // Brief ON AIR flash
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.08
        c.onAirLight?.light?.intensity = 900
        SCNTransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            c.onAirLight?.light?.intensity = 220
            SCNTransaction.commit()
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.fogStartDistance = 8
        scene.fogEndDistance = 28
        scene.fogColor = NSColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1)
        scene.background.contents = NSColor(red: 0.015, green: 0.02, blue: 0.05, alpha: 1)

        addLighting(to: scene, coord: coord)
        addStudioRoom(to: scene)
        addMixingConsole(to: scene)
        addReelToReel(to: scene, coord: coord)
        addMicrophone(to: scene)
        addVUMeters(to: scene)
        addCityscape(to: scene)
        addKamakiriad(to: scene)
        addCat(to: scene)
        addFog(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene, coord: Coordinator) {
        // Dim amber studio ambient
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 45
        ambient.light!.color = NSColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Warm overhead studio fill
        let overhead = SCNNode()
        overhead.light = SCNLight()
        overhead.light!.type = .omni
        overhead.light!.intensity = 280
        overhead.light!.color = NSColor(red: 0.90, green: 0.70, blue: 0.40, alpha: 1)
        overhead.light!.attenuationStartDistance = 0
        overhead.light!.attenuationEndDistance = 7
        overhead.position = SCNVector3(0, 2.8, 0.5)
        scene.rootNode.addChildNode(overhead)

        // ON AIR red accent — stored so tap can flash it
        let onAirNode = SCNNode()
        onAirNode.light = SCNLight()
        onAirNode.light!.type = .omni
        onAirNode.light!.intensity = 220
        onAirNode.light!.color = NSColor(red: 1.0, green: 0.08, blue: 0.08, alpha: 1)
        onAirNode.light!.attenuationStartDistance = 0
        onAirNode.light!.attenuationEndDistance = 2.5
        onAirNode.position = SCNVector3(0, 2.5, -1.6)
        scene.rootNode.addChildNode(onAirNode)
        coord.onAirLight = onAirNode

        // Cool city-glow coming through the window
        let cityGlow = SCNNode()
        cityGlow.light = SCNLight()
        cityGlow.light!.type = .directional
        cityGlow.light!.intensity = 60
        cityGlow.light!.color = NSColor(red: 0.28, green: 0.38, blue: 0.70, alpha: 1)
        cityGlow.eulerAngles = SCNVector3(0, Float.pi, 0)
        scene.rootNode.addChildNode(cityGlow)
    }

    // MARK: - Studio room shell

    private func addStudioRoom(to scene: SCNScene) {
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = NSColor(red: 0.07, green: 0.055, blue: 0.04, alpha: 1)

        // Floor — dark studio carpet
        let floor = SCNFloor()
        floor.reflectivity = 0.01
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.055, green: 0.04, blue: 0.03, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Ceiling
        let ceiling = SCNPlane(width: 8, height: 8)
        ceiling.firstMaterial = wallMat
        let ceilNode = SCNNode(geometry: ceiling)
        ceilNode.position = SCNVector3(0, 3.2, 0)
        ceilNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(ceilNode)

        // Side walls
        for (rotSign, xPos) in [(-1.0, -3.2), (1.0, 3.2)] as [(Double, Double)] {
            let wall = SCNPlane(width: 9, height: 3.2)
            wall.firstMaterial = wallMat
            let wNode = SCNNode(geometry: wall)
            wNode.position = SCNVector3(Float(xPos), 1.6, 0)
            wNode.eulerAngles = SCNVector3(0, Float(rotSign) * Float.pi / 2, 0)
            scene.rootNode.addChildNode(wNode)
        }

        // Front wall sections flanking the window (at z = -2.0)
        let wallColor = NSColor(red: 0.07, green: 0.055, blue: 0.04, alpha: 1)
        for (cx, cw) in [(-2.6, 2.0), (2.6, 2.0)] as [(Float, Float)] {
            let slab = SCNBox(width: CGFloat(cw), height: 3.2, length: 0.14, chamferRadius: 0)
            slab.firstMaterial?.diffuse.contents = wallColor
            let sNode = SCNNode(geometry: slab)
            sNode.position = SCNVector3(cx, 1.6, -2.0)
            scene.rootNode.addChildNode(sNode)
        }
        // Wall above window
        let topSlab = SCNBox(width: 3.7, height: 0.55, length: 0.14, chamferRadius: 0)
        topSlab.firstMaterial?.diffuse.contents = wallColor
        let topNode = SCNNode(geometry: topSlab)
        topNode.position = SCNVector3(0, 2.82, -2.0)
        scene.rootNode.addChildNode(topNode)

        // Window frame bars
        let frameMat = SCNMaterial()
        frameMat.diffuse.contents = NSColor(red: 0.13, green: 0.10, blue: 0.08, alpha: 1)
        let frameSpecs: [(Float, Float, Float, Float, Float)] = [
            // x,     y,    z,   width, height
            (-1.75, 1.30, -2.0, 0.28, 2.60),  // left bar
            ( 1.75, 1.30, -2.0, 0.28, 2.60),  // right bar
        ]
        for spec in frameSpecs {
            let bar = SCNBox(width: CGFloat(spec.3), height: CGFloat(spec.4), length: 0.18, chamferRadius: 0.02)
            bar.firstMaterial = frameMat
            let bNode = SCNNode(geometry: bar)
            bNode.position = SCNVector3(spec.0, spec.1, spec.2)
            scene.rootNode.addChildNode(bNode)
        }
        // Top bar
        let tBar = SCNBox(width: 3.78, height: 0.26, length: 0.18, chamferRadius: 0.02)
        tBar.firstMaterial = frameMat
        let tNode = SCNNode(geometry: tBar)
        tNode.position = SCNVector3(0, 2.65, -2.0)
        scene.rootNode.addChildNode(tNode)
        // Sill
        let sill = SCNBox(width: 3.78, height: 0.16, length: 0.30, chamferRadius: 0.02)
        sill.firstMaterial = frameMat
        let sillNode = SCNNode(geometry: sill)
        sillNode.position = SCNVector3(0, 0.02, -2.0)
        scene.rootNode.addChildNode(sillNode)

        // ON AIR sign
        let signMat = SCNMaterial()
        signMat.diffuse.contents = NSColor.black
        signMat.emission.contents = NSColor(red: 0.92, green: 0.08, blue: 0.08, alpha: 1)
        let onAirSign = SCNBox(width: 1.0, height: 0.28, length: 0.09, chamferRadius: 0.03)
        onAirSign.firstMaterial = signMat
        let signNode = SCNNode(geometry: onAirSign)
        signNode.position = SCNVector3(0, 3.05, -1.96)
        scene.rootNode.addChildNode(signNode)

        // Pulse the ON AIR sign
        let pulse = SCNAction.repeatForever(.sequence([
            .customAction(duration: 0.8) { node, t in
                let alpha = CGFloat(0.5 + 0.5 * sin(Float(t) * Float.pi / 0.8))
                let mat = (node.geometry as? SCNBox)?.firstMaterial
                mat?.emission.contents = NSColor(red: 0.92, green: 0.08, blue: 0.08, alpha: alpha)
            },
            .customAction(duration: 0.8) { node, t in
                let alpha = CGFloat(1.0 - 0.5 * sin(Float(t) * Float.pi / 0.8))
                let mat = (node.geometry as? SCNBox)?.firstMaterial
                mat?.emission.contents = NSColor(red: 0.92, green: 0.08, blue: 0.08, alpha: alpha)
            },
        ]))
        signNode.runAction(pulse)
    }

    // MARK: - Mixing console

    private func addMixingConsole(to scene: SCNScene) {
        let consoleMat = SCNMaterial()
        consoleMat.diffuse.contents = NSColor(red: 0.09, green: 0.08, blue: 0.11, alpha: 1)

        // Console surface
        let surface = SCNBox(width: 3.4, height: 0.11, length: 1.1, chamferRadius: 0.03)
        surface.firstMaterial = consoleMat
        let surfNode = SCNNode(geometry: surface)
        surfNode.position = SCNVector3(0, 0.78, 0.25)
        scene.rootNode.addChildNode(surfNode)

        // Angled front panel
        let panel = SCNBox(width: 3.4, height: 0.55, length: 0.07, chamferRadius: 0.02)
        panel.firstMaterial = consoleMat
        let panelNode = SCNNode(geometry: panel)
        panelNode.position = SCNVector3(0, 0.575, 0.82)
        panelNode.eulerAngles = SCNVector3(-Float.pi / 5, 0, 0)
        scene.rootNode.addChildNode(panelNode)

        // Faders
        let faderMat = SCNMaterial()
        faderMat.diffuse.contents = NSColor(red: 0.72, green: 0.72, blue: 0.76, alpha: 1)
        for i in 0 ..< 14 {
            let fader = SCNBox(width: 0.038, height: 0.17, length: 0.038, chamferRadius: 0.008)
            fader.firstMaterial = faderMat
            let fNode = SCNNode(geometry: fader)
            let fx = Float(i - 6) * 0.235 + 0.12
            let fy: Float = 0.84 + sin(Float(i) * 1.1) * 0.055
            fNode.position = SCNVector3(fx, fy, 0.15)
            scene.rootNode.addChildNode(fNode)
        }

        // Knobs
        let knobMat = SCNMaterial()
        knobMat.diffuse.contents = NSColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1)
        for i in 0 ..< 10 {
            let knob = SCNCylinder(radius: 0.046, height: 0.055)
            knob.firstMaterial = knobMat
            let kNode = SCNNode(geometry: knob)
            kNode.position = SCNVector3(Float(i - 4) * 0.32 + 0.16, 0.87, -0.1)
            scene.rootNode.addChildNode(kNode)
        }

        // Indicator LEDs
        let ledColors: [NSColor] = [
            NSColor(red: 0.15, green: 0.95, blue: 0.25, alpha: 1),
            NSColor(red: 0.95, green: 0.80, blue: 0.10, alpha: 1),
            NSColor(red: 0.95, green: 0.18, blue: 0.12, alpha: 1),
        ]
        for (row, color) in ledColors.enumerated() {
            for col in 0 ..< 5 {
                let led = SCNSphere(radius: 0.016)
                led.firstMaterial?.emission.contents = color
                led.firstMaterial?.diffuse.contents = NSColor.black
                let lNode = SCNNode(geometry: led)
                lNode.position = SCNVector3(Float(col) * 0.14 - 0.28 + Float(row) * 0.74 - 0.74,
                                            0.855,
                                            0.43)
                scene.rootNode.addChildNode(lNode)
            }
        }
    }

    // MARK: - Reel-to-reel deck

    private func addReelToReel(to scene: SCNScene, coord: Coordinator) {
        // Machine body on a side rack to the right
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        let body = SCNBox(width: 0.72, height: 0.60, length: 0.26, chamferRadius: 0.03)
        body.firstMaterial = bodyMat
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(1.9, 1.12, -0.22)
        scene.rootNode.addChildNode(bodyNode)

        // Two reels
        let leftReel = makeReel(at: SCNVector3(1.73, 1.43, -0.10), scene: scene)
        coord.reelLeft = leftReel
        let rightReel = makeReel(at: SCNVector3(2.07, 1.43, -0.10), scene: scene)
        coord.reelRight = rightReel

        // Animate: left spins faster (supply), right slower (take-up)
        leftReel.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: -.pi * 2, duration: 3.5)))
        rightReel.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: -.pi * 2, duration: 5.5)))

        // Tape guide pin
        let guide = SCNCylinder(radius: 0.016, height: 0.04)
        guide.firstMaterial?.diffuse.contents = NSColor(red: 0.55, green: 0.55, blue: 0.6, alpha: 1)
        let guideNode = SCNNode(geometry: guide)
        guideNode.position = SCNVector3(1.90, 1.29, -0.09)
        guideNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(guideNode)
    }

    private func makeReel(at position: SCNVector3, scene: SCNScene) -> SCNNode {
        let reelMat = SCNMaterial()
        reelMat.diffuse.contents = NSColor(red: 0.22, green: 0.19, blue: 0.15, alpha: 1)

        let reelNode = SCNNode()
        reelNode.position = position
        reelNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

        // Hub
        let hub = SCNCylinder(radius: 0.048, height: 0.038)
        hub.firstMaterial?.diffuse.contents = NSColor(red: 0.50, green: 0.50, blue: 0.54, alpha: 1)
        reelNode.addChildNode(SCNNode(geometry: hub))

        // Spokes
        for i in 0 ..< 6 {
            let angle = Float(i) * (.pi / 3)
            let spoke = SCNBox(width: 0.008, height: 0.082, length: 0.022, chamferRadius: 0)
            spoke.firstMaterial = reelMat
            let sNode = SCNNode(geometry: spoke)
            sNode.position = SCNVector3(sin(angle) * 0.042, cos(angle) * 0.042, 0)
            sNode.eulerAngles = SCNVector3(0, 0, angle)
            reelNode.addChildNode(sNode)
        }

        // Outer rim
        let rim = SCNTorus(ringRadius: 0.095, pipeRadius: 0.007)
        rim.firstMaterial = reelMat
        reelNode.addChildNode(SCNNode(geometry: rim))

        scene.rootNode.addChildNode(reelNode)
        return reelNode
    }

    // MARK: - Ribbon microphone

    private func addMicrophone(to scene: SCNScene) {
        // Boom arm
        let arm = SCNCylinder(radius: 0.011, height: 0.88)
        arm.firstMaterial?.diffuse.contents = NSColor(red: 0.28, green: 0.28, blue: 0.32, alpha: 1)
        let armNode = SCNNode(geometry: arm)
        armNode.position = SCNVector3(-1.55, 1.28, 0.22)
        armNode.eulerAngles = SCNVector3(0, 0, Float.pi / 5)
        scene.rootNode.addChildNode(armNode)

        // Capsule body
        let micMat = SCNMaterial()
        micMat.diffuse.contents = NSColor(red: 0.52, green: 0.48, blue: 0.42, alpha: 1)
        micMat.metalness.contents = NSNumber(value: 0.75)
        micMat.roughness.contents = NSNumber(value: 0.30)
        let capsule = SCNBox(width: 0.058, height: 0.21, length: 0.048, chamferRadius: 0.022)
        capsule.firstMaterial = micMat
        let micNode = SCNNode(geometry: capsule)
        micNode.position = SCNVector3(-1.17, 1.58, 0.14)
        scene.rootNode.addChildNode(micNode)

        // Grille cylinder
        let grille = SCNCylinder(radius: 0.036, height: 0.155)
        let grilleMat = SCNMaterial()
        grilleMat.diffuse.contents = NSColor(red: 0.38, green: 0.36, blue: 0.33, alpha: 0.65)
        grilleMat.isDoubleSided = true
        grille.firstMaterial = grilleMat
        let grilleNode = SCNNode(geometry: grille)
        grilleNode.position = SCNVector3(-1.17, 1.58, 0.14)
        scene.rootNode.addChildNode(grilleNode)
    }

    // MARK: - VU meters

    private func addVUMeters(to scene: SCNScene) {
        // Small panel mounted on the console surface
        let panelMat = SCNMaterial()
        panelMat.diffuse.contents = NSColor(red: 0.07, green: 0.065, blue: 0.09, alpha: 1)
        let panel = SCNBox(width: 0.62, height: 0.28, length: 0.055, chamferRadius: 0.02)
        panel.firstMaterial = panelMat
        let panelNode = SCNNode(geometry: panel)
        panelNode.position = SCNVector3(0, 1.34, -0.06)
        scene.rootNode.addChildNode(panelNode)

        // Segment bars: 2 channels × 7 segments (green→yellow→red)
        let segColors: [NSColor] = [
            NSColor(red: 0.10, green: 0.92, blue: 0.20, alpha: 1),
            NSColor(red: 0.10, green: 0.92, blue: 0.20, alpha: 1),
            NSColor(red: 0.10, green: 0.92, blue: 0.20, alpha: 1),
            NSColor(red: 0.10, green: 0.92, blue: 0.20, alpha: 1),
            NSColor(red: 0.92, green: 0.80, blue: 0.08, alpha: 1),
            NSColor(red: 0.92, green: 0.80, blue: 0.08, alpha: 1),
            NSColor(red: 0.92, green: 0.18, blue: 0.08, alpha: 1),
        ]

        for ch in 0 ..< 2 {
            let chX = Float(ch) * 0.28 - 0.16
            for (seg, color) in segColors.enumerated() {
                let bar = SCNBox(width: 0.022, height: 0.038, length: 0.012, chamferRadius: 0)
                bar.firstMaterial?.emission.contents = color
                bar.firstMaterial?.diffuse.contents = NSColor.black
                let bNode = SCNNode(geometry: bar)
                bNode.position = SCNVector3(chX + Float(seg) * 0.034, 1.34, -0.030)
                scene.rootNode.addChildNode(bNode)

                // Pulsing VU animation
                let delay = Double(ch) * 0.13 + Double(seg) * 0.04
                let pulse = SCNAction.repeatForever(.sequence([
                    .wait(duration: delay),
                    .customAction(duration: 0.25 + Double(seg) * 0.03) { node, _ in
                        let v = Float.random(in: 0.25 ... 1.0)
                        node.opacity = CGFloat(v)
                    },
                    .customAction(duration: 0.15) { node, _ in
                        node.opacity = 0.2
                    },
                ]))
                bNode.runAction(pulse)
            }
        }
    }

    // MARK: - Manhattan cityscape

    private func addCityscape(to scene: SCNScene) {
        var rng = SplitMix64(seed: 0x1982_CAFE)

        // Night sky backdrop
        let sky = SCNPlane(width: 28, height: 14)
        sky.firstMaterial?.diffuse.contents = NSColor(red: 0.015, green: 0.02, blue: 0.05, alpha: 1)
        sky.firstMaterial?.emission.contents = NSColor(red: 0.015, green: 0.02, blue: 0.05, alpha: 1)
        let skyNode = SCNNode(geometry: sky)
        skyNode.position = SCNVector3(0, 5, -16)
        scene.rootNode.addChildNode(skyNode)

        // Stars
        for _ in 0 ..< 110 {
            let star = SCNSphere(radius: 0.018)
            let b = Float(0.45 + nextDouble(&rng) * 0.55)
            star.firstMaterial?.emission.contents = NSColor(white: CGFloat(b), alpha: 1)
            star.firstMaterial?.diffuse.contents = NSColor.black
            let sNode = SCNNode(geometry: star)
            sNode.position = SCNVector3(
                Float(nextDouble(&rng) * 20 - 10),
                Float(3.8 + nextDouble(&rng) * 5.0),
                Float(-15.5 + nextDouble(&rng) * 4.0)
            )
            scene.rootNode.addChildNode(sNode)
        }

        // Buildings
        let buildingDefs: [(Float, Float, Float, Float, Float)] = [
            // x,    z,    h,    w,    d
            (-7.2, -9.0,  6.5, 1.3, 0.85),
            (-5.1, -8.0,  5.0, 1.0, 0.70),
            (-3.3, -7.0,  4.2, 1.1, 0.75),
            (-1.6, -6.5,  3.8, 0.95, 0.65),
            ( 0.4, -8.0,  5.5, 1.2, 0.80),
            ( 2.1, -7.0,  4.0, 1.0, 0.70),
            ( 3.7, -7.5,  5.8, 1.1, 0.75),
            ( 5.4, -9.0,  6.2, 1.3, 0.85),
            (-6.2, -12.0, 7.5, 1.5, 0.90),
            (-4.2, -13.0, 8.0, 1.4, 0.85),
            (-2.0, -11.0, 6.0, 1.1, 0.75),
            ( 0.0, -13.0, 8.5, 1.6, 0.90),
            ( 2.5, -12.0, 7.0, 1.3, 0.80),
            ( 4.5, -11.0, 6.5, 1.2, 0.75),
            ( 6.5, -12.0, 7.8, 1.4, 0.88),
        ]
        let wallColors: [NSColor] = [
            NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1),
            NSColor(red: 0.06, green: 0.055, blue: 0.085, alpha: 1),
            NSColor(red: 0.045, green: 0.048, blue: 0.072, alpha: 1),
        ]

        for (idx, def) in buildingDefs.enumerated() {
            let (bx, bz, bh, bw, bd) = (def.0, def.1, def.2, def.3, def.4)
            let building = SCNBox(width: CGFloat(bw), height: CGFloat(bh),
                                  length: CGFloat(bd), chamferRadius: 0.01)
            building.firstMaterial?.diffuse.contents = wallColors[idx % wallColors.count]
            let bNode = SCNNode(geometry: building)
            bNode.position = SCNVector3(bx, bh / 2, bz)
            scene.rootNode.addChildNode(bNode)

            // Broadcast antenna on one tall tower
            if idx == 9 {
                let antenna = SCNCylinder(radius: 0.025, height: 1.4)
                antenna.firstMaterial?.diffuse.contents = NSColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
                let antNode = SCNNode(geometry: antenna)
                antNode.position = SCNVector3(bx, bh + 0.7, bz)
                scene.rootNode.addChildNode(antNode)
                // Aviation beacon — blinking red sphere at the top
                let beacon = SCNSphere(radius: 0.045)
                beacon.firstMaterial?.emission.contents = NSColor(red: 0.95, green: 0.10, blue: 0.10, alpha: 1)
                beacon.firstMaterial?.diffuse.contents = NSColor.black
                let beaconNode = SCNNode(geometry: beacon)
                beaconNode.position = SCNVector3(bx, bh + 1.45, bz)
                scene.rootNode.addChildNode(beaconNode)
                beaconNode.runAction(.repeatForever(.sequence([
                    .fadeOpacity(to: 1.0, duration: 0.1),
                    .wait(duration: 0.3),
                    .fadeOpacity(to: 0.05, duration: 0.3),
                    .wait(duration: 1.2),
                ])))
            }

            // Warm windows
            let floorsCount = Int(bh / 0.68)
            let winsPerFloor = Int(2 + nextDouble(&rng) * 3)
            for fl in 0 ..< floorsCount {
                for wi in 0 ..< winsPerFloor {
                    guard nextDouble(&rng) < 0.52 else { continue }
                    let win = SCNPlane(width: 0.11, height: 0.15)
                    let r = CGFloat(0.82 + nextDouble(&rng) * 0.12)
                    let g = CGFloat(0.62 + nextDouble(&rng) * 0.10)
                    let b = CGFloat(0.18 + nextDouble(&rng) * 0.14)
                    win.firstMaterial?.emission.contents = NSColor(red: r, green: g, blue: b, alpha: 1)
                    win.firstMaterial?.diffuse.contents = NSColor.black
                    let wNode = SCNNode(geometry: win)
                    let spacingX = bw / Float(winsPerFloor + 1)
                    let wx = -bw / 2 + spacingX * Float(wi + 1)
                    wNode.position = SCNVector3(bx + wx, 0.38 + Float(fl) * 0.68, bz + bd / 2 + 0.01)
                    scene.rootNode.addChildNode(wNode)
                }
            }
        }

        // Wet street plane
        let streetPlane = SCNPlane(width: 22, height: 14)
        streetPlane.firstMaterial?.diffuse.contents = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        streetPlane.firstMaterial?.specular.contents = NSColor(white: 0.28, alpha: 1)
        let streetNode = SCNNode(geometry: streetPlane)
        streetNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        streetNode.position = SCNVector3(0, 0.01, -7)
        scene.rootNode.addChildNode(streetNode)

        // Sodium street lamp
        let pole = SCNCylinder(radius: 0.038, height: 2.6)
        pole.firstMaterial?.diffuse.contents = NSColor(red: 0.28, green: 0.24, blue: 0.18, alpha: 1)
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(1.5, 1.3, -5.0)
        scene.rootNode.addChildNode(poleNode)

        let lampHead = SCNBox(width: 0.26, height: 0.10, length: 0.13, chamferRadius: 0.03)
        lampHead.firstMaterial?.emission.contents = NSColor(red: 1.0, green: 0.62, blue: 0.18, alpha: 1)
        lampHead.firstMaterial?.diffuse.contents = NSColor.black
        let lampHeadNode = SCNNode(geometry: lampHead)
        lampHeadNode.position = SCNVector3(1.5, 2.65, -5.0)
        scene.rootNode.addChildNode(lampHeadNode)

        let lampOmni = SCNNode()
        lampOmni.light = SCNLight()
        lampOmni.light!.type = .omni
        lampOmni.light!.intensity = 380
        lampOmni.light!.color = NSColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 1)
        lampOmni.light!.attenuationStartDistance = 0
        lampOmni.light!.attenuationEndDistance = 5
        lampOmni.position = SCNVector3(1.5, 2.7, -5.0)
        scene.rootNode.addChildNode(lampOmni)
    }

    // MARK: - Kamakiriad vehicle

    private func addKamakiriad(to scene: SCNScene) {
        let vehicleMat = SCNMaterial()
        vehicleMat.diffuse.contents = NSColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1)
        vehicleMat.specular.contents = NSColor(white: 0.55, alpha: 1)
        vehicleMat.roughness.contents = NSNumber(value: 0.30)

        // Aerodynamic body
        let body = SCNBox(width: 0.92, height: 0.26, length: 1.85, chamferRadius: 0.09)
        body.firstMaterial = vehicleMat
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(-1.3, 0.19, -5.2)
        scene.rootNode.addChildNode(bodyNode)

        // Cockpit bubble
        let cabin = SCNCapsule(capRadius: 0.12, height: 0.38)
        cabin.firstMaterial?.diffuse.contents = NSColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1)
        cabin.firstMaterial?.transparency = 0.35
        let cabinNode = SCNNode(geometry: cabin)
        cabinNode.position = SCNVector3(-1.3, 0.40, -5.1)
        scene.rootNode.addChildNode(cabinNode)

        // Wheels
        let wheelMat = SCNMaterial()
        wheelMat.diffuse.contents = NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        for (wox, woz) in [(-0.50, -4.4), (0.50, -4.4), (-0.50, -6.0), (0.50, -6.0)] as [(Float, Float)] {
            let wheel = SCNCylinder(radius: 0.13, height: 0.11)
            wheel.firstMaterial = wheelMat
            let wNode = SCNNode(geometry: wheel)
            wNode.position = SCNVector3(-1.3 + wox, 0.065, woz)
            wNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            scene.rootNode.addChildNode(wNode)
        }

        // Blue running light strip
        let runLight = SCNBox(width: 0.88, height: 0.016, length: 0.016, chamferRadius: 0.006)
        runLight.firstMaterial?.emission.contents = NSColor(red: 0.28, green: 0.58, blue: 1.0, alpha: 1)
        runLight.firstMaterial?.diffuse.contents = NSColor.black
        let runLightNode = SCNNode(geometry: runLight)
        runLightNode.position = SCNVector3(-1.3, 0.275, -5.16)
        scene.rootNode.addChildNode(runLightNode)

        // Headlights
        let hlMat = SCNMaterial()
        hlMat.emission.contents = NSColor(red: 0.90, green: 0.86, blue: 0.70, alpha: 1)
        hlMat.diffuse.contents = NSColor.black
        for hox in [-0.34, 0.34] as [Float] {
            let hl = SCNSphere(radius: 0.038)
            hl.firstMaterial = hlMat
            let hNode = SCNNode(geometry: hl)
            hNode.position = SCNVector3(-1.3 + hox, 0.17, -4.32)
            scene.rootNode.addChildNode(hNode)

            let beam = SCNNode()
            beam.light = SCNLight()
            beam.light!.type = .omni
            beam.light!.intensity = 180
            beam.light!.color = NSColor(red: 0.90, green: 0.86, blue: 0.70, alpha: 1)
            beam.light!.attenuationStartDistance = 0
            beam.light!.attenuationEndDistance = 3
            beam.position = SCNVector3(-1.3 + hox, 0.17, -4.35)
            scene.rootNode.addChildNode(beam)
        }

        // Steam exhaust
        let steam = SCNParticleSystem()
        steam.birthRate = 9
        steam.particleLifeSpan = 2.8
        steam.particleSize = 0.14
        steam.particleSizeVariation = 0.07
        steam.particleColor = NSColor(white: 0.82, alpha: 0.30)
        steam.particleColorVariation = SCNVector4(0, 0, 0, 0.15)
        steam.blendMode = .alpha
        steam.spreadingAngle = 28
        steam.emittingDirection = SCNVector3(0, 1, 0)
        steam.particleVelocity = 0.28
        steam.particleVelocityVariation = 0.12
        steam.emitterShape = SCNSphere(radius: 0.035)
        steam.loops = true
        let steamEmitter = SCNNode()
        steamEmitter.position = SCNVector3(-1.3, 0.40, -6.12)
        steamEmitter.addParticleSystem(steam)
        scene.rootNode.addChildNode(steamEmitter)
    }

    // MARK: - Cat (Morph the Cat)

    private func addCat(to scene: SCNScene) {
        let catMat = SCNMaterial()
        catMat.diffuse.contents = NSColor(red: 0.055, green: 0.045, blue: 0.06, alpha: 1)

        // Body
        let catBody = SCNBox(width: 0.20, height: 0.13, length: 0.30, chamferRadius: 0.06)
        catBody.firstMaterial = catMat
        let bodyNode = SCNNode(geometry: catBody)
        bodyNode.position = SCNVector3(-3.3, 2.76, -7.0)
        scene.rootNode.addChildNode(bodyNode)

        // Head
        let head = SCNSphere(radius: 0.072)
        head.firstMaterial = catMat
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(-3.3, 2.90, -6.76)
        scene.rootNode.addChildNode(headNode)

        // Ears
        for earOffsetX in [-0.038, 0.038] as [Float] {
            let ear = SCNPyramid(width: 0.042, height: 0.052, length: 0.024)
            ear.firstMaterial = catMat
            let eNode = SCNNode(geometry: ear)
            eNode.position = SCNVector3(-3.3 + earOffsetX, 2.995, -6.74)
            scene.rootNode.addChildNode(eNode)
        }

        // Amber eyes
        for eyeOffsetX in [-0.026, 0.026] as [Float] {
            let eye = SCNSphere(radius: 0.011)
            eye.firstMaterial?.emission.contents = NSColor(red: 0.92, green: 0.60, blue: 0.10, alpha: 1)
            eye.firstMaterial?.diffuse.contents = NSColor.black
            let eNode = SCNNode(geometry: eye)
            eNode.position = SCNVector3(-3.3 + eyeOffsetX, 2.905, -6.692)
            scene.rootNode.addChildNode(eNode)
        }

        // Tail with gentle sway
        let tail = SCNCylinder(radius: 0.016, height: 0.30)
        tail.firstMaterial = catMat
        let tailNode = SCNNode(geometry: tail)
        tailNode.position = SCNVector3(-3.3 - 0.16, 2.80, -7.04)
        tailNode.eulerAngles = SCNVector3(0, 0, Float.pi / 4)
        scene.rootNode.addChildNode(tailNode)

        tailNode.runAction(.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: CGFloat(Float.pi / 4 + 0.22), duration: 1.6, usesShortestUnitArc: true),
            .rotateTo(x: 0, y: 0, z: CGFloat(Float.pi / 4 - 0.22), duration: 1.6, usesShortestUnitArc: true),
        ])))
    }

    // MARK: - City fog (Morph the Cat)

    private func addFog(to scene: SCNScene) {
        let fog = SCNParticleSystem()
        fog.birthRate = 3
        fog.particleLifeSpan = 14
        fog.particleSize = 1.0
        fog.particleSizeVariation = 0.5
        fog.particleColor = NSColor(red: 0.28, green: 0.33, blue: 0.44, alpha: 0.10)
        fog.blendMode = .alpha
        fog.spreadingAngle = 55
        fog.emittingDirection = SCNVector3(1, 0, 0)
        fog.particleVelocity = 0.18
        fog.particleVelocityVariation = 0.09
        fog.emitterShape = SCNBox(width: 2, height: 5, length: 14, chamferRadius: 0)
        fog.loops = true
        let fogEmitter = SCNNode()
        fogEmitter.position = SCNVector3(-5, 1.5, -9)
        fogEmitter.addParticleSystem(fog)
        scene.rootNode.addChildNode(fogEmitter)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let camera = SCNCamera()
        camera.fieldOfView = 66
        camera.zNear = 0.1
        camera.zFar = 32
        camera.wantsHDR = true
        camera.bloomIntensity = 0.45
        camera.bloomThreshold = 0.72

        let camNode = SCNNode()
        camNode.camera = camera
        camNode.position = SCNVector3(0, 1.32, 2.35)
        camNode.look(at: SCNVector3(0, 0.90, -10))
        scene.rootNode.addChildNode(camNode)

        // Gentle breathing drift — studio stillness
        camNode.runAction(.repeatForever(.sequence([
            .move(to: SCNVector3( 0.18, 1.28, 2.35), duration: 9),
            .move(to: SCNVector3(-0.18, 1.36, 2.35), duration: 9),
            .move(to: SCNVector3( 0.00, 1.32, 2.35), duration: 9),
        ])))
    }
}
