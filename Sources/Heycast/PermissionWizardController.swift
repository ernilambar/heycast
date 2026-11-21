import AppKit
import SwiftUI

/// Owns the setup window. The window is reused across openings so the
/// wizard's sizes and position stay put; showing it again restarts at step 1.
@MainActor
final class PermissionWizardController: NSObject, NSWindowDelegate {
    private let model = PermissionWizardModel()
    private var window: NSWindow?

    /// Called only when the user finishes the wizard, so "Set Up Later" does
    /// not mark setup as done.
    var onFinish: (() -> Void)?

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        let window = self.window ?? makeWindow()
        model.start()
        window.makeKeyAndOrderFront(nil)
        // `activate()` alone is ignored when a background launch (open, a
        // build script) has no user intent behind it, so the first-run window
        // would open behind the terminal. The deprecated flag still forces it.
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let root = PermissionWizardView(model: model) { [weak self] completed in
            self?.dismiss(completed: completed)
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Heycast Setup"
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

    private func dismiss(completed: Bool) {
        window?.orderOut(nil)
        model.stop()
        if completed {
            onFinish?()
        }
    }

    func windowWillClose(_ notification: Notification) {
        model.stop()
    }
}
