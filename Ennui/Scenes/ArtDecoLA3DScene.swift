// ArtDecoLA3DScene — SceneKit Art Deco LA boulevard scene.
// Buildings, palm trees, red streetcar, golden hour light, searchlight.
// Tap to sweep the searchlight.

import SwiftUI
import SceneKit

struct ArtDecoLA3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        ArtDecoLA3DRepresentable(interaction: interaction)
    }
}

private struct ArtDecoLA3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var searchlight: SCNNode?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.08, green: 0.04, blue: 0.02, alpha: 1)
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
        if let sl = c.searchlight {
            sl.removeAllActions()
            let sweep = SCNAction.rotateBy(x: 0, y: CGFloat.pi, z: 0, duration: 2.0)
            let resume = SCNAction.customAction(duration: 0) { _, _ in }
            sl.runAction(SCNAction.sequence([sweep, resume]))
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Ambient
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 0.12, green: 0.06, blue: 0.02, alpha: 1)
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Golden hour directional
        let dirNode = SCNNode()
        let dir = SCNLight(); dir.type = .directional
        dir.color = NSColor(red: 1.0, green: 0.72, blue: 0.3, alpha: 1)
        dir.intensity = 800
        dirNode.light = dir
        dirNode.eulerAngles = SCNVector3(-Float.pi / 8, Float.pi / 4, 0)
        scene.rootNode.addChildNode(dirNode)

        // Floor
        let floor = SCNFloor()
        floor.reflectivity = 0.05
        floor.firstMaterial?.diffuse.contents = NSColor(white: 0.28, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Road surface
        let road = SCNBox(width: 5, height: 0.01, length: 30, chamferRadius: 0)
        road.firstMaterial?.diffuse.contents = NSColor(white: 0.36, alpha: 1)
        let roadNode = SCNNode(geometry: road)
        roadNode.position = SCNVector3(0, 0.005, -10)
        scene.rootNode.addChildNode(roadNode)

        // Art Deco buildings
        let heights: [CGFloat] = [3, 5, 6, 4, 8]
        let widths: [CGFloat]  = [1.5, 2.0, 1.8, 1.6, 2.2]
        let zPos: [Float]      = [-3, -6, -9, -12, -15]
        for i in 0..<5 {
            for side in [-1, 1] {
                let h = heights[i]; let w = widths[i]
                let body = SCNBox(width: w, height: h, length: 1.5, chamferRadius: 0)
                let mat = SCNMaterial()
                mat.diffuse.contents = NSColor(red: 0.62, green: 0.52, blue: 0.36, alpha: 1)
                body.firstMaterial = mat
                let bNode = SCNNode(geometry: body)
                bNode.position = SCNVector3(Float(side) * 3.5, Float(h) / 2, zPos[i])
                scene.rootNode.addChildNode(bNode)

                // Windows
                for row in 0..<3 {
                    let win = SCNBox(width: 0.25, height: 0.18, length: 0.04, chamferRadius: 0)
                    let wm = SCNMaterial()
                    wm.diffuse.contents = NSColor(red: 0.95, green: 0.75, blue: 0.35, alpha: 1)
                    wm.emission.contents = NSColor(red: 0.85, green: 0.6, blue: 0.15, alpha: 1)
                    win.firstMaterial = wm
                    let wNode = SCNNode(geometry: win)
                    wNode.position = SCNVector3(0, Float(row) * 0.65 - Float(h) / 2 + 0.9, 0.77)
                    bNode.addChildNode(wNode)
                }

                // Gold cornice
                let cornice = SCNBox(width: w + 0.1, height: 0.14, length: 1.6, chamferRadius: 0)
                let cm = SCNMaterial()
                cm.diffuse.contents = NSColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 1)
                cm.emission.contents = NSColor(red: 0.4, green: 0.28, blue: 0.04, alpha: 1)
                cornice.firstMaterial = cm
                let cNode = SCNNode(geometry: cornice)
                cNode.position = SCNVector3(0, Float(h) / 2 + 0.07, 0)
                bNode.addChildNode(cNode)
            }
        }

        // Palm trees
        let palmXZ: [(Float, Float)] = [(-2.8, -4), (2.8, -7), (-2.8, -10), (2.8, -13)]
        for (px, pz) in palmXZ {
            let trunk = SCNCylinder(radius: 0.1, height: 3)
            trunk.firstMaterial?.diffuse.contents = NSColor(red: 0.52, green: 0.38, blue: 0.18, alpha: 1)
            let tNode = SCNNode(geometry: trunk)
            tNode.position = SCNVector3(px, 1.5, pz)
            scene.rootNode.addChildNode(tNode)
            for j in 0..<6 {
                let ang = Float(j) * Float.pi * 2 / 6
                let frond = SCNBox(width: 0.6, height: 0.05, length: 0.15, chamferRadius: 0)
                frond.firstMaterial?.diffuse.contents = NSColor(red: 0.2, green: 0.5, blue: 0.15, alpha: 1)
                let fNode = SCNNode(geometry: frond)
                fNode.position = SCNVector3(cos(ang) * 0.45, 1.6, sin(ang) * 0.45)
                fNode.eulerAngles = SCNVector3(0, -ang, -0.45)
                tNode.addChildNode(fNode)
            }
        }

        // Red streetcar
        let carBody = SCNBox(width: 1.0, height: 1.2, length: 3, chamferRadius: 0.05)
        let carMat = SCNMaterial()
        carMat.diffuse.contents = NSColor(red: 0.8, green: 0.1, blue: 0.08, alpha: 1)
        carBody.firstMaterial = carMat
        let carNode = SCNNode(geometry: carBody)
        carNode.position = SCNVector3(0.5, 0.6, 0)
        scene.rootNode.addChildNode(carNode)
        for k in 0..<3 {
            let cwin = SCNBox(width: 0.32, height: 0.28, length: 0.04, chamferRadius: 0)
            let cwm = SCNMaterial()
            cwm.diffuse.contents = NSColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1)
            cwm.emission.contents = NSColor(red: 0.8, green: 0.55, blue: 0.15, alpha: 1)
            cwin.firstMaterial = cwm
            let cwNode = SCNNode(geometry: cwin)
            cwNode.position = SCNVector3(0.52, 0.1, Float(k) * 0.85 - 0.85)
            carNode.addChildNode(cwNode)
        }
        let moveCar = SCNAction.customAction(duration: 20) { node, elapsed in
            node.position.z = 5 + Float(elapsed / 20) * (-25)
        }
        carNode.runAction(SCNAction.repeatForever(moveCar))

        // Search spotlight
        let slNode = SCNNode()
        slNode.position = SCNVector3(0, 15, -8)
        let sl = SCNLight(); sl.type = .spot
        sl.intensity = 500; sl.color = NSColor.white
        sl.spotInnerAngle = 4; sl.spotOuterAngle = 14
        slNode.light = sl
        slNode.eulerAngles = SCNVector3(-(Float.pi / 2) + 0.3, 0, 0)
        scene.rootNode.addChildNode(slNode)
        coord.searchlight = slNode
        let rotateSpot = SCNAction.customAction(duration: 8) { node, elapsed in
            node.eulerAngles.y = Float(elapsed / 8) * 2 * Float.pi
        }
        slNode.runAction(SCNAction.repeatForever(rotateSpot))

        // Camera drifts down boulevard
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 60; cam.zFar = 100
        camNode.camera = cam
        camNode.position = SCNVector3(0, 2.5, 5)
        camNode.eulerAngles = SCNVector3(-0.1, 0, 0)
        scene.rootNode.addChildNode(camNode)
        let driftCam = SCNAction.customAction(duration: 30) { node, elapsed in
            node.position.z = 5 - Float(elapsed / 30) * 20
        }
        camNode.runAction(SCNAction.repeatForever(driftCam))
    }
}
