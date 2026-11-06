import AppKit
import SwiftUI

/// Owns the settings window. One window is reused so the recorder and the
/// scroll position survive reopening; showing it reloads `config.json` first.
@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private var window: NSWindow?

    init(
        configURL: URL = SupportDirectory.configFile,
        snippetsDirectory: @escaping () -> URL,
        registrationIssues: @escaping () -> [KeymapAction: String],
        onApply: @escaping () -> Void
    ) {
        model = SettingsModel(
            configURL: configURL,
            snippetsDirectory: snippetsDirectory,
            registrationIssues: registrationIssues,
            onApply: onApply
        )
        super.init()
    }

    func show() {
        let window = self.window ?? makeWindow()
        model.reload()
        window.makeKeyAndOrderFront(nil)
        // `activate()` alone is ignored when a background launch (open, a
        // build script) has no user intent behind it.
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Re-reads `config.json` after an external edit or a hotkey re-register.
    func refresh() {
        model.reload()
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView(model: model)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 640),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Heycast Settings"
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

    func windowWillClose(_ notification: Notification) {
        model.cancelRecording()
    }
}
