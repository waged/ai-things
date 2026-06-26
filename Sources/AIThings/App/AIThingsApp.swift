import SwiftUI

@main
struct AIThingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 600)
                .preferredColorScheme(.dark)
                .navigationTitle("") // hide the redundant native window title
                .onAppear { appDelegate.model = model }
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

/// Flushes state and stops running work when the app quits, so chats aren't
/// lost and no `claude` process is left running.
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { model?.shutdown() }
    }

    // Closing the window quits the app (and triggers the clean shutdown above).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
