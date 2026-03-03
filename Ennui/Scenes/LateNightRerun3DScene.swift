// LateNightRerun3DScene — SceneKit experiment.
// First-person view from bed in a 90s bedroom. CRT TV flickers colored light
// across the walls. Lava lamp glows. Glow stars on the ceiling.
// Tap to change the channel (TV color shifts). Cozy, warm, sleepy.

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

    final class Coordinator {
        var tvLight: SCNNode?
        var tvScreen: SCNNode?
        var scanlineNode: SCNNode?
        var lastTapCount = 0
        var channel = 0
        let channelColors: [NSColor] = [
            NSColor(red: 0.30, green: 0.35, blue: 0.80, alpha: 1),  // Late show blue
            NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1),  // Static gray
            NSColor(red: 0.80, green: 0.75, blue: 0.20, alpha: 1),  // Color bars
            NSColor(red: 0.12, green: 0.45, blue: 0.12, alpha: 1),  // X-Files green
            NSColor(red: 0.75, green: 0.50, blue: 0.20, alpha: 1),  // Poirot warm
        ]
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
        view.allowsCameraControl = false

        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.channel = (c.channel + 1) % c.channelColors.count
        let color = c.channelColors[c.channel]

        // Brief static burst on channel change
        let staticColor = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0
        c.tvLight?.light?.color = staticColor
        c.tvScreen?.geometry?.firstMaterial?.emission.contents = staticColor
        SCNTransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1
            c.tvLight?.light?.color = color
            c.tvScreen?.geometry?.firstMaterial?.emission.contents = color
            SCNTransaction.commit()
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor.black

        addRoom(to: scene)
        addTV(to: scene, coord: coord)
        addFurniture(to: scene)
        addDecorations(to: scene)
        addLavaLamp(to: scene)
        addCeilingStars(to: scene)
        addLighting(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Room shell

    private func addRoom(to scene: SCNScene) {
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = NSColor(red: 0.10, green: 0.08, blue: 0.13, alpha: 1)

        // Floor
        let floor = SCNFloor()
        floor.reflectivity = 0.03
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.14, green: 0.09, blue: 0.07, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Back wall
        let back = SCNPlane(width: 6, height: 3)
        back.firstMaterial = wallMat
        let backNode = SCNNode(geometry: back)
        backNode.position = SCNVector3(0, 1.5, -3)
        scene.rootNode.addChildNode(backNode)

        // Left wall
        let left = SCNPlane(width: 6, height: 3)
        left.firstMaterial = wallMat
        let leftNode = SCNNode(geometry: left)
        leftNode.position = SCNVector3(-3, 1.5, 0)
        leftNode.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        scene.rootNode.addChildNode(leftNode)

        // Right wall
        let right = SCNPlane(width: 6, height: 3)
        right.firstMaterial = wallMat
        let rightNode = SCNNode(geometry: right)
        rightNode.position = SCNVector3(3, 1.5, 0)
        rightNode.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
        scene.rootNode.addChildNode(rightNode)

        // Ceiling
        let ceil = SCNPlane(width: 6, height: 6)
        ceil.firstMaterial?.diffuse.contents = NSColor(red: 0.07, green: 0.06, blue: 0.09, alpha: 1)
        let ceilNode = SCNNode(geometry: ceil)
        ceilNode.position = SCNVector3(0, 3, 0)
        ceilNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(ceilNode)
    }

    // MARK: - CRT Television

    private func addTV(to scene: SCNScene, coord: Coordinator) {
        // TV stand / dresser
        let stand = SCNBox(width: 1.2, height: 0.5, length: 0.6, chamferRadius: 0.02)
        stand.firstMaterial?.diffuse.contents = NSColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1)
        let standNode = SCNNode(geometry: stand)
        standNode.position = SCNVector3(0, 0.25, -2.6)
        scene.rootNode.addChildNode(standNode)

        // VHS tapes stacked on dresser
        let tapeColors: [NSColor] = [
            NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1),
            NSColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1),
            NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1),
        ]
        for (i, col) in tapeColors.enumerated() {
            let tape = SCNBox(width: 0.19, height: 0.03, length: 0.12, chamferRadius: 0.003)
            tape.firstMaterial?.diffuse.contents = col
            let tapeNode = SCNNode(geometry: tape)
            tapeNode.position = SCNVector3(0.42, 0.52 + Float(i) * 0.035, -2.55)
            tapeNode.eulerAngles = SCNVector3(0, Float(i) * 0.08 - 0.04, 0)
            scene.rootNode.addChildNode(tapeNode)
            // Label sticker
            let label = SCNPlane(width: 0.12, height: 0.02)
            label.firstMaterial?.emission.contents = NSColor(red: 0.7, green: 0.65, blue: 0.55, alpha: 1)
            label.firstMaterial?.diffuse.contents = NSColor.black
            let labelNode = SCNNode(geometry: label)
            labelNode.position = SCNVector3(0.42, 0.52 + Float(i) * 0.035, -2.49)
            scene.rootNode.addChildNode(labelNode)
        }

        // CRT body — chunky box with slight chamfer
        let tvBody = SCNBox(width: 0.7, height: 0.55, length: 0.5, chamferRadius: 0.03)
        tvBody.firstMaterial?.diffuse.contents = NSColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1)
        let tvNode = SCNNode(geometry: tvBody)
        tvNode.position = SCNVector3(0, 0.78, -2.6)
        scene.rootNode.addChildNode(tvNode)

        // Screen — emissive plane
        let screen = SCNPlane(width: 0.52, height: 0.38)
        let startColor = coord.channelColors[0]
        screen.firstMaterial?.diffuse.contents = NSColor.black
        screen.firstMaterial?.emission.contents = startColor
        screen.firstMaterial?.isDoubleSided = true
        let screenNode = SCNNode(geometry: screen)
        screenNode.position = SCNVector3(0, 0.78, -2.34)
        scene.rootNode.addChildNode(screenNode)
        coord.tvScreen = screenNode

        // Scanline overlay — semi-transparent dark lines over the screen
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

        // TV content shimmer — subtle brightness variation simulating moving images
        let contentAnim = SCNAction.repeatForever(.customAction(duration: 2.0) { node, elapsed in
            let t = Float(elapsed)
            let r = CGFloat(0.30 + 0.08 * sin(Double(t) * 4.5))
            let g = CGFloat(0.35 + 0.06 * cos(Double(t) * 3.2))
            let b = CGFloat(0.80 + 0.10 * sin(Double(t) * 5.8))
            let shimmer = NSColor(red: r, green: g, blue: b, alpha: 1)
            node.geometry?.firstMaterial?.emission.contents = shimmer
        })
        screenNode.runAction(contentAnim, forKey: "contentShimmer")

        // TV light — casts colored light into room
        let tvLight = SCNNode()
        tvLight.light = SCNLight()
        tvLight.light!.type = .omni
        tvLight.light!.intensity = 220
        tvLight.light!.color = startColor
        tvLight.light!.attenuationStartDistance = 0
        tvLight.light!.attenuationEndDistance = 5
        tvLight.position = SCNVector3(0, 0.85, -2.2)
        scene.rootNode.addChildNode(tvLight)
        coord.tvLight = tvLight

        // TV flicker animation — subtle intensity wobble
        let flicker = SCNAction.repeatForever(.sequence([
            .customAction(duration: 0.08) { node, _ in
                let base: CGFloat = 220
                let wobble = CGFloat.random(in: -30...30)
                node.light?.intensity = base + wobble
            },
            .wait(duration: Double.random(in: 0.03...0.1))
        ]))
        tvLight.runAction(flicker)

        // Matching light shimmer on the TV light so the room color matches the screen
        let lightShimmer = SCNAction.repeatForever(.customAction(duration: 2.0) { node, elapsed in
            let t = Float(elapsed)
            let r = CGFloat(0.30 + 0.08 * sin(Double(t) * 4.5))
            let g = CGFloat(0.35 + 0.06 * cos(Double(t) * 3.2))
            let b = CGFloat(0.80 + 0.10 * sin(Double(t) * 5.8))
            node.light?.color = NSColor(red: r, green: g, blue: b, alpha: 1)
        })
        tvLight.runAction(lightShimmer, forKey: "lightShimmer")
    }

    // MARK: - Furniture

    private func addFurniture(to scene: SCNScene) {
        let woodColor = NSColor(red: 0.16, green: 0.10, blue: 0.07, alpha: 1)

        // Bed (camera sits here)
        let mattress = SCNBox(width: 1.8, height: 0.25, length: 2.0, chamferRadius: 0.05)
        mattress.firstMaterial?.diffuse.contents = NSColor(red: 0.25, green: 0.12, blue: 0.10, alpha: 1)
        let mattressNode = SCNNode(geometry: mattress)
        mattressNode.position = SCNVector3(0, 0.3, 1.0)
        scene.rootNode.addChildNode(mattressNode)

        // Bed frame
        let frame = SCNBox(width: 1.9, height: 0.15, length: 2.1, chamferRadius: 0.02)
        frame.firstMaterial?.diffuse.contents = woodColor
        let frameNode = SCNNode(geometry: frame)
        frameNode.position = SCNVector3(0, 0.1, 1.0)
        scene.rootNode.addChildNode(frameNode)

        // Pillow
        let pillow = SCNBox(width: 0.5, height: 0.1, length: 0.35, chamferRadius: 0.05)
        pillow.firstMaterial?.diffuse.contents = NSColor(red: 0.85, green: 0.80, blue: 0.75, alpha: 1)
        let pillowNode = SCNNode(geometry: pillow)
        pillowNode.position = SCNVector3(0, 0.48, 1.7)
        scene.rootNode.addChildNode(pillowNode)

        // Nightstand (right side)
        let nightstand = SCNBox(width: 0.4, height: 0.5, length: 0.35, chamferRadius: 0.01)
        nightstand.firstMaterial?.diffuse.contents = woodColor
        let nsNode = SCNNode(geometry: nightstand)
        nsNode.position = SCNVector3(1.3, 0.25, 1.2)
        scene.rootNode.addChildNode(nsNode)

        // Alarm clock on nightstand
        let clockBody = SCNBox(width: 0.1, height: 0.07, length: 0.05, chamferRadius: 0.01)
        clockBody.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)
        let clockNode = SCNNode(geometry: clockBody)
        clockNode.position = SCNVector3(1.25, 0.535, 1.15)
        scene.rootNode.addChildNode(clockNode)
        // Clock display glow (red LED digits)
        let clockFace = SCNPlane(width: 0.07, height: 0.035)
        clockFace.firstMaterial?.diffuse.contents = NSColor.black
        clockFace.firstMaterial?.emission.contents = NSColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1)
        clockFace.firstMaterial?.isDoubleSided = true
        let clockFaceNode = SCNNode(geometry: clockFace)
        clockFaceNode.position = SCNVector3(1.25, 0.535, 1.13)
        scene.rootNode.addChildNode(clockFaceNode)
    }

    // MARK: - Room decorations

    private func addDecorations(to scene: SCNScene) {
        // Poster on left wall — faint rectangle suggesting a movie poster
        let poster = SCNPlane(width: 0.5, height: 0.7)
        let posterMat = SCNMaterial()
        posterMat.diffuse.contents = NSColor(red: 0.14, green: 0.09, blue: 0.08, alpha: 1)
        posterMat.emission.contents = NSColor(red: 0.06, green: 0.04, blue: 0.07, alpha: 1)
        posterMat.isDoubleSided = true
        poster.firstMaterial = posterMat
        let posterNode = SCNNode(geometry: poster)
        posterNode.position = SCNVector3(-2.99, 1.6, -0.5)
        posterNode.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        scene.rootNode.addChildNode(posterNode)

        // Second smaller poster on left wall
        let poster2 = SCNPlane(width: 0.35, height: 0.5)
        let poster2Mat = SCNMaterial()
        poster2Mat.diffuse.contents = NSColor(red: 0.10, green: 0.07, blue: 0.12, alpha: 1)
        poster2Mat.emission.contents = NSColor(red: 0.04, green: 0.03, blue: 0.06, alpha: 1)
        poster2Mat.isDoubleSided = true
        poster2.firstMaterial = poster2Mat
        let poster2Node = SCNNode(geometry: poster2)
        poster2Node.position = SCNVector3(-2.99, 1.5, 0.8)
        poster2Node.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        scene.rootNode.addChildNode(poster2Node)

        // Bookshelf on right wall — low shelf with a few books
        let shelf = SCNBox(width: 0.8, height: 0.03, length: 0.2, chamferRadius: 0)
        shelf.firstMaterial?.diffuse.contents = NSColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 1)
        let shelfNode = SCNNode(geometry: shelf)
        shelfNode.position = SCNVector3(2.88, 1.3, 0)
        scene.rootNode.addChildNode(shelfNode)

        // Books on shelf
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

        // Rug on floor — dark patterned rectangle
        let rug = SCNBox(width: 1.5, height: 0.005, length: 1.0, chamferRadius: 0.01)
        rug.firstMaterial?.diffuse.contents = NSColor(red: 0.18, green: 0.08, blue: 0.08, alpha: 1)
        let rugNode = SCNNode(geometry: rug)
        rugNode.position = SCNVector3(0, 0.003, -0.5)
        scene.rootNode.addChildNode(rugNode)

        // Window on right wall with curtain — faint moonlight creeping in
        let windowFrame = SCNPlane(width: 0.6, height: 0.8)
        windowFrame.firstMaterial?.diffuse.contents = NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
        windowFrame.firstMaterial?.emission.contents = NSColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1)
        windowFrame.firstMaterial?.isDoubleSided = true
        let windowNode = SCNNode(geometry: windowFrame)
        windowNode.position = SCNVector3(2.99, 1.5, -1.5)
        windowNode.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
        scene.rootNode.addChildNode(windowNode)

        // Curtain — hangs slightly over the window
        let curtain = SCNPlane(width: 0.35, height: 0.85)
        curtain.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.06, blue: 0.08, alpha: 1)
        curtain.firstMaterial?.isDoubleSided = true
        let curtainNode = SCNNode(geometry: curtain)
        curtainNode.position = SCNVector3(2.98, 1.5, -1.7)
        curtainNode.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
        scene.rootNode.addChildNode(curtainNode)
    }

    // MARK: - Lava lamp

    private func addLavaLamp(to scene: SCNScene) {
        // Lamp body — cylinder
        let body = SCNCylinder(radius: 0.06, height: 0.28)
        body.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.08, blue: 0.12, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(1.3, 0.64, 1.2)
        scene.rootNode.addChildNode(bodyNode)

        // Glowing lava
        let glow = SCNCylinder(radius: 0.045, height: 0.18)
        glow.firstMaterial?.diffuse.contents = NSColor.black
        glow.firstMaterial?.emission.contents = NSColor(red: 0.85, green: 0.25, blue: 0.55, alpha: 1)
        let glowNode = SCNNode(geometry: glow)
        glowNode.position = SCNVector3(1.3, 0.64, 1.2)
        scene.rootNode.addChildNode(glowNode)

        // Lava lamp light — soft pink omni
        let light = SCNNode()
        light.light = SCNLight()
        light.light!.type = .omni
        light.light!.intensity = 40
        light.light!.color = NSColor(red: 0.85, green: 0.25, blue: 0.55, alpha: 1)
        light.light!.attenuationStartDistance = 0
        light.light!.attenuationEndDistance = 1.5
        light.position = SCNVector3(1.3, 0.64, 1.2)
        scene.rootNode.addChildNode(light)

        // Subtle pulsing
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
        // Very dim ambient — the TV and lava lamp are the main light sources
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 15
        ambient.light!.color = NSColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let camera = SCNCamera()
        camera.fieldOfView = 65
        camera.zNear = 0.1
        camera.zFar = 20
        camera.wantsHDR = true
        camera.bloomIntensity = 0.4
        camera.bloomThreshold = 0.7

        let camNode = SCNNode()
        camNode.camera = camera
        // Lying in bed, propped up slightly, looking at TV
        camNode.position = SCNVector3(0, 0.75, 1.5)
        camNode.look(at: SCNVector3(0, 0.78, -2.5))
        scene.rootNode.addChildNode(camNode)

        // Very gentle breathing sway
        let sway = SCNAction.repeatForever(.sequence([
            .move(by: SCNVector3(0, 0.015, 0), duration: 4.0),
            .move(by: SCNVector3(0, -0.015, 0), duration: 4.0),
        ]))
        sway.timingMode = .easeInEaseOut
        camNode.runAction(sway)
    }
}
