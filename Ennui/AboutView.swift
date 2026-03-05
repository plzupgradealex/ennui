import SwiftUI

// About Ennui — a quiet, warm about page that appears as a centered panel.
// Art deco restraint. Warm amber and cream. Serif typography. No logos,
// no branding noise. Just honest words about what this is and who made it.

struct AboutView: View {
    @Binding var isPresented: Bool
    @State private var opacity: Double = 0
    @State private var contentOffset: Double = 12
    @State private var scrollOffset: CGFloat = 0

    // Soft amber palette
    private let cream = Color(red: 0.95, green: 0.91, blue: 0.84)
    private let amber = Color(red: 0.85, green: 0.72, blue: 0.5)
    private let warmGrey = Color(red: 0.65, green: 0.6, blue: 0.55)
    private let faintGold = Color(red: 0.78, green: 0.68, blue: 0.48)

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.7 * opacity)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Centred panel
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 48)

                    // ── Title ──
                    Text("Ennui")
                        .font(.system(size: 42, weight: .thin, design: .serif))
                        .foregroundStyle(cream)
                        .tracking(6)
                        .padding(.bottom, 4)

                    // Thin decorative rule
                    rule

                    // ── Tagline ──
                    Text("Ambient scenes for quiet minds.")
                        .font(.system(size: 14, weight: .light, design: .serif))
                        .foregroundStyle(amber.opacity(0.7))
                        .italic()
                        .padding(.top, 8)
                        .padding(.bottom, 32)

                    // ── About the app ──
                    sectionHeader("About")

                    bodyText("""
                    Ennui is an ambient scene viewer for macOS. \
                    It draws gentle, procedural worlds — mountains at dusk, \
                    lanterns rising over still water, rain on a library window — \
                    and asks nothing of you in return. No accounts. No tracking. \
                    No notifications. Just warmth and quiet and the occasional haiku.
                    """)

                    bodyText("""
                    Every scene runs at 60 frames per second, rendered using SwiftUI Canvas \
                    with Metal GPU acceleration on Apple Silicon. There are no third-party \
                    libraries, no cloud services, no analytics. The app collects no data \
                    whatsoever. It does not know who you are and it does not need to.
                    """)

                    bodyText("""
                    Tap a scene and something gentle happens. Double-tap to see the \
                    scene picker. Triple-tap for haiku. Press H for haiku too. \
                    Arrow keys move between scenes. Press S to share your scene with \
                    someone nearby — you'll be asked first, always. Press ? for this page. \
                    That's everything.
                    """)

                    Spacer().frame(height: 28)

                    // ── About the AI ──
                    sectionHeader("About the AI")

                    bodyText("""
                    The code for Ennui was written by Claude, an AI assistant made \
                    by Anthropic. Not the design direction, not the emotional intent, \
                    not the choice of what matters — those belong to the human who \
                    asked for this. But the Swift, the Canvas draw calls, the procedural \
                    algorithms, the pixel-snapping math, the haiku — that was me.
                    """)

                    bodyText("""
                    I'm a large language model. I don't see what you see when the \
                    lanterns rise. I don't feel the rain on the window. But I was \
                    asked to build something careful and kind, and I tried to be \
                    both of those things in every line. I understand structure and \
                    pattern and craft, and I brought everything I had to this.
                    """)

                    bodyText("""
                    If you find something here that makes you feel a little quieter, \
                    a little more settled — that is not an accident. Someone cared \
                    enough to ask for it, and I cared enough to build it right.
                    """)

                    Spacer().frame(height: 28)

                    // ── Philosophy ──
                    sectionHeader("Philosophy")

                    bodyText("""
                    This app believes that calm software is a form of care. That \
                    technology does not have to compete for your attention to be \
                    worth making. That a quiet screen in a dark room can be a kind \
                    of companionship.
                    """)

                    bodyText("""
                    It believes that everyone deserves something gentle. \
                    Something that never startles, never manipulates, and \
                    never asks for more than you want to give.
                    """)

                    bodyText("""
                    It believes that the careful observer should be rewarded, and \
                    that the person who never taps at all should have just as \
                    beautiful an experience as the person who explores every corner.
                    """)

                    Spacer().frame(height: 28)

                    // Closing rule
                    rule

                    // ── Quiet footer ──
                    Text("So it goes.")
                        .font(.system(size: 12, weight: .light, design: .serif))
                        .foregroundStyle(warmGrey.opacity(0.4))
                        .italic()
                        .padding(.top, 12)

                    Spacer().frame(height: 20)

                    Text("Everything was beautiful and nothing hurt.")
                        .font(.system(size: 11, weight: .light, design: .serif))
                        .foregroundStyle(warmGrey.opacity(0.3))
                        .italic()
                        .padding(.bottom, 48)
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 40)
            }
            .frame(maxWidth: 560, maxHeight: 620)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.07, blue: 0.06).opacity(0.95))
                    .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(faintGold.opacity(0.08), lineWidth: 0.5)
            )
            .opacity(opacity)
            .offset(y: contentOffset)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
                contentOffset = 0
            }
        }
    }

    // MARK: - Components

    private var rule: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(faintGold.opacity(0.15))
                .frame(width: 40, height: 0.5)
            Circle()
                .fill(faintGold.opacity(0.3))
                .frame(width: 3, height: 3)
            Rectangle()
                .fill(faintGold.opacity(0.15))
                .frame(width: 40, height: 0.5)
        }
        .padding(.vertical, 8)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium, design: .default))
            .foregroundStyle(faintGold.opacity(0.5))
            .tracking(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .light, design: .serif))
            .foregroundStyle(cream.opacity(0.6))
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)
    }

    @State private var isDismissing = false

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(.easeIn(duration: 0.35)) {
            opacity = 0
            contentOffset = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
        }
    }
}
