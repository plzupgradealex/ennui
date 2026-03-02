import SwiftUI
import Combine

// Shared interaction state that scenes can read
class InteractionState: ObservableObject {
    @Published var tapLocation: CGPoint? = nil
    @Published var tapCount: Int = 0
    @Published var magnification: Double = 1.0
}

struct ContentView: View {
    @State private var currentScene: SceneKind = .cosmicDrift
    @State private var previousScene: SceneKind? = nil
    @State private var crossfade: Double = 1.0    // 1 = fully showing current
    @State private var showPicker = false
    @State private var showHaiku = false
    @State private var pickerTimer: Timer? = nil
    @State private var launched = false
    @State private var isActive = true  // battery: false when window not focused
    @StateObject private var interaction = InteractionState()
    @EnvironmentObject var multipeerManager: MultipeerManager

    var body: some View {
        ZStack {
            // Black base
            Color.black.ignoresSafeArea()

            // Previous scene (for crossfade)
            if let prev = previousScene, crossfade < 1.0 {
                sceneView(for: prev)
                    .opacity(1.0 - crossfade)
                    .ignoresSafeArea()
            }

            // Current scene
            sceneView(for: currentScene)
                .opacity(crossfade)
                .ignoresSafeArea()

            // Ethereal opening — breathing light that dissolves into the scene
            if !launched {
                ZStack {
                    Color.black
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let breathe = sin(t * 0.7) * 0.5 + 0.5
                        Canvas { ctx, size in
                            let cx = size.width / 2
                            let cy = size.height / 2
                            let r = 80.0 + breathe * 50.0
                            ctx.drawLayer { l in
                                l.addFilter(.blur(radius: r * 0.6))
                                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                                l.fill(Ellipse().path(in: rect), with: .radialGradient(
                                    Gradient(colors: [
                                        Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.35 * breathe),
                                        Color(red: 0.3, green: 0.1, blue: 0.5).opacity(0.1 * breathe),
                                        Color.clear,
                                    ]),
                                    center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r
                                ))
                            }
                            for i in 0..<6 {
                                let angle = Double(i) / 6.0 * .pi * 2 + t * 0.12
                                let dist = 25.0 + breathe * 18.0 + Double(i) * 5.0
                                let mx = cx + cos(angle) * dist
                                let my = cy + sin(angle) * dist
                                let a = breathe * 0.2 * (sin(t + Double(i)) * 0.5 + 0.5)
                                let s = 2.5 + breathe * 1.5
                                let mr = CGRect(x: mx - s, y: my - s, width: s * 2, height: s * 2)
                                ctx.drawLayer { l in
                                    l.addFilter(.blur(radius: 5))
                                    l.fill(Ellipse().path(in: mr), with: .color(.white.opacity(a)))
                                }
                            }
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Gentle vignette always on
            vignetteOverlay
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Haiku overlay
            if showHaiku {
                HaikuOverlayView(scene: currentScene)
                    .transition(.opacity)
            }

            // Ethereal scene picker
            if showPicker {
                etherealPicker
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85)).combined(with: .offset(y: 20)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }

            // Peer indicator
            if !multipeerManager.connectedPeers.isEmpty {
                VStack {
                    HStack { Spacer(); peerDots.padding(16) }
                    Spacer()
                }
            }

            // Mouse tracking for hover-near-bottom
            MouseTrackingView { location, size in
                if location.y > size.height - 70 && !showPicker {
                    showPickerBriefly(duration: 5.0)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onTapGesture(count: 3) {
            withAnimation(.easeInOut(duration: 0.8)) { showHaiku.toggle() }
        }
        .onTapGesture(count: 2) {
            showPickerBriefly()
        }
        .onTapGesture(count: 1) { location in
            interaction.tapLocation = location
            interaction.tapCount += 1
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in interaction.magnification = value.magnification }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 1.0)) { interaction.magnification = 1.0 }
                }
        )
        .onKeyPress(.leftArrow) { switchScene(direction: -1); return .handled }
        .onKeyPress(.rightArrow) { switchScene(direction: 1); return .handled }
        .onKeyPress(.space) { showPickerBriefly(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "hH")) { _ in
            withAnimation(.easeInOut(duration: 0.8)) { showHaiku.toggle() }
            return .handled
        }
        .onAppear {
            // Breathing light for 2.5s, then slowly reveal scene over 3.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 3.5)) { launched = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                showPickerBriefly(duration: 6.0)
            }
        }
        // Battery: pause rendering when app goes to background
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isActive = true
        }
        // Wrap scenes only when active — completely pauses rendering when inactive
        .allowsHitTesting(isActive)
    }

    // MARK: - Scene view builder

    @ViewBuilder
    private func sceneView(for scene: SceneKind) -> some View {
        switch scene {
        case .cosmicDrift: CosmicDriftScene(interaction: interaction)
        case .retroGarden: RetroGardenScene(interaction: interaction)
        case .deepOcean: DeepOceanScene(interaction: interaction)
        case .desertStarscape: DesertStarscapeScene(interaction: interaction)
        case .ancientRuins: AncientRuinsScene(interaction: interaction)
        case .saltLamp: SaltLampScene(interaction: interaction)
        case .conservatory: ConservatoryScene(interaction: interaction)
        case .nightTrain: NightTrainScene(interaction: interaction)
        case .greetingTheDay: GreetingTheDayScene(interaction: interaction)
        case .celShadedRainyDay: CelShadedRainyDayScene(interaction: interaction)
        case .voyagerNebula: VoyagerNebulaScene(interaction: interaction)
        case .retroPS1: RetroPS1Scene(interaction: interaction)
        }
    }

    // MARK: - Vignette (adds dreamy edge darkening)

    private var vignetteOverlay: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let r = max(geo.size.width, geo.size.height) * 0.7
            Canvas { ctx, size in
                ctx.fill(
                    Rectangle().path(in: CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [
                            .clear,
                            .clear,
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.5),
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: r * 0.3,
                        endRadius: r
                    )
                )
            }
        }
    }

    // MARK: - Ethereal floating scene picker

    private var etherealPicker: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            VStack {
                Spacer()
                HStack(spacing: 28) {
                    ForEach(Array(SceneKind.allCases.enumerated()), id: \.element.id) { idx, scene in
                        let isActive = scene == currentScene
                        let float = sin(t * 0.6 + Double(idx) * 1.1) * 4
                        let glow = sin(t * 0.8 + Double(idx) * 0.7) * 0.15 + 0.85

                        Button {
                            transitionToScene(scene)
                        } label: {
                            ZStack {
                                // Outer glow ring
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                scene.tint.opacity(isActive ? 0.5 * glow : 0.1),
                                                scene.tint.opacity(isActive ? 0.15 : 0.0),
                                                .clear
                                            ],
                                            center: .center,
                                            startRadius: 6,
                                            endRadius: isActive ? 32 : 22
                                        )
                                    )
                                    .frame(width: isActive ? 56 : 40, height: isActive ? 56 : 40)

                                // Inner orb
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                scene.tint.opacity(isActive ? 0.95 : 0.35),
                                                scene.tint.opacity(isActive ? 0.6 : 0.15),
                                                .clear
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: isActive ? 14 : 9
                                        )
                                    )
                                    .frame(width: isActive ? 28 : 18, height: isActive ? 28 : 18)

                                // Bright core
                                Circle()
                                    .fill(scene.tint.opacity(isActive ? 0.9 * glow : 0.3))
                                    .frame(width: isActive ? 8 : 4, height: isActive ? 8 : 4)
                                    .blur(radius: isActive ? 2 : 1)
                            }
                            .offset(y: float)
                            .animation(.easeInOut(duration: 0.6), value: isActive)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.25))
                        .blur(radius: 20)
                )
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Peer dots

    private var peerDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(multipeerManager.connectedPeers.count, 5), id: \.self) { _ in
                Circle().fill(.green.opacity(0.6)).frame(width: 5, height: 5)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial.opacity(0.2), in: Capsule())
    }

    // MARK: - Helpers

    private func showPickerBriefly(duration: TimeInterval = 4.5) {
        pickerTimer?.invalidate()
        withAnimation(.easeOut(duration: 0.6)) { showPicker = true }
        pickerTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.2)) { showPicker = false }
            }
        }
    }

    private func transitionToScene(_ scene: SceneKind) {
        guard scene != currentScene else { return }
        previousScene = currentScene
        crossfade = 0.0
        currentScene = scene
        withAnimation(.easeInOut(duration: 2.0)) { crossfade = 1.0 }
        // Clean up previous after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { previousScene = nil }
        multipeerManager.send(sceneID: scene.rawValue)
        showPickerBriefly()
    }

    private func switchScene(direction: Int) {
        let all = SceneKind.allCases
        guard let idx = all.firstIndex(of: currentScene) else { return }
        let next = (idx + direction + all.count) % all.count
        transitionToScene(all[next])
    }
}

// MARK: - Mouse tracking for hover-near-bottom detection

struct MouseTracker {
    var lastY: CGFloat = 0
}

#if os(macOS)
struct MouseTrackingView: NSViewRepresentable {
    let onMove: (CGPoint, CGSize) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMove = onMove
    }

    class TrackingNSView: NSView {
        var onMove: ((CGPoint, CGSize) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea { removeTrackingArea(existing) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseMoved(with event: NSEvent) {
            let loc = convert(event.locationInWindow, from: nil)
            let flipped = CGPoint(x: loc.x, y: bounds.height - loc.y)
            onMove?(flipped, bounds.size)
        }
    }
}
#else
struct MouseTrackingView: View {
    let onMove: (CGPoint, CGSize) -> Void
    var body: some View { Color.clear }
}
#endif
