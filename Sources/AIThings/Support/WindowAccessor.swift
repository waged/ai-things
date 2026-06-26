import SwiftUI
import AppKit

/// Makes the title bar blend into the app: transparent titlebar + a window
/// background matching the header navy, so the top strip isn't a lighter
/// system-gray bar.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.067, green: 0.118, blue: 0.169, alpha: 1) // == Theme.surface
        window.isMovableByWindowBackground = true
    }
}
