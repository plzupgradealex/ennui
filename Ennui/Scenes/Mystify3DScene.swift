// Mystify3DScene — Windows 95 Mystify screensaver in 3D with bouncing emissive shapes.

import SwiftUI
import SceneKit

struct Mystify3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        Mystify3DRepresentable(interaction: interaction)
    }
}

private struct Mystify3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var shapesCount = 4
        var rootNode: SCNNode?
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
        context.coordinator.rootNode = scene.rootNode
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        guard c.shapesCount < 8, let root = c.rootNode else { return }
        let extra = min(4, 8 - c.shapesCount)
        var rng = SplitMix64(seed: UInt64(interaction.tapCount &* 3571))
        for i in 0..<extra {
            let idx = c.shapesCount + i
            addBounceShape(to: root, index: idx, seed: UInt64(idx &* 7 &+ 3), rng: &rng)
        }
        c.shapesCount += extra
    }

    private func addBounceShape(to root: SCNNode, index: Int, seed: UInt64, rng: inout SplitMix64) {
        let extraColors: [NSColor] = [
            NSColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1),
            NSColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1),
            NSColor(red: 0.8, green: 0.0, blue: 0.3, alpha: 1),
            NSColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1)
        ]
        let color = extraColors[index % extraColors.count]
        let geo: SCNGeometry
        if index % 2 == 0 {
            let box = SCNBox(width: 1.2, height: 0.9, length: 0.1, chamferRadius: 0.1)
            geo = box
        } else {
            let pyr = SCNPyramid(width: 1.0, height: 1.2, length: 0.1)
            geo = pyr
        }
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.transparency = 0.85
        mat.isDoubleSided = true
        mat.lightingModel = .constant
        geo.firstMaterial = mat
        let node = SCNNode(geometry: geo)
        root.addChildNode(node)
        let freq = CGFloat(Double.random(in: 0.4...0.9, using: &rng))
        let phaseX = CGFloat(Double.random(in: 0...Double.pi * 2, using: &rng))
        let phaseY = CGFloat(Double.random(in: 0...Double.pi * 2, using: &rng))
        let phaseZ = CGFloat(Double.random(in: 0...Double.pi * 2, using: &rng))
        let dur = Double(Double.random(in: 6...12, using: &rng))
        let bounce = SCNAction.customAction(duration: dur) { n, elapsed in
            let t = CGFloat(elapsed / CGFloat(dur)) * CGFloat.pi * 2
            let x = sin(t * freq + phaseX) * 5.0
            let y = cos(t * freq * 0.7 + phaseY) * 3.2
            let z = sin(t * freq * 0.5 + phaseZ) * 1.5
            n.position = SCNVector3(x, y, z)
            n.eulerAngles = SCNVector3(t * 0.3, t * 0.5, t * 0.2)
        }
        node.runAction(SCNAction.repeatForever(bounce))
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        let colors: [NSColor] = [
            NSColor(red: 0.0, green: 0.9, blue: 0.9, alpha: 1),
            NSColor(red: 0.9, green: 0.0, blue: 0.9, alpha: 1),
            NSColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1),
            NSColor(red: 0.1, green: 0.3, blue: 1.0, alpha: 1)
        ]
        let frequencies: [Float] = [0.6, 0.5, 0.7, 0.45]
        let phasesX: [Float] = [0.0, 1.1, 2.2, 3.3]
        let phasesY: [Float] = [0.5, 1.6, 2.7, 3.8]
        let phasesZ: [Float] = [1.0, 2.1, 3.2, 0.4]
        let durations: [Double] = [8.0, 9.5, 7.0, 11.0]

        for i in 0..<4 {
            let geo: SCNGeometry
            if i % 2 == 0 {
                let box = SCNBox(width: 1.5, height: 1.1, length: 0.1, chamferRadius: 0.1)
                geo = box
            } else {
                let pyr = SCNPyramid(width: 1.2, height: 1.4, length: 0.1)
                geo = pyr
            }
            let mat = SCNMaterial()
            mat.diffuse.contents = colors[i]
            mat.emission.contents = colors[i]
            mat.transparency = 0.85
            mat.isDoubleSided = true
            mat.lightingModel = .constant
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            scene.rootNode.addChildNode(node)

            let freq = frequencies[i]
            let phX = phasesX[i]; let phY = phasesY[i]; let phZ = phasesZ[i]
            let dur = durations[i]
            let bounce = SCNAction.customAction(duration: dur) { n, elapsed in
                let t = Float(elapsed / CGFloat(dur)) * Float.pi * 2
                let x = sin(t * freq + phX) * 5.5
                let y = cos(t * freq * 0.7 + phY) * 3.5
                let z = sin(t * freq * 0.5 + phZ) * 1.8
                n.position = SCNVector3(x, y, z)
                n.eulerAngles = SCNVector3(t * 0.25, t * 0.4, t * 0.15)
            }
            node.runAction(SCNAction.repeatForever(bounce))
        }

        // Camera with HDR bloom
        let camNode = SCNNode()
        let cam = SCNCamera()
        cam.fieldOfView = 60
        cam.zFar = 40
        cam.wantsHDR = true
        cam.bloomIntensity = 1.5
        cam.bloomThreshold = 0.5
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0, 8)
        scene.rootNode.addChildNode(camNode)
    }
}
