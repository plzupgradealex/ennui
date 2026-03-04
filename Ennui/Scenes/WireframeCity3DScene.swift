// WireframeCity3DScene — Green phosphor wireframe city flyover.
// Inspired by vector graphics from early 1980s sci-fi and CAD terminals:
// glowing green wireframe buildings on pure black, a scrolling grid floor,
// slow camera orbit, scan-line atmosphere, and a simple HUD strip.
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
        view.allowsCameraControl = true

        buildScene(scene, coord: context.coordinator)
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
            sweep.runAction(.group([
                .scale(to: 25, duration: 2.0),
                .sequence([
                    .wait(duration: 0.8),
                    .fadeOut(duration: 1.2),
                    .customAction(duration: 0.0) { n, _ in n.isHidden = true }
                ])
            ]))
        }

        // Flash all buildings briefly
        for node in c.buildingNodes {
            node.runAction(.sequence([
                .customAction(duration: 0.0) { n, _ in
                    n.geometry?.firstMaterial?.emission.intensity = 3.0
                },
                .customAction(duration: 1.5) { n, t in
                    let frac = CGFloat(t / 1.5)
                    n.geometry?.firstMaterial?.emission.intensity = 3.0 - 2.0 * frac
                }
            ]))
        }
    }

    // MARK: - Material helper

    private func wireMat(_ color: NSColor, intensity: CGFloat = 1.0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = color
        m.emission.contents = color
        m.emission.intensity = intensity
        m.fillMode = .lines
        m.isDoubleSided = true
        m.blendMode = .add
        return m
    }

    private func solidMat(_ color: NSColor, intensity: CGFloat = 1.0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = color
        m.emission.contents = color
        m.emission.intensity = intensity
        m.isDoubleSided = true
        m.blendMode = .add
        return m
    }

    // MARK: - Build scene

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor.black

        let green = NSColor(red: 0.12, green: 0.92, blue: 0.30, alpha: 1)
        let dimGreen = NSColor(red: 0.06, green: 0.50, blue: 0.15, alpha: 1)
        let faintGreen = NSColor(red: 0.04, green: 0.28, blue: 0.08, alpha: 1)

        addGrid(to: scene, color: dimGreen)
        addBuildings(to: scene, color: green, dimColor: dimGreen, coord: coord)
        addSweepRing(to: scene, color: green, coord: coord)
        addHUDElements(to: scene, color: dimGreen, faint: faintGreen)
        addScanLines(to: scene, color: faintGreen)
        addCamera(to: scene)

        // Fog fades distant buildings to black
        scene.fogStartDistance = 25
        scene.fogEndDistance = 55
        scene.fogColor = NSColor.black
        scene.fogDensityExponent = 1.5
    }

    // MARK: - Grid floor

    private func addGrid(to scene: SCNScene, color: NSColor) {
        let gridSize: CGFloat = 80
        let segments = 40

        let plane = SCNPlane(width: gridSize, height: gridSize)
        plane.widthSegmentCount = segments
        plane.heightSegmentCount = segments
        plane.firstMaterial = wireMat(color, intensity: 0.6)

        let gridNode = SCNNode(geometry: plane)
        gridNode.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        gridNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(gridNode)

        // Scroll grid toward camera for flyover feel
        let scrollDist: CGFloat = 2.0 // one cell width (80/40 = 2)
        gridNode.runAction(.repeatForever(.sequence([
            .moveBy(x: 0, y: 0, z: scrollDist, duration: 2.0),
            .moveBy(x: 0, y: 0, z: -scrollDist, duration: 0.0),
        ])))
    }

    // MARK: - Wireframe buildings

    private func addBuildings(to scene: SCNScene, color: NSColor, dimColor: NSColor, coord: Coordinator) {
        var rng = SplitMix64(seed: 1983)

        // Building clusters
        let clusters: [(xMin: Double, xMax: Double, zMin: Double, zMax: Double, count: Int)] = [
            (-18, -4, -40, -4, 16),   // left side
            (4, 18,   -40, -4, 16),   // right side
            (-6, 6,   -45, -20, 10),  // center back
            (-3, 3,   -12, -5, 5),    // center close
        ]

        for cluster in clusters {
            for _ in 0..<cluster.count {
                let x = CGFloat(Double.random(in: cluster.xMin...cluster.xMax, using: &rng))
                let z = CGFloat(Double.random(in: cluster.zMin...cluster.zMax, using: &rng))
                let h = CGFloat(Double.random(in: 1.5...10.0, using: &rng))
                let w = CGFloat(Double.random(in: 1.0...3.0, using: &rng))
                let d = CGFloat(Double.random(in: 1.0...2.5, using: &rng))

                let bldg = SCNNode()

                // Distance fading — farther buildings are dimmer
                let dist = abs(z)
                let brightness: CGFloat = dist > 30 ? 0.5 : dist > 18 ? 0.7 : 1.0
                let mat = wireMat(color, intensity: brightness)

                // Main box
                let box = SCNBox(width: w, height: h, length: d, chamferRadius: 0)
                box.firstMaterial = mat
                let bn = SCNNode(geometry: box)
                bn.position.y = h / 2
                bldg.addChildNode(bn)
                coord.buildingNodes.append(bn)

                // Some buildings get a narrower tower on top
                if nextDouble(&rng) > 0.55 {
                    let topW = w * CGFloat(0.3 + nextDouble(&rng) * 0.3)
                    let topH = CGFloat(1.0 + nextDouble(&rng) * 3.0)
                    let topBox = SCNBox(width: topW, height: topH, length: topW, chamferRadius: 0)
                    topBox.firstMaterial = wireMat(color, intensity: brightness * 0.7)
                    let tn = SCNNode(geometry: topBox)
                    tn.position.y = h + topH / 2
                    bldg.addChildNode(tn)
                    coord.buildingNodes.append(tn)
                }

                // Antenna spires on some
                if nextDouble(&rng) > 0.78 {
                    let spireH = CGFloat(2.0 + nextDouble(&rng) * 4.0)
                    let spire = SCNCylinder(radius: 0.04, height: spireH)
                    spire.firstMaterial = wireMat(color, intensity: brightness * 0.6)
                    let sn = SCNNode(geometry: spire)
                    sn.position.y = h + spireH / 2
                    bldg.addChildNode(sn)
                    coord.buildingNodes.append(sn)
                }

                bldg.position = SCNVector3(x, 0, z)
                scene.rootNode.addChildNode(bldg)
            }
        }

        // Landmark spires in the far distance
        for i in 0..<4 {
            let xOff = CGFloat(Double(i - 2) * 8 + nextDouble(&rng) * 3)
            let h = CGFloat(14.0 + nextDouble(&rng) * 8.0)
            let w: CGFloat = 1.8

            let spire = SCNBox(width: w, height: h, length: w, chamferRadius: 0)
            spire.firstMaterial = wireMat(color, intensity: 0.45)
            let sn = SCNNode(geometry: spire)
            sn.position = SCNVector3(xOff, h / 2, -42)
            scene.rootNode.addChildNode(sn)
            coord.buildingNodes.append(sn)

            // Pyramid cap
            let cap = SCNPyramid(width: w * 1.3, height: 3, length: w * 1.3)
            cap.firstMaterial = wireMat(color, intensity: 0.35)
            let cn = SCNNode(geometry: cap)
            cn.position = SCNVector3(xOff, h, -42)
            scene.rootNode.addChildNode(cn)
            coord.buildingNodes.append(cn)
        }
    }

    // MARK: - Radar sweep ring

    private func addSweepRing(to scene: SCNScene, color: NSColor, coord: Coordinator) {
        let ring = SCNTorus(ringRadius: 1, pipeRadius: 0.05)
        ring.firstMaterial = solidMat(color, intensity: 2.0)

        let node = SCNNode(geometry: ring)
        node.position = SCNVector3(0, 0.2, -15)
        node.isHidden = true
        scene.rootNode.addChildNode(node)
        coord.sweepNode = node
    }

    // MARK: - HUD elements at edges

    private func addHUDElements(to scene: SCNScene, color: NSColor, faint: NSColor) {
        // Bottom-left: small bar chart (like the reference)
        var rng = SplitMix64(seed: 4646)
        let barGroup = SCNNode()
        for i in 0..<8 {
            let bh = CGFloat(0.1 + nextDouble(&rng) * 0.4)
            let bar = SCNBox(width: 0.12, height: bh, length: 0.02, chamferRadius: 0)
            bar.firstMaterial = solidMat(color, intensity: 0.5)
            let bn = SCNNode(geometry: bar)
            bn.position = SCNVector3(CGFloat(i) * 0.16, bh / 2, 0)
            barGroup.addChildNode(bn)
        }
        barGroup.position = SCNVector3(-6.5, -2.8, 2)
        scene.rootNode.addChildNode(barGroup)

        // Bottom-right: readout blocks
        for i in 0..<6 {
            let block = SCNBox(width: 0.3, height: 0.08, length: 0.01, chamferRadius: 0)
            block.firstMaterial = solidMat(faint, intensity: 0.4)
            let bn = SCNNode(geometry: block)
            bn.position = SCNVector3(4.5 + CGFloat(i) * 0.4, -2.9, 2)
            scene.rootNode.addChildNode(bn)
        }

        // Top border line
        let topLine = SCNBox(width: 16, height: 0.02, length: 0.01, chamferRadius: 0)
        topLine.firstMaterial = solidMat(faint, intensity: 0.35)
        let tln = SCNNode(geometry: topLine)
        tln.position = SCNVector3(0, 4.5, 2)
        scene.rootNode.addChildNode(tln)

        // Bottom border line
        let botLine = SCNBox(width: 16, height: 0.02, length: 0.01, chamferRadius: 0)
        botLine.firstMaterial = solidMat(faint, intensity: 0.35)
        let bln = SCNNode(geometry: botLine)
        bln.position = SCNVector3(0, -3.2, 2)
        scene.rootNode.addChildNode(bln)

        // Side vertical border lines
        for side in [-8.0, 8.0] as [CGFloat] {
            let sideLine = SCNBox(width: 0.02, height: 8, length: 0.01, chamferRadius: 0)
            sideLine.firstMaterial = solidMat(faint, intensity: 0.25)
            let sn = SCNNode(geometry: sideLine)
            sn.position = SCNVector3(side, 0.6, 2)
            scene.rootNode.addChildNode(sn)
        }

        // Small crosshair in center-upper area
        let chH = SCNBox(width: 0.6, height: 0.015, length: 0.01, chamferRadius: 0)
        chH.firstMaterial = solidMat(color, intensity: 0.4)
        let chHN = SCNNode(geometry: chH)
        chHN.position = SCNVector3(0, 2.0, 2)
        scene.rootNode.addChildNode(chHN)

        let chV = SCNBox(width: 0.015, height: 0.6, length: 0.01, chamferRadius: 0)
        chV.firstMaterial = solidMat(color, intensity: 0.4)
        let chVN = SCNNode(geometry: chV)
        chVN.position = SCNVector3(0, 2.0, 2)
        scene.rootNode.addChildNode(chVN)
    }

    // MARK: - Scan lines overlay

    private func addScanLines(to scene: SCNScene, color: NSColor) {
        let overlay = SCNPlane(width: 20, height: 12)
        overlay.widthSegmentCount = 1
        overlay.heightSegmentCount = 120
        let om = SCNMaterial()
        om.lightingModel = .constant
        om.diffuse.contents = NSColor.clear
        om.emission.contents = color
        om.emission.intensity = 0.03
        om.fillMode = .lines
        om.isDoubleSided = true
        om.blendMode = .add
        overlay.firstMaterial = om

        let on = SCNNode(geometry: overlay)
        on.position = SCNVector3(0, 0.6, 2.5)
        on.renderingOrder = 200
        scene.rootNode.addChildNode(on)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cam = SCNCamera()
        cam.fieldOfView = 60
        cam.zNear = 0.1
        cam.zFar = 80
        cam.wantsHDR = true
        cam.bloomIntensity = 0.6
        cam.bloomThreshold = 0.4
        cam.bloomBlurRadius = 4
        cam.vignettingIntensity = 0.5
        cam.vignettingPower = 1.5

        let camNode = SCNNode()
        camNode.camera = cam
        // Start elevated, looking down at the city
        camNode.position = SCNVector3(0, 8, 4)
        camNode.eulerAngles = SCNVector3(-0.35, 0, 0)
        scene.rootNode.addChildNode(camNode)

        // Slow orbit: gentle lateral sway + height breathing
        let orbit = SCNAction.repeatForever(.customAction(duration: 60.0) { n, elapsed in
            let t = Double(elapsed)
            let sway = 3.0 * sin(t * 0.105)       // lateral drift
            let hBreathe = 0.8 * sin(t * 0.08)     // height breathing
            let pitch = -0.35 + 0.04 * sin(t * 0.06)
            let yaw = 0.08 * sin(t * 0.052)
            n.position = SCNVector3(CGFloat(sway), CGFloat(8.0 + hBreathe), 4.0)
            n.eulerAngles = SCNVector3(CGFloat(pitch), CGFloat(yaw), 0)
        })
        camNode.runAction(orbit)
    }
}
