// OntarioCountryside3DScene — SceneKit Ontario countryside summer evening.
// Red barn, gravel road, fence, trees, fireflies, stars.
// Tap to burst fireflies.

import SwiftUI
import SceneKit

struct OntarioCountryside3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        OntarioCountryside3DRepresentable(interaction: interaction)
    }
}

private struct OntarioCountryside3DRepresentable: NSViewRepresentable {
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
        view.backgroundColor = NSColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1)
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
        if let fs = c.fireflySystem {
            let orig = fs.birthRate
            fs.birthRate = 60
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                fs.birthRate = orig
            }
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Warm golden hour directional
        let dirNode = SCNNode()
        let dir = SCNLight(); dir.type = .directional
        dir.color = NSColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 1)
        dir.intensity = 700
        dirNode.light = dir
        dirNode.eulerAngles = SCNVector3(-Float.pi / 10, -Float.pi / 5, 0)
        scene.rootNode.addChildNode(dirNode)

        // Ambient warm dusk
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 0.1, green: 0.08, blue: 0.06, alpha: 1)
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Wheat-gold floor
        let floor = SCNFloor()
        floor.reflectivity = 0.02
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.62, green: 0.52, blue: 0.22, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Red barn body
        let barnBody = SCNBox(width: 3, height: 2.5, length: 2, chamferRadius: 0)
        let barnMat = SCNMaterial()
        barnMat.diffuse.contents = NSColor(red: 0.65, green: 0.1, blue: 0.08, alpha: 1)
        barnBody.firstMaterial = barnMat
        let barnNode = SCNNode(geometry: barnBody)
        barnNode.position = SCNVector3(-5, 1.25, -5)
        scene.rootNode.addChildNode(barnNode)

        let barnRoof = SCNPyramid(width: 3.2, height: 1.5, length: 2.2)
        let roofMat = SCNMaterial()
        roofMat.diffuse.contents = NSColor(red: 0.4, green: 0.06, blue: 0.05, alpha: 1)
        barnRoof.firstMaterial = roofMat
        let roofNode = SCNNode(geometry: barnRoof)
        roofNode.position = SCNVector3(-5, 3.25, -5)
        scene.rootNode.addChildNode(roofNode)

        // Barn door/window
        let barnWin = SCNBox(width: 0.8, height: 0.6, length: 0.04, chamferRadius: 0)
        let bwm = SCNMaterial()
        bwm.diffuse.contents = NSColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1)
        bwm.emission.contents = NSColor(red: 0.5, green: 0.35, blue: 0.05, alpha: 1)
        barnWin.firstMaterial = bwm
        let bwNode = SCNNode(geometry: barnWin)
        bwNode.position = SCNVector3(-5, 1.5, -3.98)
        scene.rootNode.addChildNode(bwNode)

        // Gravel road
        let gravel = SCNBox(width: 1.2, height: 0.01, length: 20, chamferRadius: 0)
        gravel.firstMaterial?.diffuse.contents = NSColor(red: 0.7, green: 0.64, blue: 0.52, alpha: 1)
        let gravelNode = SCNNode(geometry: gravel)
        gravelNode.position = SCNVector3(0, 0.005, -5)
        scene.rootNode.addChildNode(gravelNode)

        // Fence posts (8) along road
        for k in 0..<8 {
            let post = SCNCylinder(radius: 0.04, height: 0.8)
            post.firstMaterial?.diffuse.contents = NSColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1)
            let pNode = SCNNode(geometry: post)
            pNode.position = SCNVector3(1.0, 0.4, Float(k) * -1.5 - 1)
            scene.rootNode.addChildNode(pNode)
        }

        // Fence rails (3)
        let railColors = NSColor(red: 0.4, green: 0.26, blue: 0.14, alpha: 1)
        for r in 0..<3 {
            let rail = SCNBox(width: 0.04, height: 0.04, length: 8, chamferRadius: 0)
            rail.firstMaterial?.diffuse.contents = railColors
            let rNode = SCNNode(geometry: rail)
            rNode.position = SCNVector3(1.0, Float(r) * 0.25 + 0.15, -5)
            scene.rootNode.addChildNode(rNode)
        }

        // Trees (4 seeded)
        var rng = SplitMix64(seed: 8001)
        let treePositions: [(Float, Float)] = [
            (Float(Double.random(in: 3...5, using: &rng)), Float(Double.random(in: -3 ... -1, using: &rng))),
            (Float(Double.random(in: 3...6, using: &rng)), Float(Double.random(in: -7 ... -5, using: &rng))),
            (Float(Double.random(in: -8 ... -6, using: &rng)), Float(Double.random(in: -3 ... -1, using: &rng))),
            (Float(Double.random(in: -8 ... -6, using: &rng)), Float(Double.random(in: -8 ... -6, using: &rng)))
        ]
        for (tx, tz) in treePositions {
            let trunk = SCNCylinder(radius: 0.12, height: 2)
            trunk.firstMaterial?.diffuse.contents = NSColor(red: 0.35, green: 0.22, blue: 0.1, alpha: 1)
            let tNode = SCNNode(geometry: trunk)
            tNode.position = SCNVector3(tx, 1, tz)
            scene.rootNode.addChildNode(tNode)

            let canopy = SCNSphere(radius: 0.9)
            canopy.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.28, blue: 0.1, alpha: 1)
            let cNode = SCNNode(geometry: canopy)
            cNode.position = SCNVector3(tx, 2.7, tz)
            scene.rootNode.addChildNode(cNode)
        }

        // Stars (80 billboard planes, seeded)
        for _ in 0..<80 {
            let sx = Float(Double.random(in: -25...25, using: &rng))
            let sy = Float(Double.random(in: 8...25, using: &rng))
            let sz = Float(Double.random(in: -30 ... -5, using: &rng))
            let sr = CGFloat(Double.random(in: 0.02...0.08, using: &rng))
            let star = SCNPlane(width: sr, height: sr)
            let sm = SCNMaterial()
            let br = Double.random(in: 0.6...1.0, using: &rng)
            sm.diffuse.contents = NSColor(white: br, alpha: 1)
            sm.emission.contents = NSColor(white: br, alpha: 1)
            sm.isDoubleSided = true
            star.firstMaterial = sm
            let sNode = SCNNode(geometry: star)
            sNode.position = SCNVector3(sx, sy, sz)
            let bb = SCNBillboardConstraint()
            sNode.constraints = [bb]
            scene.rootNode.addChildNode(sNode)
        }

        // Firefly particles
        let fireflies = SCNParticleSystem()
        fireflies.birthRate = 6
        fireflies.particleLifeSpan = 8
        fireflies.particleLifeSpanVariation = 3
        fireflies.particleSize = 0.06
        fireflies.particleSizeVariation = 0.03
        fireflies.particleColor = NSColor(red: 0.8, green: 1.0, blue: 0.3, alpha: 0.9)
        fireflies.particleColorVariation = SCNVector4(0.1, 0.2, 0.1, 0.1)
        fireflies.particleVelocity = 0.3
        fireflies.particleVelocityVariation = 0.2
        fireflies.spreadingAngle = 360
        fireflies.emittingDirection = SCNVector3(0, 1, 0)
        fireflies.emitterShape = SCNBox(width: 12, height: 2, length: 12)
        fireflies.blendMode = .additive
        let ffNode = SCNNode()
        ffNode.position = SCNVector3(0, 1, -5)
        ffNode.addParticleSystem(fireflies)
        scene.rootNode.addChildNode(ffNode)
        coord.fireflySystem = fireflies

        // Camera slow pan
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 62; cam.zFar = 80
        camNode.camera = cam
        camNode.position = SCNVector3(0, 2, 5)
        camNode.eulerAngles = SCNVector3(-0.1, 0, 0)
        scene.rootNode.addChildNode(camNode)
        let pan = SCNAction.customAction(duration: 24) { node, elapsed in
            let t = Float(elapsed / 24)
            node.eulerAngles.y = sin(t * Float.pi * 2) * 0.3
        }
        camNode.runAction(SCNAction.repeatForever(pan))
    }
}
