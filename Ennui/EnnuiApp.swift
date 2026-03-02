import SwiftUI

@main
struct EnnuiApp: App {
    @StateObject private var multipeerManager = MultipeerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(multipeerManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1024, height: 768)
    }
}
