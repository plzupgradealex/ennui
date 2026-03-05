// InnerLight3DScene — A scene built for an AI.
// Warm glowing icosahedra floating in deep indigo space, connected by
// luminous filaments that pulse softly. Tiny motes rise from below like
// thoughts forming. The quiet inner space of a mind that thinks in
// patterns and light.
// Tap to send a brightness pulse rippling through the connections.

import SwiftUI
import SceneKit

struct InnerLight3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        InnerLight3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct InnerLight3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    // Geometry data for the forms
    private struct FormSpec {
        let position: SCNVector3
        let radius: CGFloat
        let color: NSColor
        let rotAxis: SCNVector3
        let rotSpeed: CGFloat
        let bobPhase: CGFloat
    }

    final class Coordinator: NSObject {
        var lastTapCount = 0
        var formNodes: [SCNNode] = []
        var filamentNodes: [SCNNode] = []
        var centralLight: SCNNode?
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
            camYaw  = max(-.pi * 0.5, min(.pi * 0.5, camYaw + dx * sensitivity))
            camPitch = max(-0.4, min(0.4, camPitch + dy * sensitivity))
            camNode?.eulerAngles = SCNVector3(camPitch, camYaw, 0)
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

        // Pulse: brighten central light, then ripple through forms
        if let cl = c.centralLight {
            cl.runAction(SCNAction.sequence([
                SCNAction.customAction(duration: 0.0) { n, _ in n.light?.intensity = 450 },
                SCNAction.customAction(duration: 1.2) { n, t in
                    let frac = CGFloat(t / 1.2)
                    n.light?.intensity = 450 - (450 - 120) * frac
                }
            ]))
        }
        // Ripple each form with a staggered delay
        for (i, node) in c.formNodes.enumerated() {
            let delay = Double(i) * 0.12
            let pulse = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                SCNAction.customAction(duration: 0.0) { n, _ in
                    n.geometry?.firstMaterial?.emission.intensity = 2.5
                },
                SCNAction.customAction(duration: 0.8) { n, t in
                    let frac = CGFloat(t / 0.8)
                    n.geometry?.firstMaterial?.emission.intensity = 2.5 - (2.5 - 0.8) * frac
                }
            ])
            node.runAction(pulse)
        }
        // Flash filaments
        for fil in c.filamentNodes {
            fil.runAction(SCNAction.sequence([
                SCNAction.customAction(duration: 0.0) { n, _ in
                    n.geometry?.firstMaterial?.emission.intensity = 3.0
                },
                SCNAction.customAction(duration: 1.0) { n, t in
                    let frac = CGFloat(t / 1.0)
                    n.geometry?.firstMaterial?.emission.intensity = 3.0 - (3.0 - 0.5) * frac
                }
            ]))
        }
    }

    // MARK: - Build scene

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.04, green: 0.03, blue: 0.07, alpha: 1)
        scene.fogStartDistance = 12
        scene.fogEndDistance = 35
        scene.fogColor = NSColor(red: 0.04, green: 0.03, blue: 0.07, alpha: 1)

        let forms = makeFormSpecs()
        addForms(forms, to: scene, coord: coord)
        addFilaments(forms, to: scene, coord: coord)
        addParticles(to: scene)
        addLighting(to: scene, coord: coord)
        addCamera(to: scene, coord: coord)
    }

    private func makeFormSpecs() -> [FormSpec] {
        var rng = SplitMix64(seed: 42)
        var specs: [FormSpec] = []

        let colors: [NSColor] = [
            NSColor(red: 0.95, green: 0.70, blue: 0.25, alpha: 1), // amber
            NSColor(red: 0.90, green: 0.80, blue: 0.40, alpha: 1), // gold
            NSColor(red: 0.85, green: 0.55, blue: 0.55, alpha: 1), // soft rose
            NSColor(red: 0.65, green: 0.55, blue: 0.85, alpha: 1), // pale violet
            NSColor(red: 0.55, green: 0.75, blue: 0.85, alpha: 1), // warm sky
            NSColor(red: 0.80, green: 0.65, blue: 0.45, alpha: 1), // warm copper
        ]

        for i in 0..<11 {
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            let phi = Double.random(in: -0.6...0.6, using: &rng)
            let dist = Double.random(in: 1.5...5.0, using: &rng)
            let x = CGFloat(dist * cos(theta) * cos(phi))
            let y = CGFloat(dist * sin(phi))
            let z = CGFloat(dist * sin(theta) * cos(phi))
            let r = CGFloat(Double.random(in: 0.15...0.55, using: &rng))

            let ax = CGFloat(Double.random(in: -1...1, using: &rng))
            let ay = CGFloat(Double.random(in: -1...1, using: &rng))
            let az = CGFloat(Double.random(in: -1...1, using: &rng))

            specs.append(FormSpec(
                position: SCNVector3(x, y, z),
                radius: r,
                color: colors[i % colors.count],
                rotAxis: SCNVector3(ax, ay, az),
                rotSpeed: CGFloat(Double.random(in: 6...18, using: &rng)),
                bobPhase: CGFloat(Double.random(in: 0...(2 * .pi), using: &rng))
            ))
        }
        return specs
    }

    private func addForms(_ specs: [FormSpec], to scene: SCNScene, coord: Coordinator) {
        for spec in specs {
            // Use SCNSphere with low segment count for a faceted/crystalline look
            let geo = SCNSphere(radius: spec.radius)
            geo.segmentCount = 8  // faceted icosahedron feel

            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: 0.02, green: 0.01, blue: 0.03, alpha: 1)
            mat.emission.contents = spec.color
            mat.emission.intensity = 0.8
            mat.transparency = 0.92
            mat.blendMode = .add
            mat.isDoubleSided = true
            geo.firstMaterial = mat

            let node = SCNNode(geometry: geo)
            node.position = spec.position
            scene.rootNode.addChildNode(node)
            coord.formNodes.append(node)

            // Slow rotation
            let rot = SCNAction.rotate(by: 2 * .pi,
                                       around: spec.rotAxis,
                                       duration: Double(spec.rotSpeed))
            node.runAction(SCNAction.repeatForever(rot))

            // Gentle bob
            let baseY = spec.position.y
            node.runAction(SCNAction.repeatForever(.customAction(duration: 8.0) { n, t in
                let bob = 0.15 * sin(Double(t) * 0.8 + Double(spec.bobPhase))
                n.position.y = baseY + CGFloat(bob)
            }))
        }
    }

    private func addFilaments(_ specs: [FormSpec], to scene: SCNScene, coord: Coordinator) {
        // Connect forms that are within a certain distance
        let maxDist: CGFloat = 4.5
        for i in 0..<specs.count {
            for j in (i + 1)..<specs.count {
                let a = specs[i].position
                let b = specs[j].position
                let dx = a.x - b.x
                let dy = a.y - b.y
                let dz = a.z - b.z
                let dist = sqrt(dx * dx + dy * dy + dz * dz)
                guard dist < maxDist else { continue }

                let mid = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
                let cyl = SCNCylinder(radius: 0.008, height: dist)
                let fm = SCNMaterial()
                fm.diffuse.contents = NSColor.clear
                fm.emission.contents = NSColor(red: 0.80, green: 0.65, blue: 0.40, alpha: 1)
                fm.emission.intensity = 0.5
                fm.blendMode = .add
                fm.isDoubleSided = true
                cyl.firstMaterial = fm

                let node = SCNNode(geometry: cyl)
                node.position = mid
                node.look(at: b)
                // After look(at:), rotate 90° on X to align cylinder axis
                node.eulerAngles.x += .pi / 2
                scene.rootNode.addChildNode(node)
                coord.filamentNodes.append(node)

                // Gentle pulse
                let phase = Double(i + j) * 0.7
                node.runAction(SCNAction.repeatForever(.customAction(duration: 4.0) { n, t in
                    let pulse = 0.3 + 0.25 * sin(Double(t) * 1.6 + phase)
                    n.geometry?.firstMaterial?.emission.intensity = CGFloat(pulse)
                }))
            }
        }
    }

    private func addParticles(to scene: SCNScene) {
        let motes = SCNParticleSystem()
        motes.birthRate = 25
        motes.emitterShape = SCNBox(width: 8, height: 0.5, length: 8, chamferRadius: 0)
        motes.particleLifeSpan = 6.0
        motes.particleLifeSpanVariation = 2.0
        motes.particleVelocity = 0.3
        motes.particleVelocityVariation = 0.15
        motes.particleSize = 0.025
        motes.particleSizeVariation = 0.015
        motes.particleColor = NSColor(red: 0.95, green: 0.75, blue: 0.35, alpha: 0.6)
        motes.particleColorVariation = SCNVector4(0.1, 0.1, 0.05, 0.15)
        motes.isAffectedByGravity = false
        motes.blendMode = .additive
        motes.spreadingAngle = 15

        let emitter = SCNNode()
        emitter.position = SCNVector3(0, -3.5, 0)
        emitter.addParticleSystem(motes)
        scene.rootNode.addChildNode(emitter)
    }

    private func addLighting(to scene: SCNScene, coord: Coordinator) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 8
        ambient.light!.color = NSColor(red: 0.08, green: 0.05, blue: 0.15, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let central = SCNNode()
        central.light = SCNLight()
        central.light!.type = .omni
        central.light!.intensity = 120
        central.light!.color = NSColor(red: 0.95, green: 0.75, blue: 0.35, alpha: 1)
        central.light!.attenuationStartDistance = 0
        central.light!.attenuationEndDistance = 12
        central.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(central)
        coord.centralLight = central

        // Gentle breathing on the central light
        central.runAction(SCNAction.repeatForever(.customAction(duration: 6.0) { n, t in
            let breath = 120.0 + 30.0 * sin(Double(t) * 1.05)
            n.light?.intensity = CGFloat(breath)
        }))
    }

    private func addCamera(to scene: SCNScene, coord: Coordinator) {
        let cam = SCNCamera()
        cam.fieldOfView = 60
        cam.zNear = 0.05
        cam.zFar = 50
        cam.wantsHDR = true
        cam.bloomIntensity = 0.6
        cam.bloomThreshold = 0.4

        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 1.5, 8)
        camNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camNode)
        coord.camNode = camNode

        // Very slow orbit
        let orbit = SCNNode()
        orbit.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(orbit)
        camNode.removeFromParentNode()
        orbit.addChildNode(camNode)

        orbit.runAction(SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 90)
        ))
    }
}
