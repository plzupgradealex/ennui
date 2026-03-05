// CelShadedRainyDay3DScene — Bright cel-shaded rainy day with puddles and flowers.

import SwiftUI
import SceneKit

struct CelShadedRainyDay3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        CelShadedRainyDay3DRepresentable(interaction: interaction)
    }
}

private struct CelShadedRainyDay3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var puddles: [SCNNode] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1)
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
        guard !c.puddles.isEmpty else { return }
        var rng = SplitMix64(seed: UInt64(interaction.tapCount &* 997))
        let idx = Int(Double.random(in: 0...Double(c.puddles.count - 1) + 0.99, using: &rng)) % c.puddles.count
        let puddle = c.puddles[idx]
        let expand = SCNAction.scale(to: 1.5, duration: 0.3)
        let shrink = SCNAction.scale(to: 1.0, duration: 0.3)
        puddle.runAction(SCNAction.sequence([expand, shrink]))
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Lights
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(white: 0.9, alpha: 1); amb.intensity = 600
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        let dirNode = SCNNode()
        let dir = SCNLight(); dir.type = .directional
        dir.color = NSColor(white: 0.95, alpha: 1); dir.intensity = 400
        dirNode.light = dir
        dirNode.eulerAngles = SCNVector3(-Float.pi / 3, 0.3, 0)
        scene.rootNode.addChildNode(dirNode)

        // Floor
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.35, green: 0.65, blue: 0.25, alpha: 1)
        floor.reflectivity = 0.04
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // 8 Chunky flowers
        var rng = SplitMix64(seed: 2222)
        let stemColors: [NSColor] = [
            NSColor(red: 0.2, green: 0.65, blue: 0.1, alpha: 1),
            NSColor(red: 0.15, green: 0.6, blue: 0.08, alpha: 1)
        ]
        let headColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 1),
            NSColor(red: 1.0, green: 0.5, blue: 0.05, alpha: 1),
            NSColor(red: 0.95, green: 0.9, blue: 0.1, alpha: 1),
            NSColor(red: 0.9, green: 0.1, blue: 0.9, alpha: 1),
            NSColor(red: 0.1, green: 0.4, blue: 1.0, alpha: 1),
            NSColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1),
            NSColor(red: 0.5, green: 0.1, blue: 0.9, alpha: 1),
            NSColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1)
        ]
        for i in 0..<8 {
            let fx = Float(Double.random(in: -5...5, using: &rng))
            let fz = Float(Double.random(in: -1...3, using: &rng))
            let tilt = Float(Double.random(in: -0.2...0.2, using: &rng))

            let stemGeo = SCNCylinder(radius: 0.06, height: 0.6)
            stemGeo.firstMaterial?.diffuse.contents = stemColors[i % stemColors.count]
            let stemNode = SCNNode(geometry: stemGeo)
            stemNode.position = SCNVector3(fx, 0.3, fz)
            stemNode.eulerAngles = SCNVector3(tilt, 0, tilt * 0.5)
            scene.rootNode.addChildNode(stemNode)

            let headGeo = SCNSphere(radius: 0.2)
            headGeo.firstMaterial?.diffuse.contents = headColors[i % headColors.count]
            let headNode = SCNNode(geometry: headGeo)
            headNode.position = SCNVector3(0, 0.4, 0)
            stemNode.addChildNode(headNode)
        }

        // 3 Cloud groups
        let cloudPositions: [(Float, Float, Float)] = [(0, 7, -8), (-4, 5, -6), (5, 6, -10)]
        for (cx, cy, cz) in cloudPositions {
            let cloudGroup = SCNNode()
            cloudGroup.position = SCNVector3(cx, cy, cz)
            let puffCount = Int(Double.random(in: 3...4.99, using: &rng))
            for _ in 0..<puffCount {
                let r = CGFloat(Double.random(in: 0.5...1.0, using: &rng))
                let puff = SCNSphere(radius: r)
                let grey = Double.random(in: 0.85...1.0, using: &rng)
                puff.firstMaterial?.diffuse.contents = NSColor(white: grey, alpha: 1)
                let pNode = SCNNode(geometry: puff)
                let px = Float(Double.random(in: -1.2...1.2, using: &rng))
                let py = Float(Double.random(in: -0.3...0.3, using: &rng))
                let pz = Float(Double.random(in: -0.5...0.5, using: &rng))
                pNode.position = SCNVector3(px, py, pz)
                cloudGroup.addChildNode(pNode)
            }
            // Gentle drift
            let driftDur = Double.random(in: 12...20, using: &rng)
            let drift = SCNAction.moveBy(x: CGFloat(Double.random(in: -0.8...0.8, using: &rng)),
                                         y: CGFloat(Double.random(in: -0.1...0.1, using: &rng)),
                                         z: 0, duration: driftDur)
            let driftBack = drift.reversed()
            cloudGroup.runAction(SCNAction.repeatForever(SCNAction.sequence([drift, driftBack])))
            scene.rootNode.addChildNode(cloudGroup)
        }

        // Rain particles
        let rain = SCNParticleSystem()
        rain.birthRate = 200
        rain.particleLifeSpan = 1.5
        rain.particleSize = 0.02
        rain.particleColor = NSColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.8)
        rain.particleVelocity = 7
        rain.particleVelocityVariation = 0.5
        rain.emittingDirection = SCNVector3(0.1, -1, 0)
        rain.spreadingAngle = 3
        rain.emitterShape = SCNBox(width: 20, height: 0, length: 20, chamferRadius: 0)
        rain.isAffectedByGravity = false
        let rainNode = SCNNode()
        rainNode.position = SCNVector3(0, 10, 0)
        rainNode.addParticleSystem(rain)
        scene.rootNode.addChildNode(rainNode)

        // 5 Puddles
        var prng = SplitMix64(seed: 4444)
        for _ in 0..<5 {
            let px = Float(Double.random(in: -4...4, using: &prng))
            let pz = Float(Double.random(in: -1...3, using: &prng))
            let pw = CGFloat(Double.random(in: 0.4...0.8, using: &prng))
            let pd = CGFloat(Double.random(in: 0.25...0.5, using: &prng))
            let pudGeo = SCNBox(width: pw, height: 0.005, length: pd, chamferRadius: 0)
            let pm = SCNMaterial()
            pm.diffuse.contents = NSColor(red: 0.65, green: 0.75, blue: 0.85, alpha: 0.8)
            pm.specular.contents = NSColor(white: 0.5, alpha: 1)
            pm.shininess = 60
            pudGeo.firstMaterial = pm
            let pNode = SCNNode(geometry: pudGeo)
            pNode.position = SCNVector3(px, 0.003, pz)
            scene.rootNode.addChildNode(pNode)
            coord.puddles.append(pNode)
        }

        // Camera – low wide angle, gentle bob
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 75; cam.zFar = 80
        camNode.camera = cam
        camNode.position = SCNVector3(0, 2.5, 8)
        camNode.eulerAngles = SCNVector3(-0.25, 0, 0)
        scene.rootNode.addChildNode(camNode)
        let bob = SCNAction.customAction(duration: 4) { node, elapsed in
            let angle = Float(elapsed / 4) * Float.pi * 2
            node.position = SCNVector3(0, 2.5 + sin(angle) * 0.05, 8)
        }
        camNode.runAction(SCNAction.repeatForever(bob))
    }
}
