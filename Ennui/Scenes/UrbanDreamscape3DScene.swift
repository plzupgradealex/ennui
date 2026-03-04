// UrbanDreamscape3DScene — SceneKit dreamy night city scene.
// Wet streets, neon signs, rain, puddle pulse on tap.

import SwiftUI
import SceneKit

struct UrbanDreamscape3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        UrbanDreamscape3DRepresentable(interaction: interaction)
    }
}

private struct UrbanDreamscape3DRepresentable: NSViewRepresentable {
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
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        for puddle in c.puddles {
            let expand = SCNAction.scale(to: 1.3, duration: 0.25)
            let shrink = SCNAction.scale(to: 1.0, duration: 0.25)
            puddle.runAction(SCNAction.sequence([expand, shrink]))
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Ambient purple-blue
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 0.06, green: 0.04, blue: 0.14, alpha: 1)
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Faint directional moonlight
        let moonNode = SCNNode()
        let moon = SCNLight(); moon.type = .directional
        moon.color = NSColor(red: 0.5, green: 0.5, blue: 0.7, alpha: 1)
        moon.intensity = 200
        moonNode.light = moon
        moonNode.eulerAngles = SCNVector3(-Float.pi / 5, Float.pi / 6, 0)
        scene.rootNode.addChildNode(moonNode)

        // Wet floor
        let floor = SCNFloor()
        floor.reflectivity = 0.08
        floor.firstMaterial?.diffuse.contents = NSColor(white: 0.12, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Buildings
        var rng = SplitMix64(seed: 7001)
        let windowColors: [NSColor] = [
            NSColor(red: 0.95, green: 0.85, blue: 0.5, alpha: 1),
            NSColor(red: 0.7, green: 0.4, blue: 0.9, alpha: 1)
        ]
        for _ in 0..<8 {
            let bh = CGFloat(Double.random(in: 2...10, using: &rng))
            let bw = CGFloat(Double.random(in: 1.0...2.5, using: &rng))
            let bx = Float(Double.random(in: -8...8, using: &rng))
            let bz = Float(Double.random(in: -12 ... -2, using: &rng))

            let body = SCNBox(width: bw, height: bh, length: bw * 0.7, chamferRadius: 0)
            let mat = SCNMaterial()
            let grey = Double.random(in: 0.12...0.22, using: &rng)
            mat.diffuse.contents = NSColor(white: grey, alpha: 1)
            body.firstMaterial = mat
            let bNode = SCNNode(geometry: body)
            bNode.position = SCNVector3(bx, Float(bh) / 2, bz)
            scene.rootNode.addChildNode(bNode)

            // Windows
            let winCount = Int(Double.random(in: 3...5, using: &rng))
            for w in 0..<winCount {
                let wCol = windowColors[Int(Double.random(in: 0...1.99, using: &rng))]
                let win = SCNPlane(width: 0.18, height: 0.14)
                let wm = SCNMaterial()
                wm.diffuse.contents = wCol
                wm.emission.contents = wCol
                wm.isDoubleSided = true
                win.firstMaterial = wm
                let wNode = SCNNode(geometry: win)
                let halfBh = Double(bh) / 2.0
                let halfBw = Double(bw) / 2.0
                let wy = CGFloat(Double.random(in: (-halfBh + 0.4)...(halfBh - 0.3), using: &rng))
                let wx = CGFloat(Double.random(in: (-halfBw + 0.2)...(halfBw - 0.2), using: &rng))
                wNode.position = SCNVector3(wx, wy, CGFloat(bw * 0.35) + 0.02)
                bNode.addChildNode(wNode)
            }
        }

        // Puddles
        let puddlePositions: [(Float, Float)] = [(-1, -1), (1.5, -2), (-2.5, -3), (0.5, -4), (2, -1.5)]
        for (px, pz) in puddlePositions {
            let puddle = SCNBox(width: 0.8, height: 0.005, length: 0.5, chamferRadius: 0)
            let pm = SCNMaterial()
            pm.diffuse.contents = NSColor(white: 0.04, alpha: 1)
            pm.specular.contents = NSColor(white: 0.3, alpha: 1)
            pm.shininess = 80
            puddle.firstMaterial = pm
            let pNode = SCNNode(geometry: puddle)
            pNode.position = SCNVector3(px, 0.003, pz)
            scene.rootNode.addChildNode(pNode)
            coord.puddles.append(pNode)
        }

        // Rain particles
        let rain = SCNParticleSystem()
        rain.birthRate = 120
        rain.particleLifeSpan = 1.8
        rain.particleSize = 0.02
        rain.particleColor = NSColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 0.5)
        rain.particleVelocity = 8
        rain.particleVelocityVariation = 1
        rain.emittingDirection = SCNVector3(0, -1, 0)
        rain.spreadingAngle = 5
        rain.emitterShape = SCNBox(width: 24, height: 0, length: 24, chamferRadius: 0)
        rain.isAffectedByGravity = false
        let rainNode = SCNNode()
        rainNode.position = SCNVector3(0, 12, -5)
        rainNode.addParticleSystem(rain)
        scene.rootNode.addChildNode(rainNode)

        // Neon signs
        let neonColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.15, blue: 0.6, alpha: 1),
            NSColor(red: 0.2, green: 0.9, blue: 0.9, alpha: 1),
            NSColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 1)
        ]
        let neonPos: [(Float, Float, Float)] = [(-4, 3, -2.6), (2, 2.5, -3.6), (-1, 4, -5)]
        for (idx, (nx, ny, nz)) in neonPos.enumerated() {
            let sign = SCNPlane(width: 0.8, height: 0.2)
            let sm = SCNMaterial()
            sm.diffuse.contents = neonColors[idx]
            sm.emission.contents = neonColors[idx]
            sm.isDoubleSided = true
            sign.firstMaterial = sm
            let sNode = SCNNode(geometry: sign)
            sNode.position = SCNVector3(nx, ny, nz)
            scene.rootNode.addChildNode(sNode)
        }

        // Camera orbits city
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 65; cam.zFar = 80
        camNode.camera = cam
        scene.rootNode.addChildNode(camNode)
        let orbit = SCNAction.customAction(duration: 80) { node, elapsed in
            let angle = Float(elapsed / 80) * 2 * Float.pi
            let r: Float = 6
            node.position = SCNVector3(sin(angle) * r, 3, cos(angle) * r - 5)
            node.eulerAngles = SCNVector3(-0.2, angle + Float.pi, 0)
        }
        camNode.runAction(SCNAction.repeatForever(orbit))
    }
}
