// RetroPS13DScene — PS1-era low-poly night cabin with fireflies.

import SwiftUI
import SceneKit

struct RetroPS13DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        RetroPS13DRepresentable(interaction: interaction)
    }
}

private struct RetroPS13DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var fireflySystem: SCNParticleSystem?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1)
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
        guard let fs = c.fireflySystem else { return }
        fs.birthRate = 40
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            fs.birthRate = 4
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Fog
        scene.fogStartDistance = 8
        scene.fogEndDistance = 20
        scene.fogColor = NSColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1)

        // Ambient
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1); amb.intensity = 120
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Floor
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.04, green: 0.08, blue: 0.04, alpha: 1)
        floor.reflectivity = 0
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Cabin body
        let cabinGeo = SCNBox(width: 2.5, height: 2.0, length: 2.5, chamferRadius: 0)
        let cabinMat = SCNMaterial()
        cabinMat.diffuse.contents = NSColor(red: 0.25, green: 0.13, blue: 0.06, alpha: 1)
        cabinGeo.firstMaterial = cabinMat
        let cabinNode = SCNNode(geometry: cabinGeo)
        cabinNode.position = SCNVector3(0, 1, -4)
        scene.rootNode.addChildNode(cabinNode)

        // Cabin roof (pyramid)
        let roofGeo = SCNPyramid(width: 3.0, height: 1.2, length: 3.0)
        let roofMat = SCNMaterial()
        roofMat.diffuse.contents = NSColor(red: 0.15, green: 0.08, blue: 0.04, alpha: 1)
        roofGeo.firstMaterial = roofMat
        let roofNode = SCNNode(geometry: roofGeo)
        roofNode.position = SCNVector3(0, 2.6, -4)
        scene.rootNode.addChildNode(roofNode)

        // Window plane (emissive warm orange)
        let winGeo = SCNPlane(width: 0.5, height: 0.4)
        let winMat = SCNMaterial()
        winMat.diffuse.contents = NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1)
        winMat.emission.contents = NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1)
        winMat.isDoubleSided = true
        winGeo.firstMaterial = winMat
        let winNode = SCNNode(geometry: winGeo)
        winNode.position = SCNVector3(0, 1.1, -2.74)
        scene.rootNode.addChildNode(winNode)

        // Window light
        let winLightNode = SCNNode()
        let winLight = SCNLight(); winLight.type = .omni
        winLight.color = NSColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)
        winLight.intensity = 200
        winLightNode.light = winLight
        winLightNode.position = SCNVector3(0, 1.1, -2.5)
        scene.rootNode.addChildNode(winLightNode)

        // 6 Pine trees
        var rng = SplitMix64(seed: 7777)
        for _ in 0..<6 {
            var tx: Float
            repeat {
                tx = Float(Double.random(in: -5...5, using: &rng))
            } while abs(tx) < 1.5
            let tz = Float(Double.random(in: -8 ... -1, using: &rng))

            let treeGeo = SCNPyramid(width: 1.5, height: 3.0, length: 1.5)
            let treeMat = SCNMaterial()
            treeMat.diffuse.contents = NSColor(red: 0.04, green: 0.14, blue: 0.05, alpha: 1)
            treeGeo.firstMaterial = treeMat
            let treeNode = SCNNode(geometry: treeGeo)
            treeNode.position = SCNVector3(tx, 1.5, tz)
            scene.rootNode.addChildNode(treeNode)

            let trunkGeo = SCNBox(width: 0.25, height: 0.5, length: 0.25, chamferRadius: 0)
            let trunkMat = SCNMaterial()
            trunkMat.diffuse.contents = NSColor(red: 0.2, green: 0.1, blue: 0.04, alpha: 1)
            trunkGeo.firstMaterial = trunkMat
            let trunkNode = SCNNode(geometry: trunkGeo)
            trunkNode.position = SCNVector3(tx, 0.25, tz)
            scene.rootNode.addChildNode(trunkNode)
        }

        // 50 Stars
        var srng = SplitMix64(seed: 9999)
        for _ in 0..<50 {
            let starGeo = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0)
            let starMat = SCNMaterial()
            starMat.diffuse.contents = NSColor.white
            starMat.emission.contents = NSColor.white
            starGeo.firstMaterial = starMat
            let sNode = SCNNode(geometry: starGeo)
            let sx = Float(Double.random(in: -15...15, using: &srng))
            let sy = Float(Double.random(in: 4...18, using: &srng))
            let sz = Float(Double.random(in: -20...5, using: &srng))
            sNode.position = SCNVector3(sx, sy, sz)
            scene.rootNode.addChildNode(sNode)
        }

        // Firefly particles
        let fireflies = SCNParticleSystem()
        fireflies.birthRate = 4
        fireflies.particleLifeSpan = 10
        fireflies.particleLifeSpanVariation = 3
        fireflies.particleSize = 0.06
        fireflies.particleColor = NSColor(red: 0.6, green: 1.0, blue: 0.2, alpha: 0.9)
        fireflies.particleVelocity = 0.15
        fireflies.particleVelocityVariation = 0.1
        fireflies.spreadingAngle = 180
        fireflies.emitterShape = SCNSphere(radius: 5)
        fireflies.isAffectedByGravity = false
        fireflies.particleColorVariation = SCNVector4(0.1, 0.2, 0.0, 0.0)
        let ffNode = SCNNode()
        ffNode.position = SCNVector3(0, 1, -4)
        ffNode.addParticleSystem(fireflies)
        scene.rootNode.addChildNode(ffNode)
        coord.fireflySystem = fireflies

        // Camera orbits
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 65; cam.zFar = 60
        camNode.camera = cam
        scene.rootNode.addChildNode(camNode)
        let orbit = SCNAction.customAction(duration: 120) { node, elapsed in
            let angle = Float(elapsed / 120) * 2 * Float.pi
            let r: Float = 9
            node.position = SCNVector3(sin(angle) * r, 2.5, cos(angle) * r - 4)
            node.eulerAngles = SCNVector3(-0.22, angle + Float.pi, 0)
        }
        camNode.runAction(SCNAction.repeatForever(orbit))
    }
}
