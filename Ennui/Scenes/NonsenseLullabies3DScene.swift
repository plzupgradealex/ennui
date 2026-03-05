// NonsenseLullabies3DScene — Watercolour nursery dreamscape with floating cats, moons, houses, stars.

import SwiftUI
import SceneKit

struct NonsenseLullabies3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        NonsenseLullabies3DRepresentable(interaction: interaction)
    }
}

private struct NonsenseLullabies3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var floatingShapes: [SCNNode] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.95, green: 0.90, blue: 0.82, alpha: 1)
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
        guard !c.floatingShapes.isEmpty else { return }
        var rng = SplitMix64(seed: UInt64(interaction.tapCount &* 1999))
        let idx = Int(Double.random(in: 0...Double(c.floatingShapes.count - 1) + 0.99, using: &rng)) % c.floatingShapes.count
        let shape = c.floatingShapes[idx]
        let grow = SCNAction.scale(to: 1.5, duration: 0.25)
        let shrink = SCNAction.scale(to: 1.0, duration: 0.25)
        shape.runAction(SCNAction.sequence([grow, shrink]))
    }

    // MARK: — Node builders

    private func makeCat(color: NSColor, emissive: NSColor) -> SCNNode {
        let root = SCNNode()
        let bodyGeo = SCNBox(width: 0.3, height: 0.25, length: 0.15, chamferRadius: 0.04)
        let mat = SCNMaterial()
        mat.diffuse.contents = color; mat.emission.contents = emissive
        bodyGeo.firstMaterial = mat
        root.addChildNode(SCNNode(geometry: bodyGeo))

        let headGeo = SCNSphere(radius: 0.12)
        headGeo.firstMaterial = mat
        let headNode = SCNNode(geometry: headGeo)
        headNode.position = SCNVector3(0.18, 0.1, 0)
        root.addChildNode(headNode)

        let earMat = SCNMaterial()
        earMat.diffuse.contents = color; earMat.emission.contents = emissive
        for side in [-1, 1] {
            let earGeo = SCNPyramid(width: 0.07, height: 0.08, length: 0.04)
            earGeo.firstMaterial = earMat
            let eNode = SCNNode(geometry: earGeo)
            eNode.position = SCNVector3(0.18 + Float(side) * 0.07, 0.21, 0)
            root.addChildNode(eNode)
        }
        return root
    }

    private func makeMoon(color: NSColor, emissive: NSColor) -> SCNNode {
        let geo = SCNSphere(radius: 0.2)
        let mat = SCNMaterial()
        mat.diffuse.contents = color; mat.emission.contents = emissive
        geo.firstMaterial = mat
        return SCNNode(geometry: geo)
    }

    private func makeHouse(color: NSColor, roofColor: NSColor, emissive: NSColor) -> SCNNode {
        let root = SCNNode()
        let bodyGeo = SCNBox(width: 0.25, height: 0.2, length: 0.2, chamferRadius: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = color; mat.emission.contents = emissive
        bodyGeo.firstMaterial = mat
        root.addChildNode(SCNNode(geometry: bodyGeo))

        let roofGeo = SCNPyramid(width: 0.28, height: 0.15, length: 0.22)
        let roofMat = SCNMaterial()
        roofMat.diffuse.contents = roofColor; roofMat.emission.contents = emissive
        roofGeo.firstMaterial = roofMat
        let roofNode = SCNNode(geometry: roofGeo)
        roofNode.position = SCNVector3(0, 0.175, 0)
        root.addChildNode(roofNode)
        return root
    }

    private func makeStar(color: NSColor, emissive: NSColor) -> SCNNode {
        let geo = SCNSphere(radius: 0.08)
        let mat = SCNMaterial()
        mat.diffuse.contents = color; mat.emission.contents = emissive
        geo.firstMaterial = mat
        return SCNNode(geometry: geo)
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Lights
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1); amb.intensity = 300
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        let dirNode = SCNNode()
        let dir = SCNLight(); dir.type = .directional
        dir.color = NSColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1); dir.intensity = 250
        dir.castsShadow = false
        dirNode.light = dir
        dirNode.eulerAngles = SCNVector3(-Float.pi / 3, 0, 0)
        scene.rootNode.addChildNode(dirNode)

        // Pastel palettes
        let pinkColor   = NSColor(red: 0.98, green: 0.72, blue: 0.80, alpha: 1)
        let lavColor    = NSColor(red: 0.78, green: 0.70, blue: 0.95, alpha: 1)
        let yellowColor = NSColor(red: 0.99, green: 0.92, blue: 0.52, alpha: 1)
        let peachColor  = NSColor(red: 0.99, green: 0.80, blue: 0.65, alpha: 1)
        let mintColor   = NSColor(red: 0.68, green: 0.95, blue: 0.82, alpha: 1)
        let softEmit    = NSColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 1)

        var rng = SplitMix64(seed: 8888)
        let bobDurations: [Double] = [2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 2.8, 3.2, 3.8,
                                       2.2, 2.6, 3.1, 3.6, 4.2, 4.8, 2.4, 3.4, 4.6, 2.9]
        let bobAmps: [Float] = [0.2, 0.3, 0.25, 0.35, 0.2, 0.4, 0.3, 0.25, 0.2, 0.35,
                                 0.3, 0.25, 0.4, 0.2, 0.3, 0.25, 0.35, 0.2, 0.3, 0.25]

        for i in 0..<20 {
            let x = Float(Double.random(in: -5...5, using: &rng))
            let y = Float(Double.random(in: -2...3, using: &rng))
            let z = Float(Double.random(in: -8 ... -3, using: &rng))
            let shapeType = i % 4
            let shapeNode: SCNNode
            switch shapeType {
            case 0:
                let c = i % 2 == 0 ? pinkColor : lavColor
                shapeNode = makeCat(color: c, emissive: softEmit)
            case 1:
                let c = i % 2 == 0 ? yellowColor : peachColor
                shapeNode = makeMoon(color: c, emissive: softEmit)
            case 2:
                let c = i % 2 == 0 ? mintColor : lavColor
                shapeNode = makeHouse(color: c, roofColor: i % 2 == 0 ? peachColor : pinkColor, emissive: softEmit)
            default:
                let c = i % 2 == 0 ? yellowColor : peachColor
                shapeNode = makeStar(color: c, emissive: softEmit)
            }

            shapeNode.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(shapeNode)
            coord.floatingShapes.append(shapeNode)

            let dur = bobDurations[i % bobDurations.count]
            let amp = bobAmps[i % bobAmps.count]
            let phase = Float(Double.random(in: 0...Double.pi * 2, using: &rng))
            let bob = SCNAction.customAction(duration: dur) { node, elapsed in
                let t = Float(elapsed / CGFloat(dur)) * Float.pi * 2 + phase
                node.position = SCNVector3(x, y + sin(t) * amp, z)
            }
            shapeNode.runAction(SCNAction.repeatForever(bob))
        }

        // Camera slow orbit with HDR
        let camNode = SCNNode()
        let cam = SCNCamera()
        cam.fieldOfView = 65
        cam.zFar = 60
        cam.wantsHDR = true
        cam.bloomIntensity = 0.5
        cam.bloomThreshold = 0.8
        camNode.camera = cam
        scene.rootNode.addChildNode(camNode)
        let orbit = SCNAction.customAction(duration: 120) { node, elapsed in
            let angle = Float(elapsed / 120) * 2 * Float.pi
            let r: Float = 9
            node.position = SCNVector3(sin(angle) * r * 0.5, 1.5, cos(angle) * r - 3)
            node.eulerAngles = SCNVector3(-0.15, angle * 0.5 + Float.pi, 0)
        }
        camNode.runAction(SCNAction.repeatForever(orbit))
    }
}
