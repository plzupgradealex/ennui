// ForgottenLibrary3DScene — Infinite twilight library with floating golden letters.
// Bookshelves, stone columns, amber lamp pools, arched window, drifting letters.
// Tap to burst golden letter fragments.

import SwiftUI
import SceneKit

struct ForgottenLibrary3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        ForgottenLibrary3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct ForgottenLibrary3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var scene: SCNScene?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 1)
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
        guard let scene = c.scene else { return }
        // Tap: particle burst of golden letter fragments
        let burst = SCNParticleSystem()
        burst.birthRate = 80
        burst.particleLifeSpan = 1.5
        burst.emitterShape = SCNSphere(radius: 0.5)
        burst.particleSize = 0.08
        burst.particleColor = NSColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        burst.isAffectedByGravity = true
        burst.particleVelocity = 3.0
        burst.loops = false
        let burstNode = SCNNode()
        burstNode.position = SCNVector3(0, 1.5, -2)
        scene.rootNode.addChildNode(burstNode)
        burstNode.addParticleSystem(burst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            burstNode.removeFromParentNode()
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        coord.scene = scene
        scene.background.contents = NSColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 1)
        scene.fogStartDistance = 12
        scene.fogEndDistance = 28
        scene.fogColor = NSColor(red: 0.03, green: 0.02, blue: 0.08, alpha: 1)
        addLighting(to: scene)
        addFloor(to: scene)
        addBookshelves(to: scene)
        addStoneColumns(to: scene)
        addArchwayWindow(to: scene)
        addFloatingLetters(to: scene)
        addLampPools(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 25
        ambient.light!.color = NSColor(red: 0.2, green: 0.1, blue: 0.4, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    // MARK: - Floor

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.02
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.15, green: 0.14, blue: 0.13, alpha: 1)
        mat.roughness.contents = 0.9
        floor.materials = [mat]
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }

    // MARK: - Bookshelves

    private func addBookshelves(to scene: SCNScene) {
        let shelfXPositions: [Float] = [-5.0, -2.5, 2.5, 5.0]
        let shelfMat = SCNMaterial()
        shelfMat.diffuse.contents = NSColor(red: 0.22, green: 0.14, blue: 0.08, alpha: 1)

        for x in shelfXPositions {
            let shelf = SCNBox(width: 0.4, height: 4, length: 1.5, chamferRadius: 0)
            shelf.materials = [shelfMat]
            let shelfNode = SCNNode(geometry: shelf)
            shelfNode.position = SCNVector3(x, 2.0, -3.0)
            scene.rootNode.addChildNode(shelfNode)
            addBookSpines(to: shelfNode, at: SCNVector3(x, 2.0, -3.0), scene: scene)
        }
    }

    private func addBookSpines(to shelfNode: SCNNode, at pos: SCNVector3, scene: SCNScene) {
        var rng = SplitMix64(seed: UInt64(abs(pos.x * 100)))
        let bookColors: [NSColor] = [
            NSColor(red: 0.55, green: 0.25, blue: 0.1, alpha: 1),
            NSColor(red: 0.4, green: 0.15, blue: 0.1, alpha: 1),
            NSColor(red: 0.15, green: 0.3, blue: 0.15, alpha: 1),
            NSColor(red: 0.1, green: 0.15, blue: 0.35, alpha: 1),
            NSColor(red: 0.45, green: 0.35, blue: 0.12, alpha: 1),
        ]
        for i in 0..<20 {
            let bookH = Float(0.25 + rng.nextDouble() * 0.3)
            let bookW = Float(0.04 + rng.nextDouble() * 0.04)
            let book = SCNBox(width: CGFloat(bookW), height: CGFloat(bookH), length: 0.15, chamferRadius: 0.005)
            let mat = SCNMaterial()
            mat.diffuse.contents = bookColors[i % bookColors.count]
            book.materials = [mat]
            let bookNode = SCNNode(geometry: book)
            let row = i / 5
            let col = i % 5
            bookNode.position = SCNVector3(
                Float(col) * 0.055 - 0.11,
                Float(row) * 0.35 - 0.6,
                0.83
            )
            shelfNode.addChildNode(bookNode)
        }
    }

    // MARK: - Stone Columns

    private func addStoneColumns(to scene: SCNScene) {
        let colMat = SCNMaterial()
        colMat.diffuse.contents = NSColor(red: 0.35, green: 0.33, blue: 0.30, alpha: 1)
        let colPositions: [(Float, Float)] = [(-1.0, -3.0), (1.0, -3.0), (-1.0, -6.0), (1.0, -6.0)]
        for (x, z) in colPositions {
            let cyl = SCNCylinder(radius: 0.12, height: 4)
            cyl.materials = [colMat]
            let node = SCNNode(geometry: cyl)
            node.position = SCNVector3(x, 2.0, z)
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Archway Window

    private func addArchwayWindow(to scene: SCNScene) {
        let plane = SCNPlane(width: 2, height: 3)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.3, green: 0.4, blue: 0.55, alpha: 0.7)
        mat.emission.contents = NSColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1)
        mat.isDoubleSided = true
        plane.materials = [mat]
        let windowNode = SCNNode(geometry: plane)
        windowNode.position = SCNVector3(0, 2.0, -9.0)
        scene.rootNode.addChildNode(windowNode)

        // Moonlight from window
        let moonLight = SCNNode()
        moonLight.light = SCNLight()
        moonLight.light!.type = .directional
        moonLight.light!.intensity = 60
        moonLight.light!.color = NSColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 1)
        moonLight.eulerAngles = SCNVector3(-Float.pi / 8, 0, 0)
        moonLight.position = SCNVector3(0, 4, -8)
        scene.rootNode.addChildNode(moonLight)
    }

    // MARK: - Floating Letters

    private func addFloatingLetters(to scene: SCNScene) {
        var rng = SplitMix64(seed: 7777)
        for i in 0..<15 {
            let plane = SCNPlane(width: 0.15, height: 0.15)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
            mat.emission.contents = NSColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1)
            mat.isDoubleSided = true
            plane.materials = [mat]
            let node = SCNNode(geometry: plane)
            // Billboard constraint
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            node.constraints = [constraint]

            let x = Float(rng.nextDouble() * 8 - 4)
            let y = Float(rng.nextDouble() * 2 + 0.5)
            let z = Float(rng.nextDouble() * -8 - 1)
            node.position = SCNVector3(x, y, z)

            let floatDuration = 6.0 + rng.nextDouble() * 4.0
            let rise = SCNAction.moveBy(x: 0, y: 2, z: 0, duration: floatDuration)
            let reset = SCNAction.customAction(duration: 0) { node, _ in
                node.position = SCNVector3(x, y, z)
            }
            let fade = SCNAction.fadeOut(duration: 0.5)
            let fadeIn = SCNAction.fadeIn(duration: 0.5)
            let seq = SCNAction.sequence([rise, fade, reset, fadeIn])
            node.runAction(SCNAction.repeatForever(seq))

            scene.rootNode.addChildNode(node)
            let _ = i // suppress warning
        }
    }

    // MARK: - Lamp Pools

    private func addLampPools(to scene: SCNScene) {
        let lampPositions: [(Float, Float, Float)] = [
            (-2.5, 1.5, -2.0), (0.0, 1.5, -4.5), (2.5, 1.5, -7.0)
        ]
        for (x, y, z) in lampPositions {
            let lampNode = SCNNode()
            lampNode.light = SCNLight()
            lampNode.light!.type = .omni
            lampNode.light!.intensity = 120
            lampNode.light!.color = NSColor(red: 1.0, green: 0.72, blue: 0.35, alpha: 1)
            lampNode.light!.attenuationStartDistance = 0.5
            lampNode.light!.attenuationEndDistance = 4.0
            lampNode.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(lampNode)
        }
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 40
        cameraNode.camera!.fieldOfView = 70
        cameraNode.position = SCNVector3(0, 1.7, 2.0)
        cameraNode.eulerAngles = SCNVector3(-0.05, 0, 0)

        // Drift down corridor and jump back
        let drift = SCNAction.customAction(duration: 30) { node, time in
            let t = Float(time / 30)
            node.position = SCNVector3(0, 1.7, 2.0 + (t * -10.0))
        }
        let reset = SCNAction.customAction(duration: 0) { node, _ in
            node.position = SCNVector3(0, 1.7, 2.0)
        }
        cameraNode.runAction(SCNAction.repeatForever(SCNAction.sequence([drift, reset])))
        scene.rootNode.addChildNode(cameraNode)
    }
}
