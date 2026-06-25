import SwiftUI

@main
struct AIThingsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // Discoverable menu items mirroring the in-app shortcuts.
            CommandGroup(replacing: .newItem) {
                Button("Open Project…") { model.openProjectPicker() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Terminal") {
                Button("Clear History") { model.clearHistory() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Focus Input") { model.focusComposerRequested.toggle() }
                    .keyboardShortcut("l", modifiers: .command)
                Divider()
                Button("Cancel") { model.cancelStreaming() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}
