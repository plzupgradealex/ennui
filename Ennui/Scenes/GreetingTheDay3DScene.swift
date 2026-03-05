// GreetingTheDay3DScene — Sunrise city with buildings lighting up and golden dust.

import SwiftUI
import SceneKit

struct GreetingTheDay3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        GreetingTheDay3DRepresentable(interaction: interaction)
    }
}

private struct GreetingTheDay3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var rootNode: SCNNode?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.06, green: 0.04, blue: 0.12, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = false
        context.coordinator.rootNode = scene.rootNode
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        guard let root = c.rootNode else { return }
        var rng = SplitMix64(seed: UInt64(interaction.tapCount &* 2341))
        let bw = CGFloat(Double.random(in: 1.0...2.5, using: &rng))
        let bh = CGFloat(Double.random(in: 2...9, using: &rng))
        let bx = Float(Double.random(in: -8...8, using: &rng))
        let bz = Float(Double.random(in: -10 ... -3, using: &rng))
        let bGeo = SCNBox(width: bw, height: bh, length: bw * 0.8, chamferRadius: 0)
        let grey = Double.random(in: 0.3...0.5, using: &rng)
        bGeo.firstMaterial?.diffuse.contents = NSColor(red: grey * 0.8, green: grey * 0.85, blue: grey, alpha: 1)
        let bNode = SCNNode(geometry: bGeo)
        bNode.position = SCNVector3(bx, 0, bz)
        bNode.scale = SCNVector3(1, 0.001, 1)
        root.addChildNode(bNode)
        let grow = SCNAction.customAction(duration: 0.6) { node, elapsed in
            let progress = Float(elapsed / 0.6)
            let h = Float(bh) * progress
            node.scale = SCNVector3(1, progress, 1)
            node.position = SCNVector3(bx, h / 2, bz)
        }
        bNode.runAction(grow)
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Ambient
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 0.05, green: 0.04, blue: 0.1, alpha: 1); amb.intensity = 80
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Directional sunlight that brightens over 60s
        let dirLightNode = SCNNode()
        let dir = SCNLight(); dir.type = .directional
        dir.color = NSColor(red: 0.4, green: 0.45, blue: 0.7, alpha: 1)
        dir.intensity = 20
        dirLightNode.light = dir
        dirLightNode.eulerAngles = SCNVector3(-Float.pi / 5, -Float.pi / 4, 0)
        scene.rootNode.addChildNode(dirLightNode)
        let lightAnim = SCNAction.customAction(duration: 60) { node, elapsed in
            let t = Float(elapsed / 60)
            node.light?.intensity = CGFloat(20 + t * 280)
            let r = 0.4 + t * 0.5
            let g = 0.45 + t * 0.35
            let b = 0.7 - t * 0.35
            node.light?.color = NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
        }
        dirLightNode.runAction(SCNAction.repeatForever(lightAnim))

        // Floor
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.10, blue: 0.15, alpha: 1)
        floor.reflectivity = 0.05
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // 10 City buildings
        var rng = SplitMix64(seed: 3333)
        let windowAmber = NSColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 1)
        for _ in 0..<10 {
            let bw = CGFloat(Double.random(in: 1.0...2.5, using: &rng))
            let bh = CGFloat(Double.random(in: 2...9, using: &rng))
            let bx = Float(Double.random(in: -8...8, using: &rng))
            let bz = Float(Double.random(in: -10 ... -3, using: &rng))
            let grey = Double.random(in: 0.28...0.45, using: &rng)

            let bGeo = SCNBox(width: bw, height: bh, length: bw * 0.8, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: grey * 0.75, green: grey * 0.82, blue: grey, alpha: 1)
            bGeo.firstMaterial = mat
            let bNode = SCNNode(geometry: bGeo)
            bNode.position = SCNVector3(bx, Float(bh) / 2, bz)
            scene.rootNode.addChildNode(bNode)

            // 2-4 windows, staggered light-up
            let winCount = Int(Double.random(in: 2...4.99, using: &rng))
            for w in 0..<winCount {
                let wGeo = SCNPlane(width: 0.2, height: 0.15)
                let wMat = SCNMaterial()
                wMat.diffuse.contents = NSColor(white: 0.02, alpha: 1)
                wMat.emission.contents = NSColor(white: 0.0, alpha: 1)
                wMat.isDoubleSided = true
                wGeo.firstMaterial = wMat
                let wNode = SCNNode(geometry: wGeo)
                let halfH = Double(bh) / 2.0
                let halfW = Double(bw) / 2.0
                let wy = CGFloat(Double.random(in: (-halfH + 0.3)...(halfH - 0.3), using: &rng))
                let wx = CGFloat(Double.random(in: (-halfW + 0.2)...(halfW - 0.2), using: &rng))
                wNode.position = SCNVector3(wx, wy, CGFloat(bw * 0.4) + 0.01)
                bNode.addChildNode(wNode)
                let delay = Double(w) * Double.random(in: 2...10, using: &rng)
                let lightUp = SCNAction.sequence([
                    SCNAction.wait(duration: delay),
                    SCNAction.customAction(duration: 0.5) { node, _ in
                        node.geometry?.firstMaterial?.emission.contents = windowAmber
                    }
                ])
                wNode.runAction(lightUp)
            }
        }

        // Sun sphere
        let sunGeo = SCNSphere(radius: 1.0)
        let sunMat = SCNMaterial()
        sunMat.diffuse.contents = NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1)
        sunMat.emission.contents = NSColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1)
        sunGeo.firstMaterial = sunMat
        let sunNode = SCNNode(geometry: sunGeo)
        sunNode.position = SCNVector3(-8, -2, -15)
        scene.rootNode.addChildNode(sunNode)
        let sunRise = SCNAction.customAction(duration: 60) { node, elapsed in
            let t = Float(elapsed / 60)
            node.position = SCNVector3(-8, -2 + t * 7, -15)
        }
        sunNode.runAction(SCNAction.repeatForever(sunRise))

        // Golden dust motes
        let dust = SCNParticleSystem()
        dust.birthRate = 30
        dust.particleLifeSpan = 6
        dust.particleSize = 0.03
        dust.particleColor = NSColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 0.7)
        dust.particleVelocity = 0.3
        dust.particleVelocityVariation = 0.2
        dust.emittingDirection = SCNVector3(0.1, 1, 0)
        dust.spreadingAngle = 60
        dust.emitterShape = SCNBox(width: 18, height: 0, length: 14, chamferRadius: 0)
        dust.isAffectedByGravity = false
        let dustNode = SCNNode()
        dustNode.position = SCNVector3(0, 0, -6)
        dustNode.addParticleSystem(dust)
        scene.rootNode.addChildNode(dustNode)

        // Camera tilts upward
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 70; cam.zFar = 80
        camNode.camera = cam
        camNode.position = SCNVector3(0, 3, 10)
        camNode.eulerAngles = SCNVector3(-0.15, 0, 0)
        scene.rootNode.addChildNode(camNode)
        let camTilt = SCNAction.customAction(duration: 60) { node, elapsed in
            let t = Float(elapsed / 60)
            node.eulerAngles = SCNVector3(-0.15 - t * 0.15, 0, 0)
        }
        camNode.runAction(SCNAction.repeatForever(camTilt))
    }
}
