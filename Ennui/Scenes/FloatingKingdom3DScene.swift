// FloatingKingdom3DScene — Floating sky island with crystalline spires and waterfall.
// Island with rocky underside, spires, waterfall, golden motes, cloud particles.
// Tap to pulse energy through all spires.

import SwiftUI
import SceneKit

struct FloatingKingdom3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        FloatingKingdom3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct FloatingKingdom3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var spires: [SCNNode] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.4, green: 0.6, blue: 0.85, alpha: 1)
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
        for spire in c.spires {
            let pulse = SCNAction.sequence([
                SCNAction.scale(to: 1.25, duration: 0.15),
                SCNAction.scale(to: 0.9, duration: 0.1),
                SCNAction.scale(to: 1.0, duration: 0.15)
            ])
            spire.runAction(pulse)
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.4, green: 0.6, blue: 0.85, alpha: 1)
        addLighting(to: scene)
        addIsland(to: scene)
        addSpires(to: scene, coord: coord)
        addWaterfall(to: scene)
        addGoldenMotes(to: scene)
        addClouds(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 120
        ambient.light!.color = NSColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.intensity = 800
        sun.light!.color = NSColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 1)
        sun.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 6, 0)
        scene.rootNode.addChildNode(sun)
    }

    // MARK: - Island

    private func addIsland(to scene: SCNScene) {
        // Island container – gently bobs
        let islandPivot = SCNNode()
        scene.rootNode.addChildNode(islandPivot)
        let bob = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 4.0),
            SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 4.0)
        ])
        islandPivot.runAction(SCNAction.repeatForever(bob))

        // Green top surface
        let top = SCNBox(width: 8, height: 1.5, length: 8, chamferRadius: 0.2)
        let topMat = SCNMaterial()
        topMat.diffuse.contents = NSColor(red: 0.28, green: 0.55, blue: 0.22, alpha: 1)
        let sideMat = SCNMaterial()
        sideMat.diffuse.contents = NSColor(red: 0.42, green: 0.28, blue: 0.15, alpha: 1)
        top.materials = [topMat, sideMat, sideMat, sideMat, sideMat, sideMat]
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, 0, 0)
        islandPivot.addChildNode(topNode)

        // Rocky underside main
        let under = SCNBox(width: 7, height: 2, length: 7, chamferRadius: 0.3)
        let rockMat = SCNMaterial()
        rockMat.diffuse.contents = NSColor(red: 0.40, green: 0.35, blue: 0.28, alpha: 1)
        under.materials = [rockMat]
        let underNode = SCNNode(geometry: under)
        underNode.position = SCNVector3(0, -1.8, 0)
        islandPivot.addChildNode(underNode)

        // Jagged chunks below
        var rng = SplitMix64(seed: 3333)
        for _ in 0..<6 {
            let w = Float(0.8 + rng.nextDouble() * 1.5)
            let h = Float(0.5 + rng.nextDouble() * 1.2)
            let d = Float(0.8 + rng.nextDouble() * 1.5)
            let chunk = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0.15)
            chunk.materials = [rockMat]
            let chunkNode = SCNNode(geometry: chunk)
            chunkNode.position = SCNVector3(
                Float(rng.nextDouble() * 5 - 2.5),
                -3.0 - Float(rng.nextDouble() * 1.0),
                Float(rng.nextDouble() * 5 - 2.5)
            )
            chunkNode.eulerAngles = SCNVector3(
                Float(rng.nextDouble() * 0.4 - 0.2),
                Float(rng.nextDouble() * Float.pi),
                Float(rng.nextDouble() * 0.4 - 0.2)
            )
            islandPivot.addChildNode(chunkNode)
        }
    }

    // MARK: - Spires

    private func addSpires(to scene: SCNScene, coord: Coordinator) {
        let spirePositions: [(Float, Float, Float)] = [
            (-3.0, 0.75, -3.0),
            ( 3.0, 0.75, -3.0),
            (-3.0, 0.75,  3.0),
            ( 3.0, 0.75,  3.0),
            ( 0.0, 0.75,  0.0)
        ]
        let spireMat = SCNMaterial()
        spireMat.diffuse.contents = NSColor(red: 0.75, green: 0.88, blue: 1.0, alpha: 0.6)
        spireMat.emission.contents = NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 0.5)
        spireMat.transparency = 0.4
        spireMat.lightingModel = .constant
        spireMat.isDoubleSided = true

        // Find island pivot (first child of rootNode that's doing the bob)
        let islandPivot = scene.rootNode.childNodes.first ?? scene.rootNode

        for pos in spirePositions {
            let pyramid = SCNPyramid(width: 0.6, height: 2.5, length: 0.6)
            pyramid.materials = [spireMat]
            let spireNode = SCNNode(geometry: pyramid)
            spireNode.position = SCNVector3(pos.0, pos.1, pos.2)
            scene.rootNode.addChildNode(spireNode)
            coord.spires.append(spireNode)

            // Subtle pulsing emissive
            let pulseAction = SCNAction.sequence([
                SCNAction.customAction(duration: 1.5) { node, t in
                    let intensity = Float(0.3 + 0.25 * sin(Float(t) * Float.pi))
                    (node.geometry?.materials.first?.emission.contents) = NSColor(
                        red: CGFloat(0.4 * intensity),
                        green: CGFloat(0.6 * intensity),
                        blue: CGFloat(0.9 * intensity),
                        alpha: 1
                    )
                },
                SCNAction.customAction(duration: 1.5) { node, t in
                    let intensity = Float(0.55 - 0.25 * sin(Float(t) * Float.pi))
                    (node.geometry?.materials.first?.emission.contents) = NSColor(
                        red: CGFloat(0.4 * intensity),
                        green: CGFloat(0.6 * intensity),
                        blue: CGFloat(0.9 * intensity),
                        alpha: 1
                    )
                }
            ])
            spireNode.runAction(SCNAction.repeatForever(pulseAction))
        }
    }

    // MARK: - Waterfall

    private func addWaterfall(to scene: SCNScene) {
        let fallPlane = SCNPlane(width: 0.5, height: 3)
        let fallMat = SCNMaterial()
        fallMat.diffuse.contents = NSColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 0.35)
        fallMat.emission.contents = NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 0.25)
        fallMat.isDoubleSided = true
        fallPlane.materials = [fallMat]
        let fallNode = SCNNode(geometry: fallPlane)
        fallNode.position = SCNVector3(4.0, -0.75, 0)
        scene.rootNode.addChildNode(fallNode)

        // Water drop particles
        let ps = SCNParticleSystem()
        ps.birthRate = 40
        ps.particleLifeSpan = 1.8
        ps.emitterShape = SCNPlane(width: 0.4, height: 0.1)
        ps.particleSize = 0.06
        ps.particleColor = NSColor(red: 0.75, green: 0.88, blue: 1.0, alpha: 0.8)
        ps.isAffectedByGravity = true
        ps.particleVelocity = 2.0
        ps.spreadingAngle = 8
        let waterNode = SCNNode()
        waterNode.position = SCNVector3(4.0, 0.75, 0)
        waterNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(waterNode)
        waterNode.addParticleSystem(ps)
    }

    // MARK: - Golden Motes

    private func addGoldenMotes(to scene: SCNScene) {
        let ps = SCNParticleSystem()
        ps.birthRate = 8
        ps.particleLifeSpan = 4.0
        ps.emitterShape = SCNBox(width: 7, height: 0.5, length: 7, chamferRadius: 0)
        ps.particleSize = 0.05
        ps.particleColor = NSColor(red: 1.0, green: 0.88, blue: 0.3, alpha: 0.9)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.6
        ps.spreadingAngle = 40
        let motesNode = SCNNode()
        motesNode.position = SCNVector3(0, 0.8, 0)
        scene.rootNode.addChildNode(motesNode)
        motesNode.addParticleSystem(ps)
    }

    // MARK: - Clouds

    private func addClouds(to scene: SCNScene) {
        var rng = SplitMix64(seed: 4321)
        for _ in 0..<12 {
            let sphere = SCNSphere(radius: CGFloat(0.2 + rng.nextDouble() * 0.15))
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7)
            mat.emission.contents = NSColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 0.3)
            sphere.materials = [mat]
            let cloudNode = SCNNode(geometry: sphere)
            cloudNode.position = SCNVector3(
                Float(rng.nextDouble() * 20 - 10),
                Float(-4.0 - rng.nextDouble() * 3),
                Float(rng.nextDouble() * 20 - 10)
            )
            scene.rootNode.addChildNode(cloudNode)
            let drift = SCNAction.moveBy(x: CGFloat(1.5 + rng.nextDouble()), y: 0, z: 0, duration: 12 + rng.nextDouble() * 8)
            cloudNode.runAction(SCNAction.repeatForever(SCNAction.sequence([drift, SCNAction.moveBy(x: CGFloat(-3.0 - rng.nextDouble() * 0.5), y: 0, z: 0, duration: 0.0), drift])))
        }
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(pivot)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 60
        cameraNode.camera!.fieldOfView = 70
        cameraNode.position = SCNVector3(0, -3, 12)
        cameraNode.eulerAngles = SCNVector3(0.18, 0, 0)
        pivot.addChildNode(cameraNode)

        let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 80)
        pivot.runAction(SCNAction.repeatForever(orbit))
    }
}
