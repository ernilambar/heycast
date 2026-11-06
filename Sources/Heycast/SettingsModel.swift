import AppKit
import Carbon.HIToolbox
import Combine

/// Backs the settings window. `config.json` stays the source of truth: every
/// change is written atomically and applied immediately, and the rows are
/// rebuilt from the file the same way the app resolves it at launch.
@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var shortcuts: [KeymapAction: HotKey?] = [:]
    @Published private(set) var snippetsPath = ""
    @Published private(set) var launchAtLogin: LoginItem.State = .disabled
    @Published private(set) var recording: KeymapAction?
    @Published private(set) var issues: [KeymapAction: String] = [:]
    @Published private(set) var errorMessage: String?

    private let configURL: URL
    private let snippetsDirectory: () -> URL
    private let registrationIssues: () -> [KeymapAction: String]
    private let onApply: () -> Void
    private var monitor: Any?

    init(
        configURL: URL = SupportDirectory.configFile,
        snippetsDirectory: @escaping () -> URL,
        registrationIssues: @escaping () -> [KeymapAction: String],
        onApply: @escaping () -> Void
    ) {
        self.configURL = configURL
        self.snippetsDirectory = snippetsDirectory
        self.registrationIssues = registrationIssues
        self.onApply = onApply
    }

    var hasIssues: Bool { !issues.isEmpty }

    func shortcut(for action: KeymapAction) -> HotKey? {
        shortcuts[action] ?? nil
    }

    /// Reads the file back, so an external edit and the settings window
    /// cannot drift apart.
    func reload() {
        let keymap = AppConfig.load(from: configURL).resolvedKeymap()
        var shortcuts: [KeymapAction: HotKey?] = [:]
        for action in KeymapAction.allCases {
            shortcuts[action] = keymap[action]
        }
        self.shortcuts = shortcuts
        snippetsPath = Self.displayPath(snippetsDirectory())
        launchAtLogin = LoginItem.state
        refreshIssues()
    }

    // MARK: - Shortcuts

    func beginRecording(_ action: KeymapAction) {
        cancelRecording()
        recording = action
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let consumed = MainActor.assumeIsolated { self.handleRecording(event) }
            return consumed ? nil : event
        }
    }

    func cancelRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recording = nil
    }

    func setShortcut(_ hotKey: HotKey?, for action: KeymapAction) {
        guard shortcut(for: action) != hotKey else { return }
        shortcuts[action] = hotKey
        save()
    }

    // MARK: - Snippets

    func chooseSnippetsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = snippetsDirectory()
        panel.prompt = "Choose"
        panel.message = "Choose the folder Heycast reads snippets from."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        snippetsPath = Self.displayPath(url)
        save()
    }

    func revealSnippetsDirectory() {
        NSWorkspace.shared.activateFileViewerSelecting([snippetsDirectory()])
    }

    // MARK: - Login item

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            launchAtLogin = try LoginItem.setEnabled(enabled)
            errorMessage = nil
            if launchAtLogin == .requiresApproval {
                LoginItem.openSettings()
            }
        } catch {
            NSLog(
                "Heycast: cannot change Launch at Login: %@",
                error.localizedDescription
            )
            errorMessage = "Could not change Launch at Login: \(error.localizedDescription)"
            launchAtLogin = LoginItem.state
        }
    }

    // MARK: - Saving

    /// Writes only what differs from the shipped defaults, plus an explicit
    /// `""` for disabled actions. Leaving a default unset means a future
    /// release can change that default; writing every action would pin it.
    private func save() {
        let current = AppConfig.load(from: configURL).keymaps ?? [:]
        var keymaps: [String: String] = [:]

        for action in KeymapAction.allCases {
            guard let hotKey = shortcut(for: action) else {
                if action.defaultShortcut != nil || current[action.rawValue] != nil {
                    keymaps[action.rawValue] = ""
                }
                continue
            }

            if hotKey != action.defaultShortcut {
                keymaps[action.rawValue] = hotKey.configString
            }
        }

        do {
            try AppConfig.save(
                keymaps: keymaps,
                snippetsDirectory: snippetsPath,
                at: configURL
            )
            errorMessage = nil
            onApply()
            refreshIssues()
        } catch {
            NSLog(
                "Heycast: cannot save config at %@: %@",
                configURL.path,
                error.localizedDescription
            )
            errorMessage = "Could not save config.json: \(error.localizedDescription)"
        }
    }

    private func refreshIssues() {
        var issues = registrationIssues()
        for action in KeymapAction.allCases {
            guard let hotKey = shortcut(for: action),
                  let owner = SystemShortcuts.owner(of: hotKey)
            else { continue }
            issues[action] = "\(owner.title) already uses \(hotKey.displayString)."
        }
        self.issues = issues
    }

    // MARK: - Recording

    /// Returns whether the key was consumed, so the caller can keep or swallow
    /// the event without passing `NSEvent` across an isolation boundary.
    private func handleRecording(_ event: NSEvent) -> Bool {
        guard let action = recording else { return false }

        switch Int(event.keyCode) {
        case kVK_Escape:
            cancelRecording()
            return true
        case kVK_Delete:
            setShortcut(nil, for: action)
            cancelRecording()
            return true
        default:
            break
        }

        guard let hotKey = HotKey.from(
            keyCode: UInt32(event.keyCode),
            modifiers: Self.carbonModifiers(from: event.modifierFlags)
        ) else {
            // A bare key or shift-only combination cannot be global.
            NSSound.beep()
            return true
        }

        setShortcut(hotKey, for: action)
        cancelRecording()
        return true
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    /// `~/Documents/snippets` instead of an absolute path, matching what
    /// `config.json` accepts.
    private static func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(home) else { return path }
        return "~" + path.dropFirst(home.count)
    }
}
