import AppKit
import ApplicationServices
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
    /// The app to hand focus back to when a snippet is pasted, captured before
    /// opening the palette activates Heycast.
    private var previousApplication: NSRunningApplication?
    private var activeScope: PaletteScope = .all
    /// Pending wait for the paste target to come forward; replaced by a newer paste.
    private var activationObserver: NSObjectProtocol?
    private var activationTimeout: DispatchWorkItem?

    /// Called when a paste is blocked because Accessibility is not granted,
    /// so the owner can send the user to the permission wizard.
    var onAccessibilityMissing: (() -> Void)?

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
                onActivate: { [weak self] item in self?.activate(item) },
                onSubmit: { [weak self] in self?.activateSelection() }
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

    func toggle(scope: PaletteScope = .all) {
        if isVisible, activeScope == scope {
            hide()
        } else {
            show(scope: scope)
        }
    }

    func show(scope: PaletteScope = .all) {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApplication = frontmost
        }
        activeScope = scope
        model.reset(scope: scope)
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

    // MARK: - Activating

    private func activateSelection() {
        guard let item = model.selected else {
            NSSound.beep()
            return
        }
        activate(item)
    }

    private func activate(_ item: PaletteItem) {
        switch item {
        case .application(let app):
            launch(app)
        case .snippet(let snippet):
            paste(snippet)
        }
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

    /// Copies the snippet and types ⌘V into the app that was frontmost before
    /// the palette opened. Accessibility authorizes the synthetic keystroke;
    /// without it the text still lands on the clipboard, but nothing is typed.
    private func paste(_ snippet: Snippet) {
        hide()

        // Captured now: reopening the palette while a script runs replaces it.
        let target = previousApplication
        Task { [weak self] in
            guard let text = await SnippetRunner.text(for: snippet) else {
                NSSound.beep()
                return
            }
            self?.paste(text, keyword: snippet.keyword, into: target)
        }
    }

    private func paste(_ text: String, keyword: String, into target: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard AXIsProcessTrusted() else {
            NSLog(
                "Heycast: copied snippet “%@” to the clipboard; Accessibility is needed to paste it",
                keyword
            )
            onAccessibilityMissing?()
            return
        }

        guard let target, !target.isTerminated else {
            NSLog("Heycast: copied snippet “%@” to the clipboard; no app to paste into", keyword)
            return
        }

        whenActive(target) {
            SyntheticKeyboard.postPaste()
        }
        target.activate(from: .current)
    }

    /// Runs `action` once `app` is frontmost, instead of guessing how long
    /// activation takes. Gives up after a timeout rather than typing ⌘V into
    /// whichever app happens to be in front; the text stays on the clipboard.
    private func whenActive(_ app: NSRunningApplication, perform action: @escaping @MainActor @Sendable () -> Void) {
        cancelPendingActivation()

        // A short settle lets the target's key window take focus after the
        // app itself becomes active.
        let fire: @MainActor @Sendable () -> Void = { [weak self] in
            self?.cancelPendingActivation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                MainActor.assumeIsolated { action() }
            }
        }

        if app.isActive {
            fire()
            return
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard activated?.processIdentifier == app.processIdentifier else { return }
            MainActor.assumeIsolated { fire() }
        }

        let timeout = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                NSLog("Heycast: %@ did not come forward; snippet left on the clipboard", app.localizedName ?? "target app")
                self?.cancelPendingActivation()
            }
        }
        activationTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: timeout)
    }

    private func cancelPendingActivation() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        activationTimeout?.cancel()
        activationTimeout = nil
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
            activateSelection()
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
