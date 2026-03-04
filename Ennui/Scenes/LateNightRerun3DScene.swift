// LateNightRerun3DScene — SceneKit
// First-person view from bed in a 90s bedroom. CRT TV flickers colored light
// across the walls. Lava lamp glows. Glow stars on the ceiling.
// Tap to change the channel — nine channels matching the 2D version.
// Cozy, warm, sleepy.

import SwiftUI
import SceneKit

struct LateNightRerun3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        LateNightRerun3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct LateNightRerun3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject {
        var tvLight: SCNNode?
        var tvScreen: SCNNode?
        var scanlineNode: SCNNode?
        var camNode: SCNNode?
        var camYaw: CGFloat = 0
        var camPitch: CGFloat = 0
        var lastTapCount = 0
        var channel = 0
        let channelCount = 9
        var channelOverlays: [SCNNode] = []

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let cam = camNode else { return }
            let sensitivity: CGFloat = 0.003
            let delta = gesture.translation(in: gesture.view)
            camYaw  -= delta.x * sensitivity
            camPitch -= delta.y * sensitivity
            camYaw   = max(-.pi * 0.38, min(.pi * 0.38, camYaw))
            camPitch = max(-0.44, min(0.70, camPitch))
            cam.eulerAngles = SCNVector3(camPitch, camYaw, 0)
            gesture.setTranslation(.zero, in: gesture.view)
        }

        // MARK: Channel system

        func applyChannel() {
            guard let screen = tvScreen, let light = tvLight else { return }
            for n in channelOverlays { n.removeFromParentNode() }
            channelOverlays.removeAll()
            screen.removeAction(forKey: "contentShimmer")
            light.removeAction(forKey: "lightShimmer")

            switch channel {
            case 0: setupLateShow(screen, light)
            case 1: setupColorBars(screen, light)
            case 2: setupStaticNoise(screen, light)
            case 3: setupScreensaver(screen, light)
            case 4: setupXFiles(screen, light)
            case 5: setupOuterLimits(screen, light)
            case 6: setupPoirot(screen, light)
            case 7: setupInfomercial(screen, light)
            case 8: setupGameConsole(screen, light)
            default: break
            }
        }

        // Ch 0 — Late Show (warm amber shifting, half-watching a sitcom)
        private func setupLateShow(_ screen: SCNNode, _ light: SCNNode) {
            screen.runAction(.repeatForever(.customAction(duration: 4.0) { node, elapsed in
                let t = Double(elapsed)
                let shift = sin(t * 0.8) * 0.5 + 0.5
                let warmth = sin(t * 1.5) * 0.3 + 0.5
                node.geometry?.firstMaterial?.emission.contents = NSColor(
                    red: CGFloat(0.30 + shift * 0.15),
                    green: CGFloat(0.20 + warmth * 0.08),
                    blue: 0.10, alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(red: 0.32, green: 0.22, blue: 0.10, alpha: 1))
        }

        // Ch 1 — Color Bars (SMPTE test pattern)
        private func setupColorBars(_ screen: SCNNode, _ light: SCNNode) {
            screen.geometry?.firstMaterial?.emission.contents = NSColor(white: 0.02, alpha: 1)
            let barColors: [NSColor] = [
                NSColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1),
                NSColor(red: 0.75, green: 0.75, blue: 0.0,  alpha: 1),
                NSColor(red: 0.0,  green: 0.75, blue: 0.75, alpha: 1),
                NSColor(red: 0.0,  green: 0.75, blue: 0.0,  alpha: 1),
                NSColor(red: 0.75, green: 0.0,  blue: 0.75, alpha: 1),
                NSColor(red: 0.75, green: 0.0,  blue: 0.0,  alpha: 1),
                NSColor(red: 0.0,  green: 0.0,  blue: 0.75, alpha: 1),
            ]
            let barW: CGFloat = 0.52 / 7.0
            for (i, col) in barColors.enumerated() {
                let bar = SCNPlane(width: barW + 0.001, height: 0.38)
                bar.firstMaterial?.diffuse.contents = NSColor.black
                bar.firstMaterial?.emission.contents = col
                bar.firstMaterial?.isDoubleSided = true
                let barNode = SCNNode(geometry: bar)
                barNode.position = SCNVector3(
                    -0.26 + barW * (CGFloat(i) + 0.5),
                    0.0, 0.002)
                screen.addChildNode(barNode)
                channelOverlays.append(barNode)
            }
            screen.runAction(.repeatForever(.customAction(duration: 2.0) { node, elapsed in
                let j = CGFloat(sin(Double(elapsed) * 5.0) * 0.008)
                node.geometry?.firstMaterial?.emission.contents = NSColor(white: 0.02 + j, alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(red: 0.45, green: 0.42, blue: 0.38, alpha: 1))
        }

        // Ch 2 — Static / Snow (flickering noise)
        private func setupStaticNoise(_ screen: SCNNode, _ light: SCNNode) {
            screen.runAction(.repeatForever(.customAction(duration: 0.5) { node, elapsed in
                let gray = CGFloat(0.10 + sin(Double(elapsed) * 60.0) * 0.06)
                let jitter = CGFloat.random(in: -0.04...0.04)
                node.geometry?.firstMaterial?.emission.contents = NSColor(
                    white: max(0.03, gray + jitter), alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(white: 0.18, alpha: 1))
        }

        // Ch 3 — DVD Screensaver (bouncing colored logo on dark blue)
        private func setupScreensaver(_ screen: SCNNode, _ light: SCNNode) {
            screen.geometry?.firstMaterial?.emission.contents = NSColor(
                red: 0.015, green: 0.015, blue: 0.08, alpha: 1)
            let logo = SCNPlane(width: 0.07, height: 0.04)
            let logoMat = SCNMaterial()
            logoMat.diffuse.contents = NSColor.black
            logoMat.emission.contents = NSColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1)
            logoMat.isDoubleSided = true
            logo.firstMaterial = logoMat
            let logoNode = SCNNode(geometry: logo)
            logoNode.position = SCNVector3(0, 0, 0.002)
            screen.addChildNode(logoNode)
            channelOverlays.append(logoNode)

            let bx = SCNAction.repeatForever(.sequence([
                .moveBy(x: 0.19, y: 0, z: 0, duration: 2.4),
                .moveBy(x: -0.38, y: 0, z: 0, duration: 4.8),
                .moveBy(x: 0.19, y: 0, z: 0, duration: 2.4),
            ]))
            let by = SCNAction.repeatForever(.sequence([
                .moveBy(x: 0, y: 0.14, z: 0, duration: 1.8),
                .moveBy(x: 0, y: -0.28, z: 0, duration: 3.6),
                .moveBy(x: 0, y: 0.14, z: 0, duration: 1.8),
            ]))
            logoNode.runAction(bx)
            logoNode.runAction(by)

            logoNode.runAction(.repeatForever(.customAction(duration: 9.0) { node, elapsed in
                let idx = Int(elapsed / 1.5) % 6
                let hues: [NSColor] = [
                    NSColor(red: 0.75, green: 0.18, blue: 0.18, alpha: 1),
                    NSColor(red: 0.18, green: 0.65, blue: 0.18, alpha: 1),
                    NSColor(red: 0.25, green: 0.25, blue: 0.85, alpha: 1),
                    NSColor(red: 0.75, green: 0.65, blue: 0.10, alpha: 1),
                    NSColor(red: 0.65, green: 0.18, blue: 0.65, alpha: 1),
                    NSColor(red: 0.18, green: 0.65, blue: 0.65, alpha: 1),
                ]
                node.geometry?.firstMaterial?.emission.contents = hues[idx]
            }))

            screen.runAction(.repeatForever(.customAction(duration: 2.0) { node, _ in
                node.geometry?.firstMaterial?.emission.contents = NSColor(
                    red: 0.015, green: 0.015, blue: 0.08, alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(red: 0.06, green: 0.06, blue: 0.18, alpha: 1))
        }

        // Ch 4 — X-Files (eerie green with sweeping flashlight)
        private func setupXFiles(_ screen: SCNNode, _ light: SCNNode) {
            screen.geometry?.firstMaterial?.emission.contents = NSColor(
                red: 0.02, green: 0.06, blue: 0.03, alpha: 1)
            let spot = SCNPlane(width: 0.06, height: 0.14)
            let spotMat = SCNMaterial()
            spotMat.diffuse.contents = NSColor.black
            spotMat.emission.contents = NSColor(red: 0.12, green: 0.45, blue: 0.18, alpha: 1)
            spotMat.isDoubleSided = true
            spot.firstMaterial = spotMat
            let spotNode = SCNNode(geometry: spot)
            spotNode.position = SCNVector3(0, 0.04, 0.002)
            screen.addChildNode(spotNode)
            channelOverlays.append(spotNode)

            let sweep = SCNAction.repeatForever(.sequence([
                .moveBy(x: 0.18, y: 0, z: 0, duration: 3.0),
                .moveBy(x: -0.36, y: 0, z: 0, duration: 6.0),
                .moveBy(x: 0.18, y: 0, z: 0, duration: 3.0),
            ]))
            sweep.timingMode = .easeInEaseOut
            spotNode.runAction(sweep)

            screen.runAction(.repeatForever(.customAction(duration: 3.0) { node, elapsed in
                let t = Double(elapsed)
                let pulse = sin(t * 1.2) * 0.02 + 0.06
                node.geometry?.firstMaterial?.emission.contents = NSColor(
                    red: 0.02, green: CGFloat(pulse), blue: 0.03, alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(red: 0.06, green: 0.30, blue: 0.10, alpha: 1))
        }

        // Ch 5 — Outer Limits (hypnotic B&W pulsing)
        private func setupOuterLimits(_ screen: SCNNode, _ light: SCNNode) {
            let eye = SCNPlane(width: 0.025, height: 0.025)
            let eyeMat = SCNMaterial()
            eyeMat.diffuse.contents = NSColor.black
            eyeMat.emission.contents = NSColor(white: 0.7, alpha: 1)
            eyeMat.isDoubleSided = true
            eye.firstMaterial = eyeMat
            let eyeNode = SCNNode(geometry: eye)
            eyeNode.position = SCNVector3(0, 0, 0.002)
            screen.addChildNode(eyeNode)
            channelOverlays.append(eyeNode)

            eyeNode.runAction(.repeatForever(.customAction(duration: 2.0) { node, elapsed in
                let pulse = CGFloat(0.5 + 0.4 * sin(Double(elapsed) * 2.5))
                node.geometry?.firstMaterial?.emission.contents = NSColor(white: pulse, alpha: 1)
            }))

            screen.runAction(.repeatForever(.customAction(duration: 3.0) { node, elapsed in
                let t = Double(elapsed)
                let pulse = sin(t / 3.0 * .pi * 2) * 0.5 + 0.5
                let gray = CGFloat(0.04 + pulse * 0.25)
                node.geometry?.firstMaterial?.emission.contents = NSColor(white: gray, alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(white: 0.20, alpha: 1))
        }

        // Ch 6 — Poirot (warm amber art deco parlour)
        private func setupPoirot(_ screen: SCNNode, _ light: SCNNode) {
            screen.runAction(.repeatForever(.customAction(duration: 4.0) { node, elapsed in
                let t = Double(elapsed)
                let warmShift = sin(t * 0.4) * 0.05
                let flicker = sin(t * 2.3) * 0.03
                node.geometry?.firstMaterial?.emission.contents = NSColor(
                    red: CGFloat(0.38 + warmShift + flicker),
                    green: CGFloat(0.24 + flicker * 0.5),
                    blue: 0.10, alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(red: 0.40, green: 0.26, blue: 0.10, alpha: 1))
        }

        // Ch 7 — Infomercial (bright garish cycling)
        private func setupInfomercial(_ screen: SCNNode, _ light: SCNNode) {
            screen.runAction(.repeatForever(.customAction(duration: 3.0) { node, elapsed in
                let t = Double(elapsed)
                let phase = fmod(t * 0.5, 1.0)
                let r = CGFloat(0.40 + sin(phase * .pi * 2) * 0.22)
                let g = CGFloat(0.35 + sin(phase * .pi * 2 + 2.1) * 0.18)
                let b = CGFloat(0.42 + sin(phase * .pi * 2 + 4.2) * 0.20)
                node.geometry?.firstMaterial?.emission.contents = NSColor(
                    red: r, green: g, blue: b, alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(red: 0.48, green: 0.40, blue: 0.45, alpha: 1))
        }

        // Ch 8 — Game Console (deep blue-purple, PS2 boot feel)
        private func setupGameConsole(_ screen: SCNNode, _ light: SCNNode) {
            screen.geometry?.firstMaterial?.emission.contents = NSColor(
                red: 0.04, green: 0.03, blue: 0.18, alpha: 1)
            for i in 0..<5 {
                let col = SCNPlane(width: 0.008, height: 0.024)
                let colMat = SCNMaterial()
                colMat.diffuse.contents = NSColor.black
                colMat.emission.contents = NSColor(red: 0.15, green: 0.20, blue: 0.80, alpha: 1)
                colMat.isDoubleSided = true
                col.firstMaterial = colMat
                let colNode = SCNNode(geometry: col)
                let xPos = CGFloat(-0.18 + Double(i) * 0.09)
                colNode.position = SCNVector3(xPos, -0.16, 0.002)
                screen.addChildNode(colNode)
                channelOverlays.append(colNode)
                let speed = 2.8 + Double(i) * 0.4
                colNode.runAction(.repeatForever(.sequence([
                    .moveBy(x: 0, y: 0.32, z: 0, duration: speed),
                    .move(to: SCNVector3(xPos, -0.16, 0.002), duration: 0),
                ])))
            }
            screen.runAction(.repeatForever(.customAction(duration: 4.0) { node, elapsed in
                let pulse = CGFloat(sin(Double(elapsed) * 0.5) * 0.06 + 0.94)
                node.geometry?.firstMaterial?.emission.contents = NSColor(
                    red: 0.04 * pulse, green: 0.03 * pulse,
                    blue: 0.18 * pulse, alpha: 1)
            }), forKey: "contentShimmer")
            setLightShimmer(light, base: NSColor(red: 0.06, green: 0.04, blue: 0.22, alpha: 1))
        }

        private func setLightShimmer(_ light: SCNNode, base: NSColor) {
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            light.runAction(.repeatForever(.customAction(duration: 2.0) { node, elapsed in
                let brightness = CGFloat(0.88 + 0.12 * sin(Double(elapsed) * 2.5))
                node.light?.color = NSColor(
                    red: br * brightness, green: bg * brightness,
                    blue: bb * brightness, alpha: 1)
            }), forKey: "lightShimmer")
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = true

        buildScene(scene, coord: context.coordinator)

        let pan = NSPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)

        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.channel = (c.channel + 1) % c.channelCount

        // Stop current channel animation during static flash
        c.tvScreen?.removeAction(forKey: "contentShimmer")
        c.tvLight?.removeAction(forKey: "lightShimmer")
        for n in c.channelOverlays { n.isHidden = true }

        // Brief static burst
        let staticColor = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0
        c.tvScreen?.geometry?.firstMaterial?.emission.contents = staticColor
        c.tvLight?.light?.color = staticColor
        SCNTransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            c.applyChannel()
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor.black

        addRoom(to: scene)
        addTV(to: scene, coord: coord)
        addFurniture(to: scene)
        addDecorations(to: scene)
        addStringLights(to: scene)
        addLavaLamp(to: scene)
        addCeilingStars(to: scene)
        addLighting(to: scene)
        addCamera(to: scene, coord: coord)
    }

    // MARK: - Room shell

    private func addRoom(to scene: SCNScene) {
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = NSColor(red: 0.10, green: 0.08, blue: 0.13, alpha: 1)

        let floor = SCNFloor()
        floor.reflectivity = 0.03
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.14, green: 0.09, blue: 0.07, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let back = SCNPlane(width: 6, height: 3)
        back.firstMaterial = wallMat
        let backNode = SCNNode(geometry: back)
        backNode.position = SCNVector3(0, 1.5, -3)
        scene.rootNode.addChildNode(backNode)

        let left = SCNPlane(width: 6, height: 3)
        left.firstMaterial = wallMat
        let leftNode = SCNNode(geometry: left)
        leftNode.position = SCNVector3(-3, 1.5, 0)
        leftNode.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
        scene.rootNode.addChildNode(leftNode)

        let right = SCNPlane(width: 6, height: 3)
        right.firstMaterial = wallMat
        let rightNode = SCNNode(geometry: right)
        rightNode.position = SCNVector3(3, 1.5, 0)
        rightNode.eulerAngles = SCNVector3(0, -CGFloat.pi / 2, 0)
        scene.rootNode.addChildNode(rightNode)

        let ceil = SCNPlane(width: 6, height: 6)
        ceil.firstMaterial?.diffuse.contents = NSColor(red: 0.07, green: 0.06, blue: 0.09, alpha: 1)
        let ceilNode = SCNNode(geometry: ceil)
        ceilNode.position = SCNVector3(0, 3, 0)
        ceilNode.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
        scene.rootNode.addChildNode(ceilNode)
    }

    // MARK: - CRT Television

    private func addTV(to scene: SCNScene, coord: Coordinator) {
        let stand = SCNBox(width: 1.2, height: 0.5, length: 0.6, chamferRadius: 0.02)
        stand.firstMaterial?.diffuse.contents = NSColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1)
        let standNode = SCNNode(geometry: stand)
        standNode.position = SCNVector3(0, 0.25, -2.6)
        scene.rootNode.addChildNode(standNode)

        let tapeColors: [NSColor] = [
            NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1),
            NSColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1),
            NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1),
        ]
        for (i, col) in tapeColors.enumerated() {
            let tape = SCNBox(width: 0.19, height: 0.03, length: 0.12, chamferRadius: 0.003)
            tape.firstMaterial?.diffuse.contents = col
            let tapeNode = SCNNode(geometry: tape)
            tapeNode.position = SCNVector3(0.42, 0.52 + CGFloat(i) * 0.035, -2.55)
            tapeNode.eulerAngles = SCNVector3(0, CGFloat(i) * 0.08 - 0.04, 0)
            scene.rootNode.addChildNode(tapeNode)
            let label = SCNPlane(width: 0.12, height: 0.02)
            label.firstMaterial?.emission.contents = NSColor(red: 0.7, green: 0.65, blue: 0.55, alpha: 1)
            label.firstMaterial?.diffuse.contents = NSColor.black
            let labelNode = SCNNode(geometry: label)
            labelNode.position = SCNVector3(0.42, 0.52 + CGFloat(i) * 0.035, -2.49)
            scene.rootNode.addChildNode(labelNode)
        }

        let tvBody = SCNBox(width: 0.7, height: 0.55, length: 0.5, chamferRadius: 0.03)
        tvBody.firstMaterial?.diffuse.contents = NSColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1)
        let tvNode = SCNNode(geometry: tvBody)
        tvNode.position = SCNVector3(0, 0.78, -2.6)
        scene.rootNode.addChildNode(tvNode)

        let screen = SCNPlane(width: 0.52, height: 0.38)
        screen.firstMaterial?.diffuse.contents = NSColor.black
        screen.firstMaterial?.emission.contents = NSColor(red: 0.30, green: 0.35, blue: 0.80, alpha: 1)
        screen.firstMaterial?.isDoubleSided = true
        let screenNode = SCNNode(geometry: screen)
        screenNode.position = SCNVector3(0, 0.78, -2.34)
        scene.rootNode.addChildNode(screenNode)
        coord.tvScreen = screenNode

        let scanlines = SCNPlane(width: 0.52, height: 0.38)
        let scanMat = SCNMaterial()
        scanMat.diffuse.contents = NSColor.clear
        scanMat.transparent.contents = NSColor(white: 0.0, alpha: 0.12)
        scanMat.isDoubleSided = true
        scanlines.firstMaterial = scanMat
        let scanNode = SCNNode(geometry: scanlines)
        scanNode.position = SCNVector3(0, 0.78, -2.335)
        scene.rootNode.addChildNode(scanNode)
        coord.scanlineNode = scanNode

        let tvLight = SCNNode()
        tvLight.light = SCNLight()
        tvLight.light!.type = .omni
        tvLight.light!.intensity = 220
        tvLight.light!.color = NSColor(red: 0.30, green: 0.35, blue: 0.80, alpha: 1)
        tvLight.light!.attenuationStartDistance = 0
        tvLight.light!.attenuationEndDistance = 5
        tvLight.position = SCNVector3(0, 0.85, -2.2)
        scene.rootNode.addChildNode(tvLight)
        coord.tvLight = tvLight

        // TV flicker — subtle intensity wobble
        let flicker = SCNAction.repeatForever(.sequence([
            .customAction(duration: 0.08) { node, _ in
                let base: CGFloat = 220
                let wobble = CGFloat.random(in: -20...20)
                node.light?.intensity = base + wobble
            },
            .wait(duration: Double.random(in: 0.05...0.15))
        ]))
        tvLight.runAction(flicker)

        // Apply initial channel content
        coord.applyChannel()
    }

    // MARK: - Furniture

    private func addFurniture(to scene: SCNScene) {
        let woodColor = NSColor(red: 0.16, green: 0.10, blue: 0.07, alpha: 1)

        let mattress = SCNBox(width: 1.8, height: 0.25, length: 2.0, chamferRadius: 0.05)
        mattress.firstMaterial?.diffuse.contents = NSColor(red: 0.25, green: 0.12, blue: 0.10, alpha: 1)
        let mattressNode = SCNNode(geometry: mattress)
        mattressNode.position = SCNVector3(0, 0.3, 1.0)
        scene.rootNode.addChildNode(mattressNode)

        let frame = SCNBox(width: 1.9, height: 0.15, length: 2.1, chamferRadius: 0.02)
        frame.firstMaterial?.diffuse.contents = woodColor
        let frameNode = SCNNode(geometry: frame)
        frameNode.position = SCNVector3(0, 0.1, 1.0)
        scene.rootNode.addChildNode(frameNode)

        let pillow = SCNBox(width: 0.5, height: 0.1, length: 0.35, chamferRadius: 0.05)
        pillow.firstMaterial?.diffuse.contents = NSColor(red: 0.85, green: 0.80, blue: 0.75, alpha: 1)
        let pillowNode = SCNNode(geometry: pillow)
        pillowNode.position = SCNVector3(0, 0.48, 1.7)
        scene.rootNode.addChildNode(pillowNode)

        let nightstand = SCNBox(width: 0.4, height: 0.5, length: 0.35, chamferRadius: 0.01)
        nightstand.firstMaterial?.diffuse.contents = woodColor
        let nsNode = SCNNode(geometry: nightstand)
        nsNode.position = SCNVector3(1.1, 0.25, 0.8)
        scene.rootNode.addChildNode(nsNode)

        let clockBody = SCNBox(width: 0.1, height: 0.07, length: 0.05, chamferRadius: 0.01)
        clockBody.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)
        let clockNode = SCNNode(geometry: clockBody)
        clockNode.position = SCNVector3(1.05, 0.535, 0.75)
        scene.rootNode.addChildNode(clockNode)

        let clockFace = SCNPlane(width: 0.07, height: 0.035)
        clockFace.firstMaterial?.diffuse.contents = NSColor.black
        clockFace.firstMaterial?.emission.contents = NSColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1)
        clockFace.firstMaterial?.isDoubleSided = true
        let clockFaceNode = SCNNode(geometry: clockFace)
        clockFaceNode.position = SCNVector3(1.05, 0.535, 0.73)
        scene.rootNode.addChildNode(clockFaceNode)
    }

    // MARK: - Room decorations

    private func addDecorations(to scene: SCNScene) {
        // Poster 1 — movie poster on left wall (film noir feel)
        let poster = SCNPlane(width: 0.5, height: 0.7)
        let posterMat = SCNMaterial()
        posterMat.diffuse.contents = NSColor(red: 0.14, green: 0.09, blue: 0.08, alpha: 1)
        posterMat.emission.contents = NSColor(red: 0.06, green: 0.04, blue: 0.07, alpha: 1)
        posterMat.isDoubleSided = true
        poster.firstMaterial = posterMat
        let posterNode = SCNNode(geometry: poster)
        posterNode.position = SCNVector3(-2.99, 1.6, -0.5)
        posterNode.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
        scene.rootNode.addChildNode(posterNode)

        // Poster 1 art — sepia movie still area
        let stillPlane = SCNPlane(width: 0.38, height: 0.40)
        let stillMat = SCNMaterial()
        stillMat.diffuse.contents = NSColor.black
        stillMat.emission.contents = NSColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1)
        stillMat.isDoubleSided = true
        stillPlane.firstMaterial = stillMat
        let stillNode = SCNNode(geometry: stillPlane)
        stillNode.position = SCNVector3(0, 0.06, 0.001)
        posterNode.addChildNode(stillNode)

        // Silhouette figure in the still
        let figPlane = SCNPlane(width: 0.10, height: 0.22)
        let figMat = SCNMaterial()
        figMat.diffuse.contents = NSColor.black
        figMat.emission.contents = NSColor(red: 0.07, green: 0.05, blue: 0.04, alpha: 1)
        figMat.isDoubleSided = true
        figPlane.firstMaterial = figMat
        let figNode = SCNNode(geometry: figPlane)
        figNode.position = SCNVector3(0.04, -0.02, 0.001)
        stillNode.addChildNode(figNode)

        // Title bar at bottom of poster 1
        let titleBar = SCNPlane(width: 0.36, height: 0.025)
        let titleMat = SCNMaterial()
        titleMat.diffuse.contents = NSColor.black
        titleMat.emission.contents = NSColor(red: 0.25, green: 0.20, blue: 0.12, alpha: 1)
        titleMat.isDoubleSided = true
        titleBar.firstMaterial = titleMat
        let titleNode = SCNNode(geometry: titleBar)
        titleNode.position = SCNVector3(0, -0.28, 0.001)
        posterNode.addChildNode(titleNode)

        // Poster 2 — smaller music/band poster on left wall
        let poster2 = SCNPlane(width: 0.35, height: 0.5)
        let poster2Mat = SCNMaterial()
        poster2Mat.diffuse.contents = NSColor(red: 0.10, green: 0.07, blue: 0.12, alpha: 1)
        poster2Mat.emission.contents = NSColor(red: 0.04, green: 0.03, blue: 0.06, alpha: 1)
        poster2Mat.isDoubleSided = true
        poster2.firstMaterial = poster2Mat
        let poster2Node = SCNNode(geometry: poster2)
        poster2Node.position = SCNVector3(-2.99, 1.5, 0.8)
        poster2Node.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
        scene.rootNode.addChildNode(poster2Node)

        // Poster 2 art — diamond album cover shape
        let albumPlane = SCNPlane(width: 0.16, height: 0.16)
        let albumMat = SCNMaterial()
        albumMat.diffuse.contents = NSColor.black
        albumMat.emission.contents = NSColor(red: 0.10, green: 0.06, blue: 0.18, alpha: 1)
        albumMat.isDoubleSided = true
        albumPlane.firstMaterial = albumMat
        let albumNode = SCNNode(geometry: albumPlane)
        albumNode.position = SCNVector3(0, 0.05, 0.001)
        albumNode.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 4)
        poster2Node.addChildNode(albumNode)

        // Band name strip at bottom
        let bandBar = SCNPlane(width: 0.24, height: 0.018)
        let bandMat = SCNMaterial()
        bandMat.diffuse.contents = NSColor.black
        bandMat.emission.contents = NSColor(red: 0.16, green: 0.10, blue: 0.20, alpha: 1)
        bandMat.isDoubleSided = true
        bandBar.firstMaterial = bandMat
        let bandNode = SCNNode(geometry: bandBar)
        bandNode.position = SCNVector3(0, -0.18, 0.001)
        poster2Node.addChildNode(bandNode)

        // Bookshelf on right wall
        let shelf = SCNBox(width: 0.8, height: 0.03, length: 0.2, chamferRadius: 0)
        shelf.firstMaterial?.diffuse.contents = NSColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 1)
        let shelfNode = SCNNode(geometry: shelf)
        shelfNode.position = SCNVector3(2.88, 1.3, 0)
        scene.rootNode.addChildNode(shelfNode)

        let bookColors: [NSColor] = [
            NSColor(red: 0.15, green: 0.08, blue: 0.06, alpha: 1),
            NSColor(red: 0.08, green: 0.06, blue: 0.14, alpha: 1),
            NSColor(red: 0.06, green: 0.12, blue: 0.06, alpha: 1),
            NSColor(red: 0.14, green: 0.10, blue: 0.04, alpha: 1),
            NSColor(red: 0.10, green: 0.04, blue: 0.04, alpha: 1),
        ]
        var bx: Float = 2.88 - 0.3
        for col in bookColors {
            let bw = Float.random(in: 0.04...0.08)
            let bh = Float.random(in: 0.15...0.22)
            let book = SCNBox(width: CGFloat(bw), height: CGFloat(bh), length: 0.12, chamferRadius: 0.003)
            book.firstMaterial?.diffuse.contents = col
            let bookNode = SCNNode(geometry: book)
            bookNode.position = SCNVector3(bx + bw / 2, 1.3 + 0.015 + bh / 2, 0)
            scene.rootNode.addChildNode(bookNode)
            bx += bw + 0.01
        }

        let rug = SCNBox(width: 1.5, height: 0.005, length: 1.0, chamferRadius: 0.01)
        rug.firstMaterial?.diffuse.contents = NSColor(red: 0.30, green: 0.12, blue: 0.12, alpha: 1)
        let rugNode = SCNNode(geometry: rug)
        rugNode.position = SCNVector3(0, 0.003, -0.5)
        scene.rootNode.addChildNode(rugNode)

        addWindow(to: scene)
    }

    // MARK: - Window with rain and moonlight

    private func addWindow(to scene: SCNScene) {
        let wx: Float = 2.99
        let wy: Float = 1.5
        let wz: Float = -1.5
        let wW: Float = 0.65
        let wH: Float = 0.90

        let glass = SCNPlane(width: CGFloat(wW), height: CGFloat(wH))
        let glassMat = SCNMaterial()
        glassMat.diffuse.contents = NSColor(red: 0.03, green: 0.06, blue: 0.18, alpha: 1)
        glassMat.emission.contents = NSColor(red: 0.08, green: 0.14, blue: 0.40, alpha: 1)
        glassMat.isDoubleSided = true
        glass.firstMaterial = glassMat
        let glassNode = SCNNode(geometry: glass)
        glassNode.position = SCNVector3(wx, wy, wz)
        glassNode.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
        scene.rootNode.addChildNode(glassNode)

        let frameMat = SCNMaterial()
        frameMat.diffuse.contents = NSColor(red: 0.09, green: 0.06, blue: 0.04, alpha: 1)
        let ft: Float = 0.025
        let fd: Float = 0.04

        let topBar = SCNBox(width: CGFloat(fd), height: CGFloat(ft),
                            length: CGFloat(wW + ft * 2), chamferRadius: 0.003)
        topBar.firstMaterial = frameMat
        let topNode = SCNNode(geometry: topBar)
        topNode.position = SCNVector3(wx, wy + wH / 2 + ft / 2, wz)
        scene.rootNode.addChildNode(topNode)

        let botBar = SCNBox(width: CGFloat(fd), height: CGFloat(ft),
                            length: CGFloat(wW + ft * 2), chamferRadius: 0.003)
        botBar.firstMaterial = frameMat
        let botNode = SCNNode(geometry: botBar)
        botNode.position = SCNVector3(wx, wy - wH / 2 - ft / 2, wz)
        scene.rootNode.addChildNode(botNode)

        let leftBar = SCNBox(width: CGFloat(fd), height: CGFloat(wH + ft * 2),
                             length: CGFloat(ft), chamferRadius: 0.003)
        leftBar.firstMaterial = frameMat
        let leftBarNode = SCNNode(geometry: leftBar)
        leftBarNode.position = SCNVector3(wx, wy, wz - wW / 2 - ft / 2)
        scene.rootNode.addChildNode(leftBarNode)

        let rightBar = SCNBox(width: CGFloat(fd), height: CGFloat(wH + ft * 2),
                              length: CGFloat(ft), chamferRadius: 0.003)
        rightBar.firstMaterial = frameMat
        let rightBarNode = SCNNode(geometry: rightBar)
        rightBarNode.position = SCNVector3(wx, wy, wz + wW / 2 + ft / 2)
        scene.rootNode.addChildNode(rightBarNode)

        let hDiv = SCNBox(width: CGFloat(fd - 0.01), height: 0.015,
                          length: CGFloat(wW), chamferRadius: 0.002)
        hDiv.firstMaterial = frameMat
        let hDivNode = SCNNode(geometry: hDiv)
        hDivNode.position = SCNVector3(wx, wy, wz)
        scene.rootNode.addChildNode(hDivNode)

        let vDiv = SCNBox(width: CGFloat(fd - 0.01), height: CGFloat(wH),
                          length: 0.015, chamferRadius: 0.002)
        vDiv.firstMaterial = frameMat
        let vDivNode = SCNNode(geometry: vDiv)
        vDivNode.position = SCNVector3(wx, wy, wz)
        scene.rootNode.addChildNode(vDivNode)

        let sill = SCNBox(width: 0.08, height: 0.03,
                          length: CGFloat(wW + 0.1), chamferRadius: 0.005)
        sill.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 1)
        let sillNode = SCNNode(geometry: sill)
        sillNode.position = SCNVector3(wx - 0.02, wy - wH / 2 - 0.015, wz)
        scene.rootNode.addChildNode(sillNode)

        let moonLight = SCNNode()
        moonLight.light = SCNLight()
        moonLight.light!.type = .omni
        moonLight.light!.intensity = 90
        moonLight.light!.color = NSColor(red: 0.55, green: 0.65, blue: 0.95, alpha: 1)
        moonLight.light!.attenuationStartDistance = 0
        moonLight.light!.attenuationEndDistance = 4
        moonLight.position = SCNVector3(3.5, 1.8, -1.5)
        scene.rootNode.addChildNode(moonLight)

        let curtainMat = SCNMaterial()
        curtainMat.diffuse.contents = NSColor(red: 0.13, green: 0.07, blue: 0.09, alpha: 1)
        curtainMat.isDoubleSided = true
        let curtainDZs: [Float] = [-0.22, 0.22]
        for dz in curtainDZs {
            let curt = SCNPlane(width: 0.26, height: CGFloat(wH + 0.2))
            curt.firstMaterial = curtainMat
            let curtNode = SCNNode(geometry: curt)
            curtNode.position = SCNVector3(wx - 0.005, wy + 0.05, wz + dz)
            curtNode.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
            scene.rootNode.addChildNode(curtNode)
        }

        addRainStreaks(to: scene,
                       windowX: wx - 0.02,
                       windowMinZ: wz - wW / 2 + 0.03,
                       windowMaxZ: wz + wW / 2 - 0.03,
                       windowTopY: wy + wH / 2 - 0.02,
                       windowBottomY: wy - wH / 2 + 0.02)
    }

    // MARK: - Rain streaks

    private func addRainStreaks(to scene: SCNScene,
                                windowX: Float, windowMinZ: Float, windowMaxZ: Float,
                                windowTopY: Float, windowBottomY: Float) {
        var rng = SplitMix64(seed: 9876)
        let winHeight = windowTopY - windowBottomY

        for _ in 0..<18 {
            let streakZ    = windowMinZ + Float(Double.random(in: 0...1, using: &rng)) * (windowMaxZ - windowMinZ)
            let startFrac  = Float(Double.random(in: 0...1, using: &rng))
            let streakLen  = Float(0.04 + Double.random(in: 0...0.07, using: &rng))
            let speed      = Float(0.10 + Double.random(in: 0...0.12, using: &rng))

            let streak = SCNBox(width: 0.004, height: CGFloat(streakLen), length: 0.002, chamferRadius: 0)
            streak.firstMaterial?.diffuse.contents = NSColor.black
            streak.firstMaterial?.emission.contents = NSColor(red: 0.45, green: 0.60, blue: 0.90, alpha: 0.55)
            streak.firstMaterial?.isDoubleSided = true

            let startY = windowTopY - startFrac * winHeight
            let streakNode = SCNNode(geometry: streak)
            streakNode.position = SCNVector3(windowX, startY, streakZ)
            scene.rootNode.addChildNode(streakNode)

            let fallDist = CGFloat(winHeight + streakLen)
            let duration = Double(fallDist) / Double(speed)
            let fall  = SCNAction.moveBy(x: 0, y: -fallDist, z: 0, duration: duration)
            let reset = SCNAction.run { n in
                let newZ = Float.random(in: windowMinZ...windowMaxZ)
                n.position = SCNVector3(windowX, windowTopY, newZ)
            }
            streakNode.runAction(.repeatForever(.sequence([fall, reset])))
        }
    }

    // MARK: - String lights

    private func addStringLights(to scene: SCNScene) {
        var rng = SplitMix64(seed: 5555)
        let count = 14

        for i in 0..<count {
            let t    = Double(i) / Double(count - 1)
            let x    = Float(-2.6 + t * 5.2)
            let sag  = Float(4.0 * t * (1.0 - t) * 0.18)
            let y: Float = 2.97 - sag
            let z: Float = -2.94

            let hue       = Double.random(in: 0...0.12, using: &rng) + 0.04
            let warmColor = NSColor(hue: CGFloat(hue), saturation: 0.85, brightness: 1.0, alpha: 1)

            let bulbGeo = SCNSphere(radius: 0.022)
            bulbGeo.firstMaterial?.diffuse.contents = NSColor.black
            bulbGeo.firstMaterial?.emission.contents = warmColor
            let bulbNode = SCNNode(geometry: bulbGeo)
            bulbNode.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(bulbNode)

            let bulbLight = SCNNode()
            bulbLight.light = SCNLight()
            bulbLight.light!.type = .omni
            bulbLight.light!.intensity = 8
            bulbLight.light!.color = warmColor
            bulbLight.light!.attenuationStartDistance = 0
            bulbLight.light!.attenuationEndDistance = 0.6
            bulbLight.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(bulbLight)

            let phase = Double.random(in: 0...(2 * Double.pi), using: &rng)
            let flicker = SCNAction.repeatForever(.customAction(duration: 2.5) { n, elapsed in
                let s = 0.85 + 0.15 * sin(Double(elapsed) / 2.5 * Double.pi * 3 + phase)
                n.light?.intensity = CGFloat(8.0 * s)
            })
            bulbLight.runAction(flicker)
        }
    }

    // MARK: - Lava lamp

    private func addLavaLamp(to scene: SCNScene) {
        let body = SCNCylinder(radius: 0.06, height: 0.28)
        body.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.08, blue: 0.12, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(1.1, 0.64, 0.8)
        scene.rootNode.addChildNode(bodyNode)

        let glow = SCNCylinder(radius: 0.045, height: 0.18)
        glow.firstMaterial?.diffuse.contents = NSColor.black
        glow.firstMaterial?.emission.contents = NSColor(red: 0.85, green: 0.25, blue: 0.55, alpha: 1)
        let glowNode = SCNNode(geometry: glow)
        glowNode.position = SCNVector3(1.1, 0.64, 0.8)
        scene.rootNode.addChildNode(glowNode)

        let light = SCNNode()
        light.light = SCNLight()
        light.light!.type = .omni
        light.light!.intensity = 40
        light.light!.color = NSColor(red: 0.85, green: 0.25, blue: 0.55, alpha: 1)
        light.light!.attenuationStartDistance = 0
        light.light!.attenuationEndDistance = 1.5
        light.position = SCNVector3(1.1, 0.64, 0.8)
        scene.rootNode.addChildNode(light)

        let pulse = SCNAction.repeatForever(.sequence([
            .customAction(duration: 3.0) { node, elapsed in
                let t = Float(elapsed / 3.0)
                let i = CGFloat(35 + 15 * sin(t * .pi))
                node.light?.intensity = i
            }
        ]))
        light.runAction(pulse)
    }

    // MARK: - Glow-in-the-dark ceiling stars

    private func addCeilingStars(to scene: SCNScene) {
        var rng = SplitMix64(seed: 2001)
        let starColor = NSColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 1)

        for _ in 0..<25 {
            let sx = Float(-2.5 + Double.random(in: 0...5, using: &rng))
            let sz = Float(-2.5 + Double.random(in: 0...5, using: &rng))
            let ss = CGFloat(0.02 + Double.random(in: 0...0.02, using: &rng))

            let star = SCNPlane(width: ss, height: ss)
            star.firstMaterial?.diffuse.contents = NSColor.black
            star.firstMaterial?.emission.contents = starColor
            star.firstMaterial?.isDoubleSided = true
            let sNode = SCNNode(geometry: star)
            sNode.position = SCNVector3(sx, 2.99, sz)
            sNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            scene.rootNode.addChildNode(sNode)
        }
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 15
        ambient.light!.color = NSColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene, coord: Coordinator) {
        let camera = SCNCamera()
        camera.fieldOfView = 65
        camera.zNear = 0.1
        camera.zFar = 20
        camera.wantsHDR = true
        camera.bloomIntensity = 0.4
        camera.bloomThreshold = 0.7

        let camNode = SCNNode()
        camNode.camera = camera
        camNode.position = SCNVector3(0, 0.75, 1.5)
        camNode.look(at: SCNVector3(0, 0.78, -2.5))
        scene.rootNode.addChildNode(camNode)
        coord.camNode = camNode

        let sway = SCNAction.repeatForever(.sequence([
            .move(by: SCNVector3(0, 0.015, 0), duration: 4.0),
            .move(by: SCNVector3(0, -0.015, 0), duration: 4.0),
        ]))
        sway.timingMode = .easeInEaseOut
        camNode.runAction(sway)
    }
}
