// RetroGarden3DScene — Pixel-art style low-poly garden with windmill and butterflies.

import SwiftUI
import SceneKit

struct RetroGarden3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        RetroGarden3DRepresentable(interaction: interaction)
    }
}

private struct RetroGarden3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var scene: SCNScene?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = true
        context.coordinator.scene = scene
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        guard let scene = c.scene else { return }
        var rng = SplitMix64(seed: UInt64(interaction.tapCount &* 1337 &+ 42))
        let x = Float(Double.random(in: -4...4, using: &rng))
        let z = Float(Double.random(in: -1...2, using: &rng))
        let flowerColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1),
            NSColor(red: 1.0, green: 0.6, blue: 0.7, alpha: 1),
            NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1),
            NSColor(red: 1.0, green: 0.95, blue: 0.1, alpha: 1)
        ]
        let color = flowerColors[Int(Double.random(in: 0...3.99, using: &rng))]
        let stemGeo = SCNCylinder(radius: 0.05, height: 0.8)
        stemGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.2, green: 0.7, blue: 0.1, alpha: 1)
        let stemNode = SCNNode(geometry: stemGeo)
        stemNode.position = SCNVector3(x, -0.4, z)
        stemNode.scale = SCNVector3(0.01, 0.01, 0.01)
        scene.rootNode.addChildNode(stemNode)
        let headGeo = SCNCone(topRadius: 0, bottomRadius: 0.25, height: 0.3)
        headGeo.firstMaterial?.diffuse.contents = color
        let headNode = SCNNode(geometry: headGeo)
        headNode.position = SCNVector3(0, 0.55, 0)
        stemNode.addChildNode(headNode)
        let grow = SCNAction.scale(to: 1.0, duration: 0.6)
        grow.timingMode = .easeOut
        stemNode.runAction(grow)
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Lights
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(white: 0.6, alpha: 1); amb.intensity = 400
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        let sunNode = SCNNode()
        let sun = SCNLight(); sun.type = .directional
        sun.color = NSColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1); sun.intensity = 800
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 6, 0)
        scene.rootNode.addChildNode(sunNode)

        // Floor
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.3, green: 0.7, blue: 0.2, alpha: 1)
        floor.reflectivity = 0
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Hills
        for (hx, hz) in [(-6.0, -5.0), (6.0, -5.0)] {
            let hill = SCNSphere(radius: 3)
            hill.firstMaterial?.diffuse.contents = NSColor(red: 0.25, green: 0.65, blue: 0.15, alpha: 1)
            let hNode = SCNNode(geometry: hill)
            hNode.position = SCNVector3(Float(hx), -2.5, Float(hz))
            hNode.scale = SCNVector3(1, 0.4, 1)
            scene.rootNode.addChildNode(hNode)
        }

        // 9 Flowers
        var rng = SplitMix64(seed: 5555)
        let flowerColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1),
            NSColor(red: 1.0, green: 0.6, blue: 0.7, alpha: 1),
            NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1),
            NSColor(red: 1.0, green: 0.95, blue: 0.1, alpha: 1),
            NSColor(red: 0.7, green: 0.2, blue: 0.9, alpha: 1),
            NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
        ]
        var flowerPositions: [SCNVector3] = []
        for i in 0..<9 {
            let fx = Float(Double.random(in: -4...4, using: &rng))
            let fz = Float(Double.random(in: -1...2, using: &rng))
            let color = flowerColors[i % flowerColors.count]

            let stemGeo = SCNCylinder(radius: 0.05, height: 0.8)
            stemGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.2, green: 0.7, blue: 0.1, alpha: 1)
            let stemNode = SCNNode(geometry: stemGeo)
            stemNode.position = SCNVector3(fx, 0.4, fz)
            scene.rootNode.addChildNode(stemNode)

            let headGeo = SCNCone(topRadius: 0, bottomRadius: 0.25, height: 0.3)
            headGeo.firstMaterial?.diffuse.contents = color
            let headNode = SCNNode(geometry: headGeo)
            headNode.position = SCNVector3(0, 0.55, 0)
            stemNode.addChildNode(headNode)

            flowerPositions.append(SCNVector3(fx, 1.2, fz))
        }

        // Windmill
        let wmBodyGeo = SCNCylinder(radius: 0.15, height: 3)
        wmBodyGeo.firstMaterial?.diffuse.contents = NSColor(white: 0.85, alpha: 1)
        let wmBody = SCNNode(geometry: wmBodyGeo)
        wmBody.position = SCNVector3(4, 1.5, -4)
        scene.rootNode.addChildNode(wmBody)

        let pivotNode = SCNNode()
        pivotNode.position = SCNVector3(0, 1.6, 0.16)
        wmBody.addChildNode(pivotNode)

        let bladeColors: [NSColor] = [
            NSColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1),
            NSColor(red: 0.7, green: 0.45, blue: 0.18, alpha: 1)
        ]
        for b in 0..<4 {
            let bladeGeo = SCNBox(width: 0.15, height: 1.2, length: 0.05, chamferRadius: 0)
            bladeGeo.firstMaterial?.diffuse.contents = bladeColors[b % 2]
            let bladeNode = SCNNode(geometry: bladeGeo)
            let angle = CGFloat(b) * CGFloat.pi / 2
            bladeNode.position = SCNVector3(sin(angle) * 0.65, cos(angle) * 0.65, 0)
            bladeNode.eulerAngles = SCNVector3(0, 0, angle)
            pivotNode.addChildNode(bladeNode)
        }
        let spinZ = SCNAction.repeatForever(SCNAction.rotate(by: CGFloat.pi * 2, around: SCNVector3(0, 0, 1), duration: 8))
        pivotNode.runAction(spinZ)

        // 6 Butterflies
        let butterflyColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.6, blue: 0.8, alpha: 1),
            NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1),
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1),
            NSColor(red: 1.0, green: 0.95, blue: 0.2, alpha: 1),
            NSColor(red: 0.0, green: 0.9, blue: 0.9, alpha: 1),
            NSColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 1)
        ]
        let orbitDurations: [Double] = [3.0, 4.0, 5.0, 3.5, 4.5, 6.0]
        let orbitRadii: [CGFloat] = [0.3, 0.4, 0.35, 0.5, 0.3, 0.45]

        for b in 0..<6 {
            let wingGeo = SCNBox(width: 0.2, height: 0.15, length: 0.01, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = butterflyColors[b]
            mat.isDoubleSided = true
            wingGeo.firstMaterial = mat
            let bNode = SCNNode(geometry: wingGeo)
            let flowerPos = flowerPositions[b % flowerPositions.count]
            let r = orbitRadii[b]
            let dur = orbitDurations[b]
            let yHeight = CGFloat(1.0 + Double(b) * 0.2)
            let orbit = SCNAction.customAction(duration: dur) { node, elapsed in
                let angle = CGFloat(elapsed / CGFloat(dur)) * CGFloat.pi * 2
                node.position = SCNVector3(
                    flowerPos.x + sin(angle) * r,
                    flowerPos.y + yHeight - 1.2,
                    flowerPos.z + cos(angle) * r
                )
                node.eulerAngles = SCNVector3(0, -angle, 0)
            }
            bNode.runAction(SCNAction.repeatForever(orbit))
            scene.rootNode.addChildNode(bNode)
        }

        // Camera
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 70; cam.zFar = 100
        camNode.camera = cam
        scene.rootNode.addChildNode(camNode)
        let camOrbit = SCNAction.customAction(duration: 60) { node, elapsed in
            let angle = Float(elapsed / 60) * 2 * Float.pi
            let r: Float = 10
            node.position = SCNVector3(sin(angle) * r, 3, cos(angle) * r)
            node.eulerAngles = SCNVector3(-0.25, angle + Float.pi, 0)
        }
        camNode.runAction(SCNAction.repeatForever(camOrbit))
    }
}
