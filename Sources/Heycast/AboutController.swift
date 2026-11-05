import AppKit
import SwiftUI

/// Owns the About window. The window is reused so reopening it keeps the
/// position the user moved it to.
@MainActor
final class AboutController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        let window = self.window ?? makeWindow()
        window.makeKeyAndOrderFront(nil)
        // `activate()` alone is ignored when a background launch (open, a
        // build script) has no user intent behind it, so the panel would open
        // behind the terminal. The deprecated flag still forces it.
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let info = AboutInfo.current()
        let root = AboutView(
            info: info,
            icon: NSApp.applicationIconImage ?? StatusBarIcon.image
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "About \(info.name)"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.contentViewController = NSHostingController(rootView: root)
        window.delegate = self
        window.center()

        self.window = window
        return window
    }
}
