import SwiftUI

/// Full-screen overlay showing all scene ratings at a glance.
/// For the 16 scenes with both Metal and SceneKit versions, both ratings are shown.
/// Activated with Cmd+R.
struct AllRatingsOverlay: View {
    @ObservedObject var ratingManager: RatingManager
    @Binding var isPresented: Bool

    @State private var appear = false

    private let scenes2D = SceneKind.allCases.filter { !$0.rawValue.hasSuffix("3D") }
    private let scenes3D = SceneKind.allCases.filter { $0.rawValue.hasSuffix("3D") }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Title
                Text("All Ratings")
                    .font(.system(size: 20, weight: .thin, design: .serif))
                    .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84))
                    .tracking(3)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 3D Scenes
                        sectionHeader("3D Scenes")
                        ForEach(scenes3D, id: \.id) { scene in
                            if scene.hasSceneKitVersion {
                                ratingRow(scene: scene, key: scene.rawValue + "-metal", suffix: "Metal")
                                ratingRow(scene: scene, key: scene.rawValue + "-scenekit", suffix: "SceneKit")
                            } else {
                                ratingRow(scene: scene, key: scene.rawValue, suffix: nil)
                            }
                        }

                        Divider()
                            .background(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.15))
                            .padding(.vertical, 12)

                        // 2D Scenes
                        sectionHeader("2D Scenes")
                        ForEach(scenes2D, id: \.id) { scene in
                            ratingRow(scene: scene, key: scene.rawValue, suffix: nil)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }

                // Summary
                HStack(spacing: 16) {
                    let total = ratingManager.ratings.count
                    let sceneCount = SceneKind.allCases.count
                    Text("\(total) rated")
                        .font(.system(size: 11, weight: .light, design: .serif))
                        .foregroundStyle(.white.opacity(0.3))
                    if total > 0 {
                        let avg = Double(ratingManager.ratings.values.reduce(0, +)) / Double(total)
                        Text("avg \(String(format: "%.1f", avg))★")
                            .font(.system(size: 11, weight: .light, design: .serif))
                            .foregroundStyle(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.5))
                    }
                }
                .padding(.bottom, 16)

                Text("Press R on any scene to rate it  ·  ⌘C toggles Metal/SceneKit")
                    .font(.system(size: 10, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: 520, maxHeight: 600)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.05, blue: 0.05).opacity(0.97))
                    .shadow(color: .black.opacity(0.6), radius: 40, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.08), lineWidth: 0.5)
            )
            .scaleEffect(appear ? 1.0 : 0.9)
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

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .regular, design: .serif))
            .foregroundStyle(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.6))
            .tracking(1.5)
            .textCase(.uppercase)
            .padding(.bottom, 8)
            .padding(.top, 4)
    }

    private func ratingRow(scene: SceneKind, key: String, suffix: String?) -> some View {
        let rating = ratingManager.rating(forKey: key)
        return HStack(spacing: 8) {
            // Scene name
            VStack(alignment: .leading, spacing: 1) {
                Text(scene.displayName)
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(rating != nil ? 0.7 : 0.3))
                if let s = suffix {
                    Text(s)
                        .font(.system(size: 9, weight: .light, design: .serif))
                        .foregroundStyle(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.5))
                }
            }
            .frame(minWidth: 160, alignment: .leading)

            Spacer()

            // Stars
            if let r = rating {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= r ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundStyle(star <= r ? starColor(for: star) : .white.opacity(0.12))
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: 11, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.15))
            }
        }
        .padding(.vertical, 4)
    }

    private func starColor(for index: Int) -> Color {
        let warmth = Double(index) / 5.0
        return Color(
            red: 1.0,
            green: 0.78 + warmth * 0.12,
            blue: 0.3 + warmth * 0.15
        )
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
