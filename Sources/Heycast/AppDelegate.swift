import AppKit
import Darwin
import Dispatch

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Written only when the wizard is finished, not when it opens, so "Set Up
    /// Later" leaves the setup unfinished. `make reset-permissions` clears it.
    private static let wizardShownKey = "setup.wizard.shown"

    private let palette = PaletteController()
    private let permissions = PermissionWizardController()
    private let about = AboutController()
    private let windowManager = WindowManager()
    private var settings: SettingsController?
    private var hotKeyControllers: [KeymapAction: HotKeyController] = [:]
    private var keymap: Keymap?
    private var snippetsDirectory: URL?
    private var snippetExpander: SnippetExpander?
    private var statusItem: NSStatusItem?
    private var configWatcher: DispatchSourceFileSystemObject?
    private var pendingConfigApply: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureSettings()
        installStatusItem()

        palette.onAccessibilityMissing = { [weak self] in self?.permissions.show() }
        windowManager.onAccessibilityMissing = { [weak self] in self?.permissions.show() }

        // Resolve config, register hot keys and start the snippet expander.
        // The wizard is not opened here: Accessibility is only needed for
        // snippets and window commands, so it is offered at first use.
        applyConfig()
        startConfigWatcher()
    }

    /// The wizard sends the user to System Settings; retry the tap when they
    /// return so a new Accessibility grant takes effect without a relaunch.
    func applicationDidBecomeActive(_ notification: Notification) {
        snippetExpander?.startIfNeeded()
    }

    private func configureSettings() {
        let settings = SettingsController(
            snippetsDirectory: { [weak self] in
                self?.snippetsDirectory ?? SupportDirectory.defaultSnippets
            },
            registrationIssues: { [weak self] in
                self?.registrationIssues() ?? [:]
            },
            onApply: { [weak self] in
                self?.applyConfig()
            }
        )
        // Finishing the wizard is the only thing that marks setup complete.
        permissions.onFinish = {
            UserDefaults.standard.set(true, forKey: Self.wizardShownKey)
        }
        self.settings = settings
    }

    // MARK: - Config

    /// Applies `config.json` in place: hot keys are re-registered and the
    /// snippets folder is re-resolved, so a settings change or a hand edit
    /// needs no relaunch. Unchanged values are left alone to avoid churn.
    private func applyConfig() {
        let config = AppConfig.load()
        let keymap = config.resolvedKeymap()
        if keymap != self.keymap {
            installKeymap(keymap)
        }

        let directory = config.snippetsDirectoryURL()
        if directory != snippetsDirectory {
            snippetsDirectory = directory
            logSnippetsDirectory(directory)
            snippetExpander?.setDirectory(directory)
            palette.setSnippetsDirectory(directory)
        }
        if snippetExpander == nil {
            snippetExpander = makeSnippetExpander(directory: directory)
        }
        snippetExpander?.startIfNeeded()

        settings?.refresh()
    }

    /// Watches the support folder rather than the file: an atomic save replaces
    /// the file, so a file descriptor on it would stop seeing writes.
    private func startConfigWatcher() {
        let directory = SupportDirectory.url
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            NSLog(
                "Heycast: cannot create %@: %@",
                directory.path,
                error.localizedDescription
            )
            return
        }

        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else {
            NSLog("Heycast: cannot watch %@ for config changes", directory.path)
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.scheduleConfigApply()
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        configWatcher = source
    }

    /// One save can produce several filesystem events; reload once they settle.
    private func scheduleConfigApply() {
        pendingConfigApply?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.applyConfig()
            }
        }
        pendingConfigApply = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func makeSnippetExpander(directory: URL) -> SnippetExpander {
        SnippetExpander(directory: directory) { [weak self] in
            guard let self else { return false }
            return !self.palette.isVisible && !self.permissions.isVisible
        }
    }

    @discardableResult
    private func logSnippetsDirectory(_ directory: URL) -> URL {
        let scan = SnippetLibrary.scan(from: directory)
        NSLog(
            "Heycast: snippets directory: %@ (%d snippets, %d invalid)",
            directory.path,
            scan.snippets.count,
            scan.invalid.count
        )
        return directory
    }

    private func installKeymap(_ keymap: Keymap) {
        for controller in hotKeyControllers.values {
            controller.unregister()
        }
        hotKeyControllers.removeAll()
        self.keymap = keymap

        for action in KeymapAction.allCases {
            guard let hotKey = keymap[action] else {
                if action.defaultShortcut != nil {
                    NSLog("Heycast: keymap %@: disabled", action.rawValue)
                }
                continue
            }

            NSLog("Heycast: keymap %@: %@", action.rawValue, hotKey.displayString)
            let controller = HotKeyController(hotKey: hotKey) { [weak self] in
                self?.perform(action, toggling: true)
            }
            if let message = controller.status.message {
                NSLog("Heycast: keymap %@: %@", action.rawValue, message)
            }
            hotKeyControllers[action] = controller
        }
    }

    /// Registration failures, surfaced in the settings window instead of only
    /// in the log.
    private func registrationIssues() -> [KeymapAction: String] {
        var issues: [KeymapAction: String] = [:]
        for (action, controller) in hotKeyControllers {
            if let message = controller.status.message {
                issues[action] = message
            }
        }
        return issues
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

    // MARK: - Menu

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusBarIcon.image
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
            let hotKey = keymap?[action]
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
        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self

        let loginItem = menu.addItem(
            withTitle: LoginItem.state == .requiresApproval
                ? "Launch at Login (Needs Approval)"
                : "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.state = LoginItem.state.isOn ? .on : .off
        loginItem.target = self

        menu.addItem(
            withTitle: "Permissions…",
            action: #selector(openPermissions),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Edit Config…",
            action: #selector(editConfig),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "About Heycast",
            action: #selector(openAbout),
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
            let hotKey = keymap?[action]
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

    /// Registers or removes the login item. An approval requirement is not an
    /// error: macOS waits in System Settings, so open that pane.
    @objc private func toggleLaunchAtLogin() {
        do {
            let state = try LoginItem.setEnabled(!LoginItem.state.isOn)
            if state == .requiresApproval {
                LoginItem.openSettings()
            }
        } catch {
            NSLog(
                "Heycast: cannot change Launch at Login: %@",
                error.localizedDescription
            )
        }
    }

    @objc private func openSettings() {
        settings?.show()
    }

    @objc private func openPermissions() {
        permissions.show()
    }

    @objc private func openAbout() {
        about.show()
    }

    /// Seeds a template on first use and hands the file to the default editor.
    /// Settings writes the same file; "Edit Config…" stays for keys that have
    /// no UI.
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
