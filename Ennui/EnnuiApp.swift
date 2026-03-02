import SwiftUI
import AppKit

extension Notification.Name {
    static let showAboutEnnui = Notification.Name("showAboutEnnui")
    static let toggleSharing = Notification.Name("toggleSharing")
}

@main
struct EnnuiApp: App {
    @StateObject private var multipeerManager = MultipeerManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(multipeerManager)
                .background(EDRWindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1024, height: 768)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Ennui") {
                    NotificationCenter.default.post(name: .showAboutEnnui, object: nil)
                }
            }
            CommandGroup(after: .appInfo) {
                Divider()
                Button(multipeerManager.isEnabled ? "Stop Sharing" : "Share Experience\u{2026}") {
                    NotificationCenter.default.post(name: .toggleSharing, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - App Delegate: request P3 color space for display

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we get the full P3 gamut and EDR headroom
        NSApplication.shared.windows.forEach { window in
            window.colorSpace = .displayP3
            // Request maximum EDR headroom (XDR displays can go up to 1600 nits)
            if let screen = window.screen {
                _ = screen.maximumExtendedDynamicRangeColorComponentValue
            }
        }
    }
}

// MARK: - Per-window EDR + P3 configuration via NSViewRepresentable

struct EDRWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Display P3 wide gamut — uses the full color range of Apple displays
                window.colorSpace = .displayP3
                // Enable the view's layer for EDR
                view.wantsLayer = true
                view.layer?.wantsExtendedDynamicRangeContent = true
                // Also set on content view
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.wantsExtendedDynamicRangeContent = true
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
