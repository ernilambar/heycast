import Foundation

/// User-owned settings read from `config.json` in `SupportDirectory`.
///
/// Heycast reads this file at startup and never writes it; the status-bar menu
/// seeds a template the first time you open it.
struct AppConfig: Decodable {
    /// Global shortcuts keyed by action name, e.g.
    /// `{"palette": "cmd+space", "snippets": "alt+space"}`.
    /// An empty value disables an action. Unknown actions are logged and
    /// ignored; missing actions keep their built-in default.
    var keymaps: [String: String]?

    /// Path to the snippets folder. `~` expands to the home directory and
    /// relative paths resolve against the config file's own directory.
    var snippetsDirectory: String?
}

extension AppConfig {
    /// Resolves every known action, rejecting malformed and duplicate
    /// shortcuts so one command cannot silently replace another.
    func resolvedKeymap() -> Keymap {
        var shortcuts: [KeymapAction: HotKey] = [:]
        var owners: [HotKey: KeymapAction] = [:]

        for action in KeymapAction.allCases {
            guard let hotKey = resolvedShortcut(
                for: action,
                configured: keymaps?[action.rawValue]
            ) else { continue }

            if let owner = owners[hotKey] {
                NSLog(
                    "Heycast: keymap %@ duplicates %@ (%@); ignoring %@",
                    action.rawValue,
                    owner.rawValue,
                    hotKey.displayString,
                    action.rawValue
                )
                continue
            }

            owners[hotKey] = action
            shortcuts[action] = hotKey
        }

        for key in (keymaps ?? [:]).keys where KeymapAction(rawValue: key) == nil {
            NSLog("Heycast: unknown keymap action \"%@\" in config.json", key)
        }

        return Keymap(shortcuts: shortcuts)
    }

    private func resolvedShortcut(
        for action: KeymapAction,
        configured: String?
    ) -> HotKey? {
        guard let configured else { return action.defaultShortcut }

        let value = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        guard let parsed = HotKey.parse(value) else {
            let fallback = action.defaultShortcut?.displayString ?? "disabled"
            NSLog(
                "Heycast: invalid keymap %@ \"%@\" in config.json, using %@",
                action.rawValue,
                value,
                fallback
            )
            return action.defaultShortcut
        }
        return parsed
    }

    static func load(from url: URL = SupportDirectory.configFile) -> AppConfig {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppConfig() }
        do {
            return try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: url))
        } catch {
            NSLog(
                "Heycast: ignoring unreadable config at %@: %@",
                url.path,
                error.localizedDescription
            )
            return AppConfig()
        }
    }

    /// Effective snippets folder, created when missing. A configured path that
    /// cannot be created falls back to the default so the library never
    /// silently disappears.
    func snippetsDirectoryURL(configURL: URL = SupportDirectory.configFile) -> URL {
        let fileManager = FileManager.default

        if let configured = snippetsDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            let url = Self.resolve(configured, relativeTo: configURL.deletingLastPathComponent())
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                return url
            } catch {
                NSLog(
                    "Heycast: cannot use snippets directory %@: %@",
                    url.path,
                    error.localizedDescription
                )
            }
        }

        let fallback = SupportDirectory.defaultSnippets
        do {
            try fileManager.createDirectory(at: fallback, withIntermediateDirectories: true)
        } catch {
            NSLog(
                "Heycast: cannot create snippets directory %@: %@",
                fallback.path,
                error.localizedDescription
            )
        }
        return fallback
    }

    /// Creates the support folder and seeds a template when the file does not
    /// exist yet, then returns the file to edit. The app writes config only
    /// when asked from the menu.
    static func prepareForEditing(at url: URL = SupportDirectory.configFile) throws -> URL {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            try template().write(to: url, options: .atomic)
        }
        return url
    }

    /// `_comment` is ignored by the decoder; it documents the real keys in
    /// the file a user will see first.
    private static func template() throws -> Data {
        let snippets = SupportDirectory.defaultSnippets.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let displayPath = snippets.hasPrefix(home)
            ? "~" + String(snippets.dropFirst(home.count))
            : snippets

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(
            ConfigTemplate(
                comment: "Bind commands under keymaps by action name; an empty string disables one. Window commands are window.left, window.right, window.top, window.bottom, window.topLeft, window.topRight, window.bottomLeft, window.bottomRight, window.maximize and window.center. snippetsDirectory is optional. Restart Heycast after editing.",
                keymaps: [
                    "palette": "cmd+space",
                    "snippets": "alt+space",
                    "window.left": "ctrl+alt+left",
                    "window.right": "ctrl+alt+right",
                    "window.top": "ctrl+alt+up",
                    "window.bottom": "ctrl+alt+down",
                    "window.maximize": "ctrl+alt+return",
                    "window.center": "ctrl+alt+c",
                ],
                snippetsDirectory: displayPath
            )
        )
    }

    private static func resolve(_ path: String, relativeTo base: URL) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        }
        return base.appendingPathComponent(expanded, isDirectory: true).standardizedFileURL
    }
}

/// Shape of the seeded `config.json`. `_comment` is ignored by the decoder.
private struct ConfigTemplate: Encodable {
    let comment: String
    let keymaps: [String: String]
    let snippetsDirectory: String

    enum CodingKeys: String, CodingKey {
        case comment = "_comment"
        case keymaps
        case snippetsDirectory
    }
}
