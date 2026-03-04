// EnchantedArchives3DScene — Magical flying library with orbiting books and paper birds.
// Bookshelf walls, orbiting books, paper birds, sparkle particles.
// Tap to scatter paper fragment burst.

import SwiftUI
import SceneKit

struct EnchantedArchives3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        EnchantedArchives3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct EnchantedArchives3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var sparkleSystem: SCNParticleSystem?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 1)
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
        guard let ps = c.sparkleSystem else { return }
        let oldRate = ps.birthRate
        ps.birthRate = 120
        ps.particleVelocity = 4.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            ps.birthRate = oldRate
            ps.particleVelocity = 0.4
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 1)
        addLighting(to: scene)
        addFloor(to: scene)
        addBookshelfWalls(to: scene)
        addFlyingBooks(to: scene)
        addPaperBirds(to: scene)
        addSparkles(to: scene, coord: coord)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 35
        ambient.light!.color = NSColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let positions: [(Float, Float, Float)] = [(-3, 3, 0), (3, 3, 0)]
        for (x, y, z) in positions {
            let light = SCNNode()
            light.light = SCNLight()
            light.light!.type = .omni
            light.light!.intensity = 200
            light.light!.color = NSColor(red: 1.0, green: 0.8, blue: 0.5, alpha: 1)
            light.light!.attenuationStartDistance = 1
            light.light!.attenuationEndDistance = 12
            light.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(light)
        }
    }

    // MARK: - Floor

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.02
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.14, green: 0.12, blue: 0.10, alpha: 1)
        floor.materials = [mat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))
    }

    // MARK: - Bookshelf Walls

    private func addBookshelfWalls(to scene: SCNScene) {
        let shelfMat = SCNMaterial()
        shelfMat.diffuse.contents = NSColor(red: 0.20, green: 0.13, blue: 0.07, alpha: 1)

        let wallConfigs: [(Float, Float, Float, Float)] = [
            (-5.5, 1.5, 0,    0),
            ( 5.5, 1.5, 0,    0),
            ( 0,   1.5, -6.5, Float.pi / 2),
            ( 0,   1.5,  6.5, Float.pi / 2),
            ( 0,   4.5, -6.5, Float.pi / 2),
        ]
        var rng = SplitMix64(seed: 4444)
        let spineColors: [NSColor] = [
            NSColor(red: 0.6, green: 0.2, blue: 0.1, alpha: 1),
            NSColor(red: 0.1, green: 0.3, blue: 0.5, alpha: 1),
            NSColor(red: 0.2, green: 0.45, blue: 0.2, alpha: 1),
            NSColor(red: 0.5, green: 0.4, blue: 0.1, alpha: 1),
            NSColor(red: 0.4, green: 0.1, blue: 0.4, alpha: 1),
        ]
        for (x, y, z, ry) in wallConfigs {
            let shelf = SCNBox(width: 3, height: 3, length: 0.3, chamferRadius: 0)
            shelf.materials = [shelfMat]
            let shelfNode = SCNNode(geometry: shelf)
            shelfNode.position = SCNVector3(x, y, z)
            shelfNode.eulerAngles = SCNVector3(0, ry, 0)
            scene.rootNode.addChildNode(shelfNode)
            // Book spine detail planes
            for j in 0..<8 {
                let spinePlane = SCNPlane(width: 0.25, height: 0.8)
                let spineMat = SCNMaterial()
                spineMat.diffuse.contents = spineColors[j % spineColors.count]
                spineMat.emission.contents = (spineColors[j % spineColors.count]).withAlphaComponent(0.15)
                spinePlane.materials = [spineMat]
                let spineNode = SCNNode(geometry: spinePlane)
                spineNode.position = SCNVector3(
                    Float(rng.nextDouble() * 2.4 - 1.2),
                    Float(rng.nextDouble() * 2.0 - 0.8),
                    0.16
                )
                shelfNode.addChildNode(spineNode)
            }
        }
    }

    // MARK: - Flying Books

    private func addFlyingBooks(to scene: SCNScene) {
        var rng = SplitMix64(seed: 5555)
        let bookColors: [NSColor] = [
            NSColor(red: 0.7, green: 0.2, blue: 0.1, alpha: 1),
            NSColor(red: 0.1, green: 0.3, blue: 0.65, alpha: 1),
            NSColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 1),
            NSColor(red: 0.6, green: 0.5, blue: 0.1, alpha: 1),
            NSColor(red: 0.45, green: 0.1, blue: 0.5, alpha: 1),
            NSColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1),
            NSColor(red: 0.2, green: 0.6, blue: 0.6, alpha: 1),
            NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1),
        ]
        for i in 0..<8 {
            let book = SCNBox(width: 0.3, height: 0.4, length: 0.05, chamferRadius: 0.01)
            let mat = SCNMaterial()
            mat.diffuse.contents = bookColors[i]
            mat.emission.contents = (bookColors[i]).withAlphaComponent(0.2)
            book.materials = [mat]
            let bookNode = SCNNode(geometry: book)
            let orbitRadius = Float(1.5 + rng.nextDouble() * 2.0)
            let orbitY = Float(1.5 + rng.nextDouble() * 2.0)
            let duration = 6.0 + rng.nextDouble() * 8.0
            let startAngle = rng.nextDouble() * Double.pi * 2

            bookNode.position = SCNVector3(orbitRadius, orbitY, 0)
            let pivot = SCNNode()
            pivot.position = SCNVector3(0, 0, 0)
            pivot.addChildNode(bookNode)
            pivot.eulerAngles.y = Float(startAngle)
            scene.rootNode.addChildNode(pivot)

            let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: duration)
            pivot.runAction(SCNAction.repeatForever(orbit))

            let tilt = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(Double.pi * 2), duration: duration * 0.7)
            bookNode.runAction(SCNAction.repeatForever(tilt))
        }
    }

    // MARK: - Paper Birds

    private func addPaperBirds(to scene: SCNScene) {
        var rng = SplitMix64(seed: 6666)
        for i in 0..<6 {
            let bird = SCNBox(width: 0.2, height: 0.12, length: 0.02, chamferRadius: 0.005)
            let mat = SCNMaterial()
            let shade = Float(0.88 + rng.nextDouble() * 0.1)
            mat.diffuse.contents = NSColor(red: CGFloat(shade), green: CGFloat(shade), blue: CGFloat(shade * 0.95), alpha: 1)
            bird.materials = [mat]
            let birdNode = SCNNode(geometry: bird)
            let orbitRadius = Float(2.0 + rng.nextDouble() * 2.0)
            let orbitY = Float(2.0 + rng.nextDouble() * 2.0)
            let duration = 14.0 + rng.nextDouble() * 10.0
            let startAngle = rng.nextDouble() * Double.pi * 2

            birdNode.position = SCNVector3(orbitRadius, orbitY, 0)
            let pivot = SCNNode()
            pivot.eulerAngles.y = Float(startAngle)
            pivot.addChildNode(birdNode)
            scene.rootNode.addChildNode(pivot)

            let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: duration)
            pivot.runAction(SCNAction.repeatForever(orbit))
            let _ = i
        }
    }

    // MARK: - Sparkles

    private func addSparkles(to scene: SCNScene, coord: Coordinator) {
        let ps = SCNParticleSystem()
        ps.birthRate = 8
        ps.particleLifeSpan = 3.0
        ps.emitterShape = SCNSphere(radius: 3.0)
        ps.particleSize = 0.04
        ps.particleColor = NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.4
        ps.particleVelocityVariation = 0.3
        ps.spreadingAngle = 180
        let sparkleNode = SCNNode()
        sparkleNode.position = SCNVector3(0, 2, 0)
        scene.rootNode.addChildNode(sparkleNode)
        sparkleNode.addParticleSystem(ps)
        coord.sparkleSystem = ps
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 2, 0)
        scene.rootNode.addChildNode(pivot)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 30
        cameraNode.camera!.fieldOfView = 70
        cameraNode.position = SCNVector3(0, 1, 9)
        cameraNode.eulerAngles = SCNVector3(-0.08, 0, 0)
        pivot.addChildNode(cameraNode)

        let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 60)
        pivot.runAction(SCNAction.repeatForever(orbit))
    }
}
