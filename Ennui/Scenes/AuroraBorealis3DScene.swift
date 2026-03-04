// AuroraBorealis3DScene — SceneKit aurora over frozen lake scene.
// Pine trees, aurora curtains, stars, moon, frozen lake.
// Tap to briefly boost aurora emission (solar flare).

import SwiftUI
import SceneKit

struct AuroraBorealis3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        AuroraBorealis3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct AuroraBorealis3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var auroraMaterials: [SCNMaterial] = []
        var auroraBaseColors: [NSColor] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = false
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount

        // Solar flare: boost aurora emission to near-white then fade back
        for (i, mat) in c.auroraMaterials.enumerated() {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            mat.emission.contents = NSColor(white: 0.9, alpha: 1)
            SCNTransaction.commit()

            let base = i < c.auroraBaseColors.count ? c.auroraBaseColors[i] : NSColor.green
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(i) * 0.05) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                mat.emission.contents = base
                SCNTransaction.commit()
            }
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
        addLighting(to: scene)
        addFloor(to: scene)
        addFrozenLake(to: scene)
        addPineTrees(to: scene)
        addAurora(to: scene, coord: coord)
        addStarField(to: scene)
        addMoon(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 20
        ambient.light!.color = NSColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Blue-white directional (moonlight)
        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light!.type = .directional
        dirLight.light!.intensity = 100
        dirLight.light!.color = NSColor(red: 0.65, green: 0.72, blue: 0.95, alpha: 1)
        dirLight.light!.castsShadow = true
        dirLight.light!.shadowRadius = 4
        dirLight.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 8, 0)
        scene.rootNode.addChildNode(dirLight)
    }

    // MARK: - Floor (snow)

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1)
        mat.lightingModel = .lambert
        floor.firstMaterial = mat
        floor.reflectivity = 0.05
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }

    // MARK: - Frozen lake

    private func addFrozenLake(to scene: SCNScene) {
        let geo = SCNBox(width: 14, height: 0.05, length: 10, chamferRadius: 0)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.78, green: 0.88, blue: 0.95, alpha: 1)
        mat.specular.contents = NSColor.white
        mat.shininess = 80
        mat.lightingModel = .phong
        mat.transparency = 0.15
        geo.firstMaterial = mat
        let lakeNode = SCNNode(geometry: geo)
        lakeNode.position = SCNVector3(0, 0.02, -4)
        scene.rootNode.addChildNode(lakeNode)
    }

    // MARK: - Pine trees

    private func addPineTrees(to scene: SCNScene) {
        var rng = SplitMix64(seed: 4001)

        let trunkMat = SCNMaterial()
        trunkMat.diffuse.contents = NSColor(red: 0.35, green: 0.22, blue: 0.1, alpha: 1)
        trunkMat.lightingModel = .lambert

        let foliageMat = SCNMaterial()
        foliageMat.diffuse.contents = NSColor(red: 0.08, green: 0.28, blue: 0.12, alpha: 1)
        foliageMat.lightingModel = .lambert

        for _ in 0..<10 {
            let x = Float(Double.random(in: -7...7, using: &rng))
            let z = Float(Double.random(in: -1...2, using: &rng))
            let scale = Float(Double.random(in: 0.7...1.3, using: &rng))

            let treeNode = SCNNode()
            treeNode.position = SCNVector3(x, 0, z)

            // Trunk
            let trunkGeo = SCNCylinder(radius: CGFloat(0.12 * scale), height: CGFloat(0.8 * scale))
            trunkGeo.firstMaterial = trunkMat
            let trunkNode = SCNNode(geometry: trunkGeo)
            trunkNode.position = SCNVector3(0, 0.4 * scale, 0)
            treeNode.addChildNode(trunkNode)

            // Foliage cone
            let coneGeo = SCNCone(topRadius: 0, bottomRadius: CGFloat(0.8 * scale), height: CGFloat(3 * scale))
            coneGeo.firstMaterial = foliageMat
            let coneNode = SCNNode(geometry: coneGeo)
            coneNode.position = SCNVector3(0, (0.8 + 1.5) * scale, 0)
            treeNode.addChildNode(coneNode)

            scene.rootNode.addChildNode(treeNode)
        }
    }

    // MARK: - Aurora curtains

    private func addAurora(to scene: SCNScene, coord: Coordinator) {
        let configs: [(SCNVector3, NSColor)] = [
            (SCNVector3(0,  6, -18), NSColor(red: 0.0, green: 0.85, blue: 0.4, alpha: 1)),
            (SCNVector3(-6, 7, -16), NSColor(red: 0.6, green: 0.0, blue: 0.9, alpha: 1)),
            (SCNVector3(6,  5, -16), NSColor(red: 0.0, green: 0.7, blue: 0.75, alpha: 1)),
            (SCNVector3(2,  8, -20), NSColor(red: 0.3, green: 0.0, blue: 0.8, alpha: 1)),
        ]

        for (i, cfg) in configs.enumerated() {
            let (pos, color) = cfg
            let geo = SCNPlane(width: 15, height: 6)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor.black
            mat.emission.contents = color
            mat.lightingModel = .constant
            mat.transparency = 0.7
            mat.isDoubleSided = true
            mat.blendMode = .add
            mat.writesToDepthBuffer = false
            geo.firstMaterial = mat

            let node = SCNNode(geometry: geo)
            node.position = pos
            scene.rootNode.addChildNode(node)

            coord.auroraMaterials.append(mat)
            coord.auroraBaseColors.append(color)

            // Ripple: y position oscillation
            let ripple = CABasicAnimation(keyPath: "position.y")
            ripple.fromValue = pos.y - 0.5
            ripple.toValue = pos.y + 0.5
            ripple.duration = 4.0 + Double(i) * 0.8
            ripple.autoreverses = true
            ripple.repeatCount = .infinity
            ripple.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.addAnimation(ripple, forKey: "ripple\(i)")

            // Slight scale shimmer
            let shimmer = CABasicAnimation(keyPath: "scale.x")
            shimmer.fromValue = Float(0.95)
            shimmer.toValue = Float(1.05)
            shimmer.duration = 3.0 + Double(i) * 0.6
            shimmer.autoreverses = true
            shimmer.repeatCount = .infinity
            shimmer.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.addAnimation(shimmer, forKey: "shimmer\(i)")
        }
    }

    // MARK: - Star field

    private func addStarField(to scene: SCNScene) {
        var rng = SplitMix64(seed: 4002)
        for _ in 0..<120 {
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            let phi   = Double.random(in: 0.1...(Double.pi / 2), using: &rng)
            let r     = Double.random(in: 18...25, using: &rng)
            let x = Float(r * sin(phi) * cos(theta))
            let y = Float(abs(r * cos(phi))) + 4
            let z = Float(r * sin(phi) * sin(theta))

            let planeGeo = SCNPlane(width: 0.04, height: 0.04)
            let mat = SCNMaterial()
            let brightness = Double.random(in: 0.4...1.0, using: &rng)
            mat.emission.contents = NSColor(white: brightness, alpha: 1)
            mat.diffuse.contents = NSColor.black
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            planeGeo.firstMaterial = mat

            let starNode = SCNNode(geometry: planeGeo)
            starNode.position = SCNVector3(x, y, z)
            let bill = SCNBillboardConstraint()
            bill.freeAxes = .all
            starNode.constraints = [bill]
            scene.rootNode.addChildNode(starNode)
        }
    }

    // MARK: - Moon

    private func addMoon(to scene: SCNScene) {
        let geo = SCNSphere(radius: 1.2)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.92, green: 0.92, blue: 0.95, alpha: 1)
        mat.emission.contents = NSColor(red: 0.8, green: 0.8, blue: 0.85, alpha: 1)
        mat.lightingModel = .constant
        geo.firstMaterial = mat
        let moonNode = SCNNode(geometry: geo)
        moonNode.position = SCNVector3(8, 18, -20)
        scene.rootNode.addChildNode(moonNode)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.fieldOfView = 68
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 100
        cameraNode.position = SCNVector3(0, 3, 10)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 12, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Slow x-axis oscillation pan
        let pan = CABasicAnimation(keyPath: "position.x")
        pan.fromValue = Float(-4)
        pan.toValue = Float(4)
        pan.duration = 120
        pan.autoreverses = true
        pan.repeatCount = .infinity
        pan.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.addAnimation(pan, forKey: "camPan")
    }
}
