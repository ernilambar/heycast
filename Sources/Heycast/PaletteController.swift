import AppKit
import SwiftUI

/// Borderless floating panel that can take keyboard focus without dragging
/// the whole app forward as a regular window would.
final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the panel and its SwiftUI content.
@MainActor
final class PaletteController: NSObject, NSWindowDelegate {
    private static let contentSize = NSSize(
        width: PaletteControllerLayout.width,
        height: PaletteControllerLayout.height
    )

    private let model = PaletteModel()
    private let panel: PalettePanel
    private var escapeMonitor: Any?

    override init() {
        panel = PalettePanel(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: PaletteView(model: model))
        panel.setContentSize(Self.contentSize)
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.reset()
        moveToActiveScreen()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        installEscapeMonitor()
    }

    func hide() {
        removeEscapeMonitor()
        panel.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Helpers

    /// Centers horizontally on the screen under the pointer, a fifth of the
    /// way down from the top edge (launcher-style placement).
    private func moveToActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - visible.height * 0.20
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event } // esc
            MainActor.assumeIsolated { self?.hide() }
            return nil
        }
    }

    private func removeEscapeMonitor() {
        guard let escapeMonitor else { return }
        NSEvent.removeMonitor(escapeMonitor)
        self.escapeMonitor = nil
    }
}
