// CelestialScrollHall3DScene — Moonlit Chinese study hall with scrolls and incense.
// Lacquered columns, hanging scrolls, lattice window, floating glyphs, incense smoke.
// Tap to release burst of glowing glyph characters.

import SwiftUI
import SceneKit

struct CelestialScrollHall3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        CelestialScrollHall3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct CelestialScrollHall3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var glyphSystem: SCNParticleSystem?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1)
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
        guard let ps = c.glyphSystem else { return }
        let oldRate = ps.birthRate
        ps.birthRate = 60
        ps.particleVelocity = 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ps.birthRate = oldRate
            ps.particleVelocity = 0.3
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1)
        scene.fogStartDistance = 10
        scene.fogEndDistance = 22
        scene.fogColor = NSColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)
        addLighting(to: scene)
        addFloor(to: scene)
        addColumns(to: scene)
        addScrolls(to: scene)
        addLatticeWindow(to: scene)
        addIncense(to: scene)
        addFloatingGlyphs(to: scene, coord: coord)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 30
        ambient.light!.color = NSColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Moonlight directional through window
        let moon = SCNNode()
        moon.light = SCNLight()
        moon.light!.type = .directional
        moon.light!.intensity = 70
        moon.light!.color = NSColor(red: 0.7, green: 0.75, blue: 0.9, alpha: 1)
        moon.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi / 8, 0)
        scene.rootNode.addChildNode(moon)

        // Candle point lights
        let candlePositions: [(Float, Float, Float)] = [(-2.0, 0.5, -1.0), (2.0, 0.5, -1.0)]
        for (x, y, z) in candlePositions {
            let candle = SCNNode()
            candle.light = SCNLight()
            candle.light!.type = .omni
            candle.light!.intensity = 90
            candle.light!.color = NSColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 1)
            candle.light!.attenuationStartDistance = 0.3
            candle.light!.attenuationEndDistance = 5.0
            candle.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(candle)
        }
    }

    // MARK: - Floor

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.04
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.18, green: 0.10, blue: 0.06, alpha: 1)
        floor.materials = [mat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))
    }

    // MARK: - Columns

    private func addColumns(to scene: SCNScene) {
        let colMat = SCNMaterial()
        colMat.diffuse.contents = NSColor(red: 0.45, green: 0.12, blue: 0.08, alpha: 1)
        colMat.shininess = 40
        let positions: [(Float, Float)] = [(-2.5, -3.0), (2.5, -3.0), (-2.5, 1.0), (2.5, 1.0)]
        for (x, z) in positions {
            let cyl = SCNCylinder(radius: 0.15, height: 3.5)
            cyl.materials = [colMat]
            let node = SCNNode(geometry: cyl)
            node.position = SCNVector3(x, 1.75, z)
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Hanging Scrolls

    private func addScrolls(to scene: SCNScene) {
        var rng = SplitMix64(seed: 8888)
        let scrollZ: [Float] = [-4.0, -5.5, -3.0, -6.5]
        let scrollX: [Float] = [-1.5, -0.5, 0.5, 1.5]
        for i in 0..<4 {
            let scroll = SCNPlane(width: 0.4, height: 1.2)
            let mat = SCNMaterial()
            let ivory: CGFloat = CGFloat(0.92 + rng.nextDouble() * 0.05)
            mat.diffuse.contents = NSColor(red: ivory, green: ivory * 0.95, blue: ivory * 0.85, alpha: 1)
            mat.emission.contents = NSColor(red: 0.8, green: 0.7, blue: 0.3, alpha: 0.25)
            mat.isDoubleSided = true
            scroll.materials = [mat]
            let scrollNode = SCNNode(geometry: scroll)
            scrollNode.position = SCNVector3(scrollX[i], 2.0, scrollZ[i])
            scene.rootNode.addChildNode(scrollNode)
        }
    }

    // MARK: - Lattice Window

    private func addLatticeWindow(to scene: SCNScene) {
        let latticeMat = SCNMaterial()
        latticeMat.diffuse.contents = NSColor(red: 0.25, green: 0.14, blue: 0.07, alpha: 1)
        // 12 thin rods arranged in a 4x3 grid pattern
        for col in 0..<4 {
            let bar = SCNBox(width: 0.02, height: 1.5, length: 0.02, chamferRadius: 0)
            bar.materials = [latticeMat]
            let node = SCNNode(geometry: bar)
            node.position = SCNVector3(Float(col) * 0.3 - 0.45, 2.2, -8.0)
            scene.rootNode.addChildNode(node)
        }
        for row in 0..<3 {
            let bar = SCNBox(width: 1.2, height: 0.02, length: 0.02, chamferRadius: 0)
            bar.materials = [latticeMat]
            let node = SCNNode(geometry: bar)
            node.position = SCNVector3(0, 1.5 + Float(row) * 0.5, -8.0)
            scene.rootNode.addChildNode(node)
        }
        // Moonlight glow behind window
        let glowPlane = SCNPlane(width: 1.4, height: 1.6)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = NSColor(red: 0.5, green: 0.55, blue: 0.75, alpha: 0.3)
        glowMat.emission.contents = NSColor(red: 0.3, green: 0.35, blue: 0.55, alpha: 1)
        glowMat.isDoubleSided = true
        glowPlane.materials = [glowMat]
        let glowNode = SCNNode(geometry: glowPlane)
        glowNode.position = SCNVector3(0, 2.2, -8.1)
        scene.rootNode.addChildNode(glowNode)
    }

    // MARK: - Incense

    private func addIncense(to scene: SCNScene) {
        let ps = SCNParticleSystem()
        ps.birthRate = 4
        ps.particleLifeSpan = 5.0
        ps.particleLifeSpanVariation = 2.0
        ps.emitterShape = SCNSphere(radius: 0.05)
        ps.particleSize = 0.04
        ps.particleSizeVariation = 0.02
        ps.particleColor = NSColor(red: 0.9, green: 0.88, blue: 0.85, alpha: 0.5)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.25
        ps.particleVelocityVariation = 0.1
        ps.spreadingAngle = 20
        let incenseNode = SCNNode()
        incenseNode.position = SCNVector3(0, 0.3, -2.0)
        scene.rootNode.addChildNode(incenseNode)
        incenseNode.addParticleSystem(ps)
    }

    // MARK: - Floating Glyphs

    private func addFloatingGlyphs(to scene: SCNScene, coord: Coordinator) {
        var rng = SplitMix64(seed: 9999)
        // Main glyph particle system
        let ps = SCNParticleSystem()
        ps.birthRate = 3
        ps.particleLifeSpan = 6.0
        ps.emitterShape = SCNBox(width: 4, height: 0.5, length: 4, chamferRadius: 0)
        ps.particleSize = 0.08
        ps.particleColor = NSColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.3
        ps.spreadingAngle = 30
        let psNode = SCNNode()
        psNode.position = SCNVector3(0, 1.0, -3.0)
        scene.rootNode.addChildNode(psNode)
        psNode.addParticleSystem(ps)
        coord.glyphSystem = ps

        // Individual billboard glyph nodes
        for _ in 0..<12 {
            let plane = SCNPlane(width: 0.12, height: 0.12)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: 1.0, green: 0.88, blue: 0.3, alpha: 1)
            mat.emission.contents = NSColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 1)
            mat.isDoubleSided = true
            plane.materials = [mat]
            let node = SCNNode(geometry: plane)
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            node.constraints = [constraint]
            let x = Float(rng.nextDouble() * 6 - 3)
            let y = Float(rng.nextDouble() * 2.0 + 0.8)
            let z = Float(rng.nextDouble() * -7 - 1)
            node.position = SCNVector3(x, y, z)
            let floatUp = SCNAction.moveBy(x: 0, y: 1.2, z: 0, duration: 5.0 + rng.nextDouble() * 4.0)
            let fadeOut = SCNAction.fadeOut(duration: 0.4)
            let reset = SCNAction.customAction(duration: 0) { n, _ in n.position = SCNVector3(x, y, z) }
            let fadeIn = SCNAction.fadeIn(duration: 0.4)
            node.runAction(SCNAction.repeatForever(SCNAction.sequence([floatUp, fadeOut, reset, fadeIn])))
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 1.5, 0)
        scene.rootNode.addChildNode(pivot)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 25
        cameraNode.camera!.fieldOfView = 65
        cameraNode.position = SCNVector3(0, 0.5, 8)
        cameraNode.eulerAngles = SCNVector3(-0.06, 0, 0)
        pivot.addChildNode(cameraNode)

        let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 90)
        pivot.runAction(SCNAction.repeatForever(orbit))
    }
}
