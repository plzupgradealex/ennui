// PotterGarden3DScene — A three-dimensional English cottage garden diorama
// in the style of Beatrix Potter. Rows of cabbages on brown earth, a stone wall,
// a wooden gate, a distant cottage, butterflies, and soft afternoon light.
// Tap to release a butterfly.

import SwiftUI
import SceneKit

struct PotterGarden3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        PotterGarden3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct PotterGarden3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var butterflySystem: SCNParticleSystem?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.62, green: 0.72, blue: 0.82, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = true
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        guard let ps = c.butterflySystem else { return }
        let oldRate = ps.birthRate
        ps.birthRate = 30
        ps.particleVelocity = 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            ps.birthRate = oldRate
            ps.particleVelocity = 0.3
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Soft sky background
        scene.background.contents = NSColor(red: 0.68, green: 0.76, blue: 0.85, alpha: 1)
        scene.fogStartDistance = 15
        scene.fogEndDistance = 30
        scene.fogColor = NSColor(red: 0.72, green: 0.78, blue: 0.82, alpha: 1)

        addLighting(to: scene)
        addGround(to: scene)
        addPaths(to: scene)
        addStoneWall(to: scene)
        addGate(to: scene)
        addCabbages(to: scene)
        addCottage(to: scene)
        addFlowers(to: scene)
        addDistantTrees(to: scene)
        addButterflies(to: scene, coord: coord)
        addCamera(to: scene)
    }

    // MARK: - Materials

    private func earthMaterial(r: CGFloat, g: CGFloat, b: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(red: r, green: g, blue: b, alpha: 1)
        m.roughness.contents = NSColor(white: 0.85, alpha: 1)
        return m
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        // Warm afternoon ambient
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 60
        ambient.light!.color = NSColor(red: 0.8, green: 0.75, blue: 0.65, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Afternoon sunlight — warm directional from upper-right
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.intensity = 90
        sun.light!.color = NSColor(red: 1.0, green: 0.92, blue: 0.75, alpha: 1)
        sun.light!.castsShadow = true
        sun.light!.shadowRadius = 4
        sun.light!.shadowSampleCount = 8
        sun.light!.shadowColor = NSColor(red: 0.2, green: 0.2, blue: 0.15, alpha: 0.3)
        sun.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)
    }

    // MARK: - Ground

    private func addGround(to scene: SCNScene) {
        // Rich brown garden earth
        let ground = SCNPlane(width: 20, height: 20)
        let mat = earthMaterial(r: 0.38, g: 0.26, b: 0.16)
        ground.materials = [mat]
        let node = SCNNode(geometry: ground)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(node)

        // Grass beyond the wall
        let grassPlane = SCNPlane(width: 20, height: 12)
        let grassMat = SCNMaterial()
        grassMat.diffuse.contents = NSColor(red: 0.4, green: 0.55, blue: 0.3, alpha: 1)
        grassPlane.materials = [grassMat]
        let grassNode = SCNNode(geometry: grassPlane)
        grassNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        grassNode.position = SCNVector3(0, 0.01, -8)
        scene.rootNode.addChildNode(grassNode)
    }

    // MARK: - Paths

    private func addPaths(to scene: SCNScene) {
        let pathMat = earthMaterial(r: 0.5, g: 0.38, b: 0.25)

        // Main central path
        let main = SCNPlane(width: 1.2, height: 8)
        main.materials = [pathMat]
        let mainNode = SCNNode(geometry: main)
        mainNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        mainNode.position = SCNVector3(0, 0.02, 2)
        scene.rootNode.addChildNode(mainNode)

        // Cross path
        let cross = SCNPlane(width: 6, height: 0.8)
        cross.materials = [pathMat]
        let crossNode = SCNNode(geometry: cross)
        crossNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        crossNode.position = SCNVector3(0, 0.02, 1)
        scene.rootNode.addChildNode(crossNode)
    }

    // MARK: - Stone wall

    private func addStoneWall(to scene: SCNScene) {
        var rng = SplitMix64(seed: 2222)
        let wallZ: Float = -1.8

        // Two rows of stones
        for row in 0..<2 {
            var sx: Float = -5.0
            while sx < 5.0 {
                let sw = Float(0.3 + rng.nextDouble() * 0.4)
                let sh = Float(0.15 + rng.nextDouble() * 0.1)
                let sd: Float = 0.2
                let gy = CGFloat(0.55 + rng.nextDouble() * 0.2)

                let stone = SCNBox(width: CGFloat(sw), height: CGFloat(sh), length: CGFloat(sd), chamferRadius: CGFloat(sw * 0.08))
                let mat = SCNMaterial()
                mat.diffuse.contents = NSColor(red: gy, green: gy - 0.02, blue: gy - 0.05, alpha: 1)
                mat.roughness.contents = NSColor(white: 0.8, alpha: 1)
                stone.materials = [mat]

                let node = SCNNode(geometry: stone)
                let yOffset = Float(row) * 0.2
                node.position = SCNVector3(sx + sw / 2, sh / 2 + yOffset, wallZ)
                scene.rootNode.addChildNode(node)

                sx += sw + 0.02
            }
        }
    }

    // MARK: - Wooden gate

    private func addGate(to scene: SCNScene) {
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(red: 0.45, green: 0.32, blue: 0.2, alpha: 1)
        woodMat.roughness.contents = NSColor(white: 0.7, alpha: 1)

        let gateZ: Float = -1.8
        let gateW: Float = 1.0
        let gateH: Float = 0.55

        // Posts
        for postX: Float in [-gateW / 2 - 0.05, gateW / 2 + 0.05] {
            let post = SCNBox(width: 0.1, height: CGFloat(gateH + 0.15), length: 0.1, chamferRadius: 0.01)
            post.materials = [woodMat]
            let n = SCNNode(geometry: post)
            n.position = SCNVector3(postX, (gateH + 0.15) / 2, gateZ)
            scene.rootNode.addChildNode(n)
        }

        // Horizontal rails
        for railY in [Float(0.12), gateH - 0.05] {
            let rail = SCNBox(width: CGFloat(gateW), height: 0.04, length: 0.04, chamferRadius: 0)
            rail.materials = [woodMat]
            let n = SCNNode(geometry: rail)
            n.position = SCNVector3(0, railY, gateZ)
            scene.rootNode.addChildNode(n)
        }

        // Vertical slats
        for i in 0..<5 {
            let slX = -gateW / 2 + 0.1 + Float(i) * (gateW - 0.2) / 4
            let slat = SCNBox(width: 0.03, height: CGFloat(gateH - 0.1), length: 0.02, chamferRadius: 0)
            slat.materials = [woodMat]
            let n = SCNNode(geometry: slat)
            n.position = SCNVector3(slX, gateH / 2, gateZ)
            scene.rootNode.addChildNode(n)
        }
    }

    // MARK: - Cabbages

    private func addCabbages(to scene: SCNScene) {
        var rng = SplitMix64(seed: 1893)

        let rowStarts: [(Float, Float, Int)] = [
            (-3.5, -0.5, 6), (-3.5, 0.5, 6), (-3.5, 1.5, 5),
            (1.0, 0.0, 5), (1.0, 1.0, 5), (1.0, 2.0, 4),
            (-2.0, 2.5, 3), (0.5, 3.0, 3),
        ]

        for (startX, z, count) in rowStarts {
            for i in 0..<count {
                let x = startX + Float(i) * 0.8 + Float(rng.nextDouble() - 0.5) * 0.15
                let cz = z + Float(rng.nextDouble() - 0.5) * 0.1
                let size = CGFloat(0.25 + rng.nextDouble() * 0.12)

                let parent = SCNNode()
                parent.position = SCNVector3(x, 0, cz)

                // Central head — light green sphere
                let head = SCNSphere(radius: size * 0.5)
                let headMat = SCNMaterial()
                let hue = CGFloat(0.28 + rng.nextDouble() * 0.08)
                let bri = CGFloat(0.55 + rng.nextDouble() * 0.15)
                headMat.diffuse.contents = NSColor(hue: hue, saturation: 0.4, brightness: bri + 0.1, alpha: 1)
                head.materials = [headMat]
                let headNode = SCNNode(geometry: head)
                headNode.position = SCNVector3(0, Float(size * 0.35), 0)
                headNode.scale = SCNVector3(1, 0.7, 1)
                parent.addChildNode(headNode)

                // Outer leaves — flattened spheres radiating outward
                let leafCount = 5 + Int(rng.nextDouble() * 4)
                for j in 0..<leafCount {
                    let angle = Float(j) / Float(leafCount) * Float.pi * 2
                    let dist = Float(size * 0.45)
                    let leaf = SCNSphere(radius: size * 0.35)
                    let leafMat = SCNMaterial()
                    let leafBri = CGFloat(bri - 0.05 + rng.nextDouble() * 0.08)
                    leafMat.diffuse.contents = NSColor(hue: hue + CGFloat(rng.nextDouble() * 0.03 - 0.015),
                                                       saturation: 0.45,
                                                       brightness: leafBri, alpha: 1)
                    leaf.materials = [leafMat]
                    let leafNode = SCNNode(geometry: leaf)
                    leafNode.position = SCNVector3(cos(angle) * dist, Float(size * 0.15), sin(angle) * dist)
                    leafNode.scale = SCNVector3(1.2, 0.4, 0.8)
                    parent.addChildNode(leafNode)
                }

                // Very gentle wobble animation
                let wobbleDur = 4.0 + rng.nextDouble() * 3.0
                let wobbleAmt = CGFloat(0.01 + rng.nextDouble() * 0.008)
                let wL = SCNAction.rotateBy(x: 0, y: 0, z: wobbleAmt, duration: wobbleDur / 2)
                wL.timingMode = .easeInEaseOut
                let wR = SCNAction.rotateBy(x: 0, y: 0, z: -wobbleAmt, duration: wobbleDur / 2)
                wR.timingMode = .easeInEaseOut
                parent.runAction(SCNAction.repeatForever(SCNAction.sequence([wL, wR])))

                scene.rootNode.addChildNode(parent)
            }
        }
    }

    // MARK: - Cottage in the distance

    private func addCottage(to scene: SCNScene) {
        let cottageZ: Float = -6.0
        let cottageX: Float = 3.0

        // Walls
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = NSColor(red: 0.82, green: 0.75, blue: 0.65, alpha: 1)
        let walls = SCNBox(width: 1.5, height: 1.0, length: 1.2, chamferRadius: 0.02)
        walls.materials = [wallMat]
        let wallNode = SCNNode(geometry: walls)
        wallNode.position = SCNVector3(cottageX, 0.5, cottageZ)
        scene.rootNode.addChildNode(wallNode)

        // Roof — pyramid-ish using a box rotated
        let roofMat = SCNMaterial()
        roofMat.diffuse.contents = NSColor(red: 0.5, green: 0.32, blue: 0.22, alpha: 1)
        let roof = SCNPyramid(width: 1.8, height: 0.7, length: 1.5)
        roof.materials = [roofMat]
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(cottageX, 1.0, cottageZ)
        scene.rootNode.addChildNode(roofNode)

        // Chimney
        let chimney = SCNBox(width: 0.2, height: 0.5, length: 0.2, chamferRadius: 0.02)
        let chimneyMat = SCNMaterial()
        chimneyMat.diffuse.contents = NSColor(red: 0.55, green: 0.35, blue: 0.25, alpha: 1)
        chimney.materials = [chimneyMat]
        let chimNode = SCNNode(geometry: chimney)
        chimNode.position = SCNVector3(cottageX + 0.45, 1.5, cottageZ)
        scene.rootNode.addChildNode(chimNode)

        // Door
        let door = SCNPlane(width: 0.3, height: 0.55)
        let doorMat = SCNMaterial()
        doorMat.diffuse.contents = NSColor(red: 0.35, green: 0.25, blue: 0.18, alpha: 1)
        door.materials = [doorMat]
        let doorNode = SCNNode(geometry: door)
        doorNode.position = SCNVector3(cottageX, 0.28, cottageZ + 0.61)
        scene.rootNode.addChildNode(doorNode)

        // Window
        let window = SCNPlane(width: 0.25, height: 0.2)
        let winMat = SCNMaterial()
        winMat.diffuse.contents = NSColor(red: 0.65, green: 0.72, blue: 0.82, alpha: 1)
        winMat.emission.contents = NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.2)
        window.materials = [winMat]
        let winNode = SCNNode(geometry: window)
        winNode.position = SCNVector3(cottageX + 0.45, 0.65, cottageZ + 0.61)
        scene.rootNode.addChildNode(winNode)
    }

    // MARK: - Flowers

    private func addFlowers(to scene: SCNScene) {
        var rng = SplitMix64(seed: 7654)

        // Scattered wildflowers along the wall and path edges
        let positions: [(Float, Float)] = [
            (-3.5, -1.5), (-2.8, -1.6), (-1.5, -1.4), (1.2, -1.5), (2.5, -1.6), (3.2, -1.4),
            (-0.8, 0.1), (0.8, 0.1), (-2.0, 3.5), (2.0, 3.5), (-3.0, 2.5), (3.0, 2.2),
        ]

        for (fx, fz) in positions {
            let parent = SCNNode()
            parent.position = SCNVector3(fx + Float(rng.nextDouble() - 0.5) * 0.3,
                                          0,
                                          fz + Float(rng.nextDouble() - 0.5) * 0.2)

            // Stem
            let stem = SCNCylinder(radius: 0.01, height: 0.15)
            let stemMat = SCNMaterial()
            stemMat.diffuse.contents = NSColor(red: 0.3, green: 0.5, blue: 0.25, alpha: 1)
            stem.materials = [stemMat]
            let stemNode = SCNNode(geometry: stem)
            stemNode.position = SCNVector3(0, 0.075, 0)
            parent.addChildNode(stemNode)

            // Flower head
            let petal = SCNSphere(radius: 0.04)
            let petalMat = SCNMaterial()
            let hues: [CGFloat] = [0.0, 0.08, 0.12, 0.6, 0.75, 0.85]
            let h = hues[Int(rng.nextDouble() * Double(hues.count))]
            petalMat.diffuse.contents = NSColor(hue: h, saturation: 0.5, brightness: 0.75, alpha: 1)
            petal.materials = [petalMat]
            let petalNode = SCNNode(geometry: petal)
            petalNode.position = SCNVector3(0, 0.16, 0)
            petalNode.scale = SCNVector3(1, 0.6, 1)
            parent.addChildNode(petalNode)

            // Gentle sway
            let swayDur = 3.0 + rng.nextDouble() * 2.0
            let swayAmt = CGFloat(0.02 + rng.nextDouble() * 0.015)
            let sL = SCNAction.rotateBy(x: 0, y: 0, z: swayAmt, duration: swayDur / 2)
            sL.timingMode = .easeInEaseOut
            let sR = SCNAction.rotateBy(x: 0, y: 0, z: -swayAmt, duration: swayDur / 2)
            sR.timingMode = .easeInEaseOut
            parent.runAction(SCNAction.repeatForever(SCNAction.sequence([sL, sR])))

            scene.rootNode.addChildNode(parent)
        }
    }

    // MARK: - Distant trees

    private func addDistantTrees(to scene: SCNScene) {
        var rng = SplitMix64(seed: 5432)

        for _ in 0..<10 {
            let tx = Float(rng.nextDouble() * 12 - 6)
            let tz = Float(-5.0 - rng.nextDouble() * 6)
            let treeH = Float(0.8 + rng.nextDouble() * 1.2)

            // Trunk
            let trunk = SCNCylinder(radius: 0.06, height: CGFloat(treeH * 0.4))
            let trunkMat = SCNMaterial()
            trunkMat.diffuse.contents = NSColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1)
            trunk.materials = [trunkMat]
            let trunkNode = SCNNode(geometry: trunk)
            trunkNode.position = SCNVector3(tx, treeH * 0.2, tz)
            scene.rootNode.addChildNode(trunkNode)

            // Canopy — soft green sphere
            let canopy = SCNSphere(radius: CGFloat(treeH * 0.35))
            let canopyMat = SCNMaterial()
            let g = CGFloat(0.35 + rng.nextDouble() * 0.2)
            canopyMat.diffuse.contents = NSColor(red: g * 0.7, green: g, blue: g * 0.6, alpha: 1)
            canopy.materials = [canopyMat]
            let canopyNode = SCNNode(geometry: canopy)
            canopyNode.position = SCNVector3(tx, treeH * 0.55, tz)
            canopyNode.scale = SCNVector3(1, 0.8, 1)
            scene.rootNode.addChildNode(canopyNode)
        }
    }

    // MARK: - Butterflies

    private func addButterflies(to scene: SCNScene, coord: Coordinator) {
        // Particle system for tap-burst butterflies
        let ps = SCNParticleSystem()
        ps.birthRate = 1.5
        ps.particleLifeSpan = 8.0
        ps.particleLifeSpanVariation = 3.0
        ps.emitterShape = SCNBox(width: 5, height: 1, length: 5, chamferRadius: 0)
        ps.particleSize = 0.04
        ps.particleSizeVariation = 0.02
        ps.particleColor = NSColor(red: 0.85, green: 0.65, blue: 0.35, alpha: 0.8)
        ps.particleColorVariation = SCNVector4(0.2, 0.15, 0.1, 0.2)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.3
        ps.particleVelocityVariation = 0.15
        ps.spreadingAngle = 80
        ps.particleAngularVelocity = 2.0
        ps.particleAngularVelocityVariation = 1.5
        let psNode = SCNNode()
        psNode.position = SCNVector3(0, 0.6, 0.5)
        scene.rootNode.addChildNode(psNode)
        psNode.addParticleSystem(ps)
        coord.butterflySystem = ps

        // A few explicit butterfly billboard nodes
        var rng = SplitMix64(seed: 3210)
        let hues: [CGFloat] = [0.08, 0.12, 0.58, 0.8, 0.0, 0.15]
        for i in 0..<6 {
            let plane = SCNPlane(width: 0.08, height: 0.06)
            let mat = SCNMaterial()
            let h = hues[i % hues.count]
            mat.diffuse.contents = NSColor(hue: h, saturation: 0.5, brightness: 0.7, alpha: 0.8)
            mat.isDoubleSided = true
            plane.materials = [mat]
            let node = SCNNode(geometry: plane)
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            node.constraints = [constraint]

            let x = Float(rng.nextDouble() * 6 - 3)
            let y = Float(0.4 + rng.nextDouble() * 0.8)
            let z = Float(rng.nextDouble() * 5 - 2)
            node.position = SCNVector3(x, y, z)

            // Lazy fluttering path
            let dur = 6.0 + rng.nextDouble() * 5.0
            let dx = CGFloat((rng.nextDouble() - 0.5) * 2)
            let dy = CGFloat(0.3 + rng.nextDouble() * 0.5)
            let dz = CGFloat((rng.nextDouble() - 0.5) * 2)

            let flutter = SCNAction.moveBy(x: dx, y: dy, z: dz, duration: dur)
            flutter.timingMode = .easeInEaseOut
            let back = SCNAction.moveBy(x: -dx, y: -dy, z: -dz, duration: dur)
            back.timingMode = .easeInEaseOut
            node.runAction(SCNAction.repeatForever(SCNAction.sequence([flutter, back])))

            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 0.8, 0)
        scene.rootNode.addChildNode(pivot)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 40
        cameraNode.camera!.fieldOfView = 50
        cameraNode.camera!.wantsHDR = true
        cameraNode.camera!.bloomIntensity = 0.15
        cameraNode.camera!.bloomThreshold = 0.9
        cameraNode.camera!.wantsDepthOfField = true
        cameraNode.camera!.focusDistance = 5
        cameraNode.camera!.focalBlurSampleCount = 4
        cameraNode.camera!.fStop = 3.5
        cameraNode.position = SCNVector3(0, 2.5, 7)
        cameraNode.eulerAngles = SCNVector3(-0.3, 0, 0)
        pivot.addChildNode(cameraNode)

        // Very slow gentle orbit
        let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 150)
        pivot.runAction(SCNAction.repeatForever(orbit))
    }
}
