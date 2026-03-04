// MinnesotaSmallTown3DScene — SceneKit Minnesota prairie town.
// Church, water tower, grain elevator, diner with neon, fireflies, stars.
// Tap to burst fireflies.

import SwiftUI
import SceneKit

struct MinnesotaSmallTown3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        MinnesotaSmallTown3DRepresentable(interaction: interaction)
    }
}

private struct MinnesotaSmallTown3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var fireflySystem: SCNParticleSystem?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1)
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
        if let fs = c.fireflySystem {
            let orig = fs.birthRate
            fs.birthRate = 55
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                fs.birthRate = orig
            }
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Warm evening directional
        let dirNode = SCNNode()
        let dir = SCNLight(); dir.type = .directional
        dir.color = NSColor(red: 0.95, green: 0.75, blue: 0.45, alpha: 1)
        dir.intensity = 600
        dirNode.light = dir
        dirNode.eulerAngles = SCNVector3(-Float.pi / 9, Float.pi / 6, 0)
        scene.rootNode.addChildNode(dirNode)

        // Blue ambient
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 0.05, green: 0.06, blue: 0.15, alpha: 1)
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Grey Main Street floor
        let floor = SCNFloor()
        floor.reflectivity = 0.03
        floor.firstMaterial?.diffuse.contents = NSColor(white: 0.32, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Church body
        let church = SCNBox(width: 2, height: 2.5, length: 2, chamferRadius: 0)
        church.firstMaterial?.diffuse.contents = NSColor(white: 0.92, alpha: 1)
        let churchNode = SCNNode(geometry: church)
        churchNode.position = SCNVector3(-6, 1.25, -3)
        scene.rootNode.addChildNode(churchNode)

        // Church steeple cylinder
        let steeple = SCNCylinder(radius: 0.15, height: 3)
        steeple.firstMaterial?.diffuse.contents = NSColor(white: 0.9, alpha: 1)
        let steepleNode = SCNNode(geometry: steeple)
        steepleNode.position = SCNVector3(-6, 4.0, -3)
        scene.rootNode.addChildNode(steepleNode)

        // Steeple cap
        let cap = SCNPyramid(width: 0.4, height: 0.5, length: 0.4)
        cap.firstMaterial?.diffuse.contents = NSColor(white: 0.75, alpha: 1)
        let capNode = SCNNode(geometry: cap)
        capNode.position = SCNVector3(-6, 5.75, -3)
        scene.rootNode.addChildNode(capNode)

        // Church window
        let cwin = SCNBox(width: 0.4, height: 0.7, length: 0.04, chamferRadius: 0)
        let cwm = SCNMaterial()
        cwm.diffuse.contents = NSColor(red: 1.0, green: 0.88, blue: 0.5, alpha: 1)
        cwm.emission.contents = NSColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1)
        cwin.firstMaterial = cwm
        let cwinNode = SCNNode(geometry: cwin)
        cwinNode.position = SCNVector3(-6, 1.4, -1.98)
        scene.rootNode.addChildNode(cwinNode)

        // Water tower tank
        let tank = SCNCylinder(radius: 0.8, height: 1.2)
        tank.firstMaterial?.diffuse.contents = NSColor(white: 0.55, alpha: 1)
        let tankNode = SCNNode(geometry: tank)
        tankNode.position = SCNVector3(3, 2.6, -5)
        scene.rootNode.addChildNode(tankNode)

        // Water tower legs (6)
        for k in 0..<6 {
            let ang = Float(k) * Float.pi * 2 / 6
            let leg = SCNCylinder(radius: 0.05, height: 2)
            leg.firstMaterial?.diffuse.contents = NSColor(white: 0.4, alpha: 1)
            let lNode = SCNNode(geometry: leg)
            lNode.position = SCNVector3(3 + cos(ang) * 0.6, 1.0, -5 + sin(ang) * 0.6)
            scene.rootNode.addChildNode(lNode)
        }

        // Grain elevator
        let elevator = SCNBox(width: 1.5, height: 5, length: 1.5, chamferRadius: 0)
        elevator.firstMaterial?.diffuse.contents = NSColor(white: 0.72, alpha: 1)
        let elevNode = SCNNode(geometry: elevator)
        elevNode.position = SCNVector3(6, 2.5, -4)
        scene.rootNode.addChildNode(elevNode)

        // Elevator roof
        let elevRoof = SCNPyramid(width: 1.7, height: 0.6, length: 1.7)
        elevRoof.firstMaterial?.diffuse.contents = NSColor(white: 0.5, alpha: 1)
        let erNode = SCNNode(geometry: elevRoof)
        erNode.position = SCNVector3(6, 5.3, -4)
        scene.rootNode.addChildNode(erNode)

        // Diner body
        let diner = SCNBox(width: 2.5, height: 1.5, length: 1.5, chamferRadius: 0)
        diner.firstMaterial?.diffuse.contents = NSColor(red: 0.96, green: 0.93, blue: 0.82, alpha: 1)
        let dinerNode = SCNNode(geometry: diner)
        dinerNode.position = SCNVector3(-2, 0.75, -3)
        scene.rootNode.addChildNode(dinerNode)

        // Diner neon sign with flicker
        let neon = SCNPlane(width: 1.0, height: 0.25)
        let nm = SCNMaterial()
        nm.diffuse.contents = NSColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1)
        nm.emission.contents = NSColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1)
        nm.isDoubleSided = true
        neon.firstMaterial = nm
        let neonNode = SCNNode(geometry: neon)
        neonNode.position = SCNVector3(-2, 1.65, -2.24)
        scene.rootNode.addChildNode(neonNode)
        // Flicker
        let flicker = SCNAction.customAction(duration: 3) { node, elapsed in
            let phase = sin(Float(elapsed) * 12) + sin(Float(elapsed) * 17)
            node.opacity = phase > 0 ? 1.0 : 0.2
        }
        neonNode.runAction(SCNAction.repeatForever(flicker))

        // Diner window
        let dwin = SCNBox(width: 0.7, height: 0.5, length: 0.04, chamferRadius: 0)
        let dwm = SCNMaterial()
        dwm.diffuse.contents = NSColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 1)
        dwm.emission.contents = NSColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1)
        dwin.firstMaterial = dwm
        let dwinNode = SCNNode(geometry: dwin)
        dwinNode.position = SCNVector3(-2, 0.75, -2.23)
        scene.rootNode.addChildNode(dwinNode)

        // Stars (100 billboard planes, seeded)
        var rng = SplitMix64(seed: 9001)
        for _ in 0..<100 {
            let sx = Float(Double.random(in: -30...30, using: &rng))
            let sy = Float(Double.random(in: 8...28, using: &rng))
            let sz = Float(Double.random(in: -35 ... -5, using: &rng))
            let sr = CGFloat(Double.random(in: 0.02...0.07, using: &rng))
            let star = SCNPlane(width: sr, height: sr)
            let sm = SCNMaterial()
            let br = Double.random(in: 0.5...1.0, using: &rng)
            sm.diffuse.contents = NSColor(white: br, alpha: 1)
            sm.emission.contents = NSColor(white: br, alpha: 1)
            sm.isDoubleSided = true
            star.firstMaterial = sm
            let sNode = SCNNode(geometry: star)
            sNode.position = SCNVector3(sx, sy, sz)
            let bb = SCNBillboardConstraint()
            sNode.constraints = [bb]
            scene.rootNode.addChildNode(sNode)
        }

        // Firefly particles
        let fireflies = SCNParticleSystem()
        fireflies.birthRate = 5
        fireflies.particleLifeSpan = 9
        fireflies.particleLifeSpanVariation = 4
        fireflies.particleSize = 0.06
        fireflies.particleColor = NSColor(red: 0.8, green: 1.0, blue: 0.3, alpha: 0.9)
        fireflies.particleVelocity = 0.25
        fireflies.particleVelocityVariation = 0.2
        fireflies.spreadingAngle = 360
        fireflies.emittingDirection = SCNVector3(0, 1, 0)
        fireflies.emitterShape = SCNBox(width: 14, height: 2, length: 10)
        fireflies.blendMode = .additive
        let ffNode = SCNNode()
        ffNode.position = SCNVector3(0, 1, -3)
        ffNode.addParticleSystem(fireflies)
        scene.rootNode.addChildNode(ffNode)
        coord.fireflySystem = fireflies

        // Camera drifts down Main Street
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 60; cam.zFar = 80
        camNode.camera = cam
        camNode.position = SCNVector3(0, 2, 6)
        camNode.eulerAngles = SCNVector3(-0.12, 0, 0)
        scene.rootNode.addChildNode(camNode)
        let drift = SCNAction.customAction(duration: 28) { node, elapsed in
            node.position.z = 6 - Float(elapsed / 28) * 14
        }
        camNode.runAction(SCNAction.repeatForever(drift))
    }
}
