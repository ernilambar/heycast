import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let palette = PaletteController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
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
        menu.addItem(
            withTitle: "Open Palette",
            action: #selector(openPalette),
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
}
