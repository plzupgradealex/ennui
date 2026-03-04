// WireframeCity3DScene — Green phosphor wireframe city flyover.
// Inspired by the vector graphics sequences from early 1980s sci-fi:
// glowing green wireframe buildings on pure black, a scrolling grid
// floor, slow flythrough camera, scan-line atmosphere. The whole
// thing feels like peering into an old vector display terminal.
// Tap to pulse a radar sweep across the grid.

import SwiftUI
import SceneKit

struct WireframeCity3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        WireframeCity3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct WireframeCity3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject {
        var lastTapCount = 0
        var sweepNode: SCNNode?
        var buildingNodes: [SCNNode] = []
        var camNode: SCNNode?
        var camYaw: CGFloat = 0
        var camPitch: CGFloat = 0
        var lastDragPoint: CGPoint = .zero

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let loc = gesture.location(in: gesture.view)
            if gesture.state == .began { lastDragPoint = loc; return }
            let dx = loc.x - lastDragPoint.x
            let dy = loc.y - lastDragPoint.y
            lastDragPoint = loc
            let sensitivity: CGFloat = 0.003
            camYaw  = max(-.pi * 0.35, min(.pi * 0.35, camYaw + dx * sensitivity))
            camPitch = max(-0.3, min(0.3, camPitch + dy * sensitivity))
            camNode?.eulerAngles = SCNVector3(camPitch - 0.25, camYaw, 0)
        }
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

        buildScene(scene, coord: context.coordinator)

        let pan = NSPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount

        // Radar sweep — expand a ring outward from center
        if let sweep = c.sweepNode {
            sweep.isHidden = false
            sweep.scale = SCNVector3(0.1, 1, 0.1)
            sweep.opacity = 1.0
            sweep.runAction(SCNAction.group([
                SCNAction.scale(to: 30, duration: 2.0),
                SCNAction.sequence([
                    SCNAction.wait(duration: 0.8),
                    SCNAction.fadeOut(duration: 1.2),
                    SCNAction.customAction(duration: 0.0) { n, _ in n.isHidden = true }
                ])
            ]))
        }

        // Flash all buildings briefly
        for node in c.buildingNodes {
            node.runAction(SCNAction.sequence([
                SCNAction.customAction(duration: 0.0) { n, _ in
                    n.geometry?.firstMaterial?.emission.intensity = 2.5
                },
                SCNAction.customAction(duration: 1.5) { n, t in
                    let frac = CGFloat(t / 1.5)
                    n.geometry?.firstMaterial?.emission.intensity = 2.5 - (2.5 - 1.0) * frac
                }
            ]))
        }
    }

    // MARK: - Build scene

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor.black
        scene.fogStartDistance = 30
        scene.fogEndDistance = 60
        scene.fogColor = NSColor.black

        let green = NSColor(red: 0.15, green: 0.95, blue: 0.35, alpha: 1)
        let dimGreen = NSColor(red: 0.08, green: 0.55, blue: 0.18, alpha: 1)

        addGrid(to: scene, color: dimGreen)
        addBuildings(to: scene, color: green, coord: coord)
        addSweepRing(to: scene, color: green, coord: coord)
        addScanLineOverlay(to: scene)
        addLighting(to: scene, color: green)
        addCamera(to: scene, coord: coord)
    }

    // MARK: - Grid floor

    private func addGrid(to scene: SCNScene, color: NSColor) {
        let gridMat = SCNMaterial()
        gridMat.diffuse.contents = NSColor.clear
        gridMat.emission.contents = color
        gridMat.emission.intensity = 0.4
        gridMat.fillMode = .lines
        gridMat.isDoubleSided = true

        // Create a subdivided plane for grid lines
        let gridSize: CGFloat = 80
        let segments = 40

        let plane = SCNPlane(width: gridSize, height: gridSize)
        plane.widthSegmentCount = segments
        plane.heightSegmentCount = segments
        plane.firstMaterial = gridMat

        let gridNode = SCNNode(geometry: plane)
        gridNode.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        gridNode.position = SCNVector3(0, 0, -20)
        scene.rootNode.addChildNode(gridNode)

        // Scroll the grid toward camera for flyover effect
        gridNode.runAction(SCNAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 0, z: 20, duration: 8.0),
            .move(to: SCNVector3(0, 0, -20), duration: 0),
        ])))
    }

    // MARK: - Wireframe buildings

    private func addBuildings(to scene: SCNScene, color: NSColor, coord: Coordinator) {
        var rng = SplitMix64(seed: 1983) // the year Escape was culturally peak

        func wireMat(intensity: CGFloat = 1.0) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = NSColor.clear
            m.emission.contents = color
            m.emission.intensity = intensity
            m.fillMode = .lines
            m.isDoubleSided = true
            return m
        }

        // Rows of buildings on both sides + center
        let rows: [(xRange: ClosedRange<Double>, zRange: ClosedRange<Double>, count: Int)] = [
            (-22...(-8), -50...(-5), 14),
            (8...22,     -50...(-5), 14),
            (-5...5,     -55...(-25), 8),
        ]

        for row in rows {
            for _ in 0..<row.count {
                let x = CGFloat(Double.random(in: row.xRange, using: &rng))
                let z = CGFloat(Double.random(in: row.zRange, using: &rng))
                let h = CGFloat(Double.random(in: 1.5...12.0, using: &rng))
                let w = CGFloat(Double.random(in: 1.2...3.5, using: &rng))
                let d = CGFloat(Double.random(in: 1.2...3.0, using: &rng))

                let building = SCNNode()

                // Main box
                let box = SCNBox(width: w, height: h, length: d, chamferRadius: 0)
                box.firstMaterial = wireMat()
                let bn = SCNNode(geometry: box)
                bn.position.y = h / 2
                building.addChildNode(bn)
                coord.buildingNodes.append(bn)

                // Some buildings get a secondary structure on top
                if Double.random(in: 0...1, using: &rng) > 0.5 {
                    let topW = w * CGFloat(Double.random(in: 0.3...0.6, using: &rng))
                    let topH = CGFloat(Double.random(in: 1.0...3.0, using: &rng))
                    let topBox = SCNBox(width: topW, height: topH, length: topW, chamferRadius: 0)
                    topBox.firstMaterial = wireMat(intensity: 0.7)
                    let tn = SCNNode(geometry: topBox)
                    tn.position.y = h + topH / 2
                    building.addChildNode(tn)
                    coord.buildingNodes.append(tn)
                }

                // Occasional pyramid top (antenna tower vibe)
                if Double.random(in: 0...1, using: &rng) > 0.75 {
                    let pw = w * 0.4
                    let ph = CGFloat(Double.random(in: 2.0...5.0, using: &rng))
                    let pyr = SCNPyramid(width: pw, height: ph, length: pw)
                    pyr.firstMaterial = wireMat(intensity: 0.6)
                    let pn = SCNNode(geometry: pyr)
                    pn.position.y = h + ph * 0.1
                    building.addChildNode(pn)
                    coord.buildingNodes.append(pn)
                }

                building.position = SCNVector3(x, 0, z)
                scene.rootNode.addChildNode(building)
            }
        }

        // A few landmark-style tall spires in the distance
        for i in 0..<3 {
            let xOff: CGFloat = CGFloat(i - 1) * 10
            let h: CGFloat = CGFloat(Double.random(in: 15...22, using: &rng))
            let w: CGFloat = 2.0

            let spire = SCNBox(width: w, height: h, length: w, chamferRadius: 0)
            spire.firstMaterial = wireMat(intensity: 0.5)
            let sn = SCNNode(geometry: spire)
            sn.position = SCNVector3(xOff, h / 2, -45)
            scene.rootNode.addChildNode(sn)
            coord.buildingNodes.append(sn)

            let top = SCNPyramid(width: w * 1.2, height: 4, length: w * 1.2)
            top.firstMaterial = wireMat(intensity: 0.4)
            let tn = SCNNode(geometry: top)
            tn.position = SCNVector3(xOff, h, -45)
            scene.rootNode.addChildNode(tn)
            coord.buildingNodes.append(tn)
        }
    }

    // MARK: - Radar sweep ring (tap interaction)

    private func addSweepRing(to scene: SCNScene, color: NSColor, coord: Coordinator) {
        let ring = SCNTorus(ringRadius: 1, pipeRadius: 0.03)
        let rm = SCNMaterial()
        rm.diffuse.contents = NSColor.clear
        rm.emission.contents = color
        rm.emission.intensity = 1.5
        rm.blendMode = .add
        rm.isDoubleSided = true
        ring.firstMaterial = rm

        let node = SCNNode(geometry: ring)
        node.position = SCNVector3(0, 0.1, 0)
        node.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
        node.isHidden = true
        scene.rootNode.addChildNode(node)
        coord.sweepNode = node
    }

    // MARK: - Faint scan-line plane (close to camera)

    private func addScanLineOverlay(to scene: SCNScene) {
        // A very faint horizontal-line overlay to simulate CRT scan lines
        let overlay = SCNPlane(width: 20, height: 12)
        overlay.widthSegmentCount = 1
        overlay.heightSegmentCount = 80  // creates horizontal wireframe lines
        let om = SCNMaterial()
        om.diffuse.contents = NSColor.clear
        om.emission.contents = NSColor(red: 0.12, green: 0.90, blue: 0.30, alpha: 1)
        om.emission.intensity = 0.04
        om.fillMode = .lines
        om.isDoubleSided = true
        om.blendMode = .add
        overlay.firstMaterial = om

        let on = SCNNode(geometry: overlay)
        on.position = SCNVector3(0, 3, 2.2)
        on.renderingOrder = 100
        scene.rootNode.addChildNode(on)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene, color: NSColor) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 3
        ambient.light!.color = color
        scene.rootNode.addChildNode(ambient)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene, coord: Coordinator) {
        let cam = SCNCamera()
        cam.fieldOfView = 65
        cam.zNear = 0.1
        cam.zFar = 80
        cam.wantsHDR = true
        cam.bloomIntensity = 0.5
        cam.bloomThreshold = 0.5

        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 5, 6)
        camNode.eulerAngles = SCNVector3(-0.25, 0, 0)
        scene.rootNode.addChildNode(camNode)
        coord.camNode = camNode

        // Gentle lateral sway like you're in a helicopter
        camNode.runAction(SCNAction.repeatForever(.customAction(duration: 10.0) { n, t in
            let sway = 1.2 * sin(Double(t) * 0.63)
            let pitch = -0.25 + 0.02 * sin(Double(t) * 0.4)
            n.position.x = CGFloat(sway)
            n.eulerAngles.x = CGFloat(pitch) + coord.camPitch
            n.eulerAngles.y = coord.camYaw
        }))
    }
}
