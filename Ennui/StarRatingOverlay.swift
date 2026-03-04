import SwiftUI

/// Floating Nintendo-style 1–5 star rating overlay.
/// Shows the current scene name and five stars that highlight left-to-right.
struct StarRatingOverlay: View {
    let scene: SceneKind
    @ObservedObject var ratingManager: RatingManager
    @Binding var isPresented: Bool

    @State private var hovered: Int? = nil
    @State private var appear = false

    private var currentRating: Int { ratingManager.rating(for: scene) ?? 0 }

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap to dismiss
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 16) {
                // Scene name
                Text(scene.displayName)
                    .font(.system(size: 15, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                // Five floating stars
                HStack(spacing: 14) {
                    ForEach(1...5, id: \.self) { star in
                        starView(index: star)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                    if currentRating == star {
                                        ratingManager.clearRating(for: scene)
                                    } else {
                                        ratingManager.rate(scene: scene, stars: star)
                                    }
                                }
                                // Auto-dismiss after a moment
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    dismiss()
                                }
                            }
                            .onHover { hovering in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    hovered = hovering ? star : nil
                                }
                            }
                    }
                }

                // Gentle label
                Text(ratingLabel)
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(height: 16)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            )
            .scaleEffect(appear ? 1.0 : 0.85)
            .opacity(appear ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appear = true
            }
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    // MARK: - Star rendering

    private func starView(index: Int) -> some View {
        let active = activeLevel(for: index)

        return ZStack {
            // Glow behind active stars
            if active {
                Image(systemName: "star.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(starColor(for: index).opacity(0.4))
                    .blur(radius: 8)
            }

            // The star itself
            Image(systemName: active ? "star.fill" : "star")
                .font(.system(size: 30))
                .foregroundStyle(active ? starColor(for: index) : .white.opacity(0.25))
                .shadow(color: active ? starColor(for: index).opacity(0.6) : .clear, radius: 6, y: 2)
        }
        .scaleEffect(hovered == index ? 1.2 : 1.0)
        // Gentle float animation — each star bobs at a slightly different rate
        .offset(y: appear ? floatOffset(for: index) : 0)
        .animation(
            .easeInOut(duration: 2.0 + Double(index) * 0.3)
            .repeatForever(autoreverses: true),
            value: appear
        )
        .accessibilityLabel("\(index) star\(index == 1 ? "" : "s")")
        .accessibilityAddTraits(currentRating == index ? .isSelected : [])
    }

    private func activeLevel(for index: Int) -> Bool {
        let effective = hovered ?? currentRating
        return index <= effective
    }

    /// Warm golden gradient — brighter for higher stars
    private func starColor(for index: Int) -> Color {
        let warmth = Double(index) / 5.0
        return Color(
            red: 1.0,
            green: 0.78 + warmth * 0.12,
            blue: 0.3 + warmth * 0.15
        )
    }

    private func floatOffset(for index: Int) -> CGFloat {
        // Staggered gentle bob
        CGFloat(3 + index % 2 * 2) * (index.isMultiple(of: 2) ? -1 : 1)
    }

    private var ratingLabel: String {
        if let h = hovered {
            return ["", "not great", "okay", "nice", "really good", "favourite"][h]
        }
        if currentRating > 0 {
            return ["", "not great", "okay", "nice", "really good", "favourite"][currentRating]
        }
        return "tap a star"
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            appear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPresented = false
            }
        }
    }
}
