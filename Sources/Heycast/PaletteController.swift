import AppKit
import Combine
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
    private let model = PaletteModel()
    private let panel: PalettePanel
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        let size = NSSize(
            width: PaletteControllerLayout.width,
            height: PaletteControllerLayout.height(for: 0)
        )
        panel = PalettePanel(
            contentRect: NSRect(origin: .zero, size: size),
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
        panel.contentView = NSHostingView(
            rootView: PaletteView(
                model: model,
                onOpen: { [weak self] app in self?.launch(app) },
                onSubmit: { [weak self] in self?.launchSelection() }
            )
        )
        panel.setContentSize(size)

        model.$results
            .map(\.count)
            .removeDuplicates()
            .sink { [weak self] count in
                MainActor.assumeIsolated {
                    self?.resizePanel(forResultCount: count)
                }
            }
            .store(in: &cancellables)

        // Scan at launch so the first palette open already has results.
        model.loadApplicationsIfNeeded()
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
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Launching

    private func launchSelection() {
        guard let app = model.selected else {
            NSSound.beep()
            return
        }
        launch(app)
    }

    private func launch(_ app: LaunchableApp) {
        hide()

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: app.url,
            configuration: configuration
        ) { _, error in
            if let error {
                NSLog("Heycast: could not open %@: %@", app.name, error.localizedDescription)
            } else {
                UsageStore.shared.recordLaunch(of: app)
            }
        }
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated {
                self.handleKeyDown(event)
            }
            return handled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])

        if event.keyCode == 53, modifiers.isEmpty { // esc
            hide()
            return true
        }

        guard modifiers.isEmpty else { return false }

        switch event.keyCode {
        case 36, 76: // return, keypad enter
            launchSelection()
            return true
        case 125: // down arrow
            model.moveSelection(by: 1)
            return true
        case 126: // up arrow
            model.moveSelection(by: -1)
            return true
        default:
            return false
        }
    }

    // MARK: - Layout

    /// Grows and shrinks with the result list while keeping the top edge put.
    private func resizePanel(forResultCount count: Int) {
        let height = PaletteControllerLayout.height(for: count)
        guard abs(panel.frame.height - height) > 0.5 else { return }

        let top = panel.frame.maxY
        let x = panel.frame.minX
        panel.setContentSize(NSSize(width: PaletteControllerLayout.width, height: height))
        panel.setFrameOrigin(NSPoint(x: x, y: top - height))
    }

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
}
