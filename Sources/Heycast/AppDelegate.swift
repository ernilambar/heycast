import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let wizardShownKey = "setup.wizard.shown"

    private let palette = PaletteController()
    private let permissions = PermissionWizardController()
    private var hotKey: HotKeyController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        installHotKey()
        showWizardOnFirstLaunch()
    }

    private func installHotKey() {
        hotKey = HotKeyController { [weak self] in
            self?.palette.toggle()
        }
    }

    /// The permissions are declared in Info.plist, but macOS only prompts the
    /// first time something asks, so the wizard walks through them once.
    private func showWizardOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: Self.wizardShownKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.wizardShownKey)
        permissions.show()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "Heycast"
        )
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            palette.toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let openPaletteItem = menu.addItem(
            withTitle: "Open Palette",
            action: #selector(openPalette),
            keyEquivalent: " "
        )
        openPaletteItem.keyEquivalentModifierMask = [.option]
        openPaletteItem.target = self

        menu.addItem(
            withTitle: "Permissions…",
            action: #selector(openPermissions),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Heycast",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Detach again so left clicks keep toggling the palette.
        statusItem?.menu = nil
    }

    @objc private func openPalette() {
        palette.show()
    }

    @objc private func openPermissions() {
        permissions.show()
    }
}
