import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let wizardShownKey = "setup.wizard.shown"

    private let palette = PaletteController()
    private let permissions = PermissionWizardController()
    private let windowManager = WindowManager()
    private var hotKeyControllers: [KeymapAction: HotKeyController] = [:]
    private var keymap = Keymap.default
    private var snippetExpander: SnippetExpander?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = AppConfig.load()
        installStatusItem()
        palette.onAccessibilityMissing = { [weak self] in self?.permissions.show() }
        windowManager.onAccessibilityMissing = { [weak self] in self?.permissions.show() }
        installKeymap(config.resolvedKeymap())
        let snippetsDirectory = logSnippetsDirectory(config)
        snippetExpander = SnippetExpander(directory: snippetsDirectory) { [weak self] in
            guard let self else { return false }
            return !self.palette.isVisible && !self.permissions.isVisible
        }
        snippetExpander?.startIfNeeded()
        showWizardOnFirstLaunch()
    }

    /// The wizard sends the user to System Settings; retry the tap when they
    /// return so a new Accessibility grant takes effect without a relaunch.
    func applicationDidBecomeActive(_ notification: Notification) {
        snippetExpander?.startIfNeeded()
    }

    /// Resolves the snippets folder once per launch, so the menu, the palette
    /// and the expander cannot disagree on one path.
    @discardableResult
    private func logSnippetsDirectory(_ config: AppConfig) -> URL {
        let directory = config.snippetsDirectoryURL()
        let count = SnippetLibrary.load(from: directory).count
        NSLog("Heycast: snippets directory: %@ (%d snippets)", directory.path, count)
        return directory
    }

    private func installKeymap(_ keymap: Keymap) {
        self.keymap = keymap

        for action in KeymapAction.allCases {
            guard let hotKey = keymap[action] else {
                if action.defaultShortcut != nil {
                    NSLog("Heycast: keymap %@: disabled", action.rawValue)
                }
                continue
            }

            NSLog("Heycast: keymap %@: %@", action.rawValue, hotKey.displayString)
            hotKeyControllers[action] = HotKeyController(hotKey: hotKey) { [weak self] in
                self?.perform(action, toggling: true)
            }
        }
    }

    private func perform(_ action: KeymapAction, toggling: Bool) {
        switch action {
        case .palette:
            if toggling {
                palette.toggle(scope: .all)
            } else {
                palette.show(scope: .all)
            }
        case .snippets:
            if toggling {
                palette.toggle(scope: .snippets)
            } else {
                palette.show(scope: .snippets)
            }
        case .window(let action):
            performWindow(action)
        }
    }

    /// Window commands apply to the app that was in front before Heycast took
    /// focus, so opening the palette first does not change the target.
    private func performWindow(_ action: WindowAction) {
        let target = targetApplicationForWindows()
        if palette.isVisible {
            palette.hide()
        }

        guard let target, !target.isTerminated,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            NSLog("Heycast: window %@: no app in front", action.rawValue)
            return
        }

        windowManager.perform(action, on: target)
        target.activate(from: .current)
    }

    private func targetApplicationForWindows() -> NSRunningApplication? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost == nil || frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return palette.previousApplication
        }
        return frontmost
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
            perform(.palette, toggling: true)
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        for action in KeymapAction.allCases {
            guard let title = action.menuTitle else { continue }
            let hotKey = keymap[action]
            let item = menu.addItem(
                withTitle: title,
                action: #selector(menuActionSelected(_:)),
                keyEquivalent: hotKey?.keyEquivalent ?? ""
            )
            item.keyEquivalentModifierMask = hotKey?.menuModifiers ?? []
            item.representedObject = action.rawValue
            item.target = self
        }

        addWindowMenu(to: menu)

        menu.addItem(
            withTitle: "Edit Config…",
            action: #selector(editConfig),
            keyEquivalent: ""
        ).target = self
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

    /// Window commands get a submenu so the top level stays short. Actions
    /// without a hotkey remain clickable.
    private func addWindowMenu(to menu: NSMenu) {
        let windowMenu = NSMenu(title: "Window")

        for action in KeymapAction.allCases {
            guard case .window(let windowAction) = action else { continue }
            let hotKey = keymap[action]
            let item = windowMenu.addItem(
                withTitle: windowAction.title,
                action: #selector(menuActionSelected(_:)),
                keyEquivalent: hotKey?.keyEquivalent ?? ""
            )
            item.keyEquivalentModifierMask = hotKey?.menuModifiers ?? []
            item.representedObject = action.rawValue
            item.target = self
        }

        let item = menu.addItem(withTitle: "Window", action: nil, keyEquivalent: "")
        item.submenu = windowMenu
    }

    @objc private func menuActionSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let action = KeymapAction(rawValue: raw)
        else { return }
        perform(action, toggling: false)
    }

    @objc private func openPermissions() {
        permissions.show()
    }

    /// Seeds a template on first use and hands the file to the default editor.
    /// The app never writes config on its own, only when asked from this menu.
    @objc private func editConfig() {
        do {
            let url = try AppConfig.prepareForEditing()
            if !NSWorkspace.shared.open(url) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            NSLog(
                "Heycast: cannot prepare config at %@: %@",
                SupportDirectory.configFile.path,
                error.localizedDescription
            )
            NSWorkspace.shared.activateFileViewerSelecting([SupportDirectory.url])
        }
    }
}
