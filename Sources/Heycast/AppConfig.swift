import Foundation

/// User-owned settings read from `config.json` in `SupportDirectory`.
///
/// The file is the source of truth: Heycast reads it at startup, the settings
/// window writes it atomically, and an external edit is picked up without a
/// relaunch. Unknown keys survive a settings save untouched.
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
        resolve().keymap
    }

    /// Why a configured shortcut is not the one in effect, keyed by action,
    /// so Settings can explain a value it would otherwise show as chosen.
    func keymapIssues() -> [KeymapAction: String] {
        resolve().issues
    }

    /// Keys under `keymaps` that name no action, sorted.
    var unknownKeymapActions: [String] {
        (keymaps ?? [:]).keys.filter { KeymapAction(rawValue: $0) == nil }.sorted()
    }

    private func resolve() -> (keymap: Keymap, issues: [KeymapAction: String]) {
        var shortcuts: [KeymapAction: HotKey] = [:]
        var owners: [HotKey: KeymapAction] = [:]
        var issues: [KeymapAction: String] = [:]

        for action in KeymapAction.allCases {
            let (resolved, issue) = resolvedShortcut(
                for: action,
                configured: keymaps?[action.rawValue]
            )
            issues[action] = issue
            guard let hotKey = resolved else { continue }

            if let owner = owners[hotKey] {
                NSLog(
                    "Heycast: keymap %@ duplicates %@ (%@); ignoring %@",
                    action.rawValue,
                    owner.rawValue,
                    hotKey.displayString,
                    action.rawValue
                )
                issues[action] = "\(hotKey.displayString) is already used by \(owner.settingsTitle); disabled."
                continue
            }

            owners[hotKey] = action
            shortcuts[action] = hotKey
        }

        for key in unknownKeymapActions {
            NSLog("Heycast: unknown keymap action \"%@\" in config.json", key)
        }

        return (Keymap(shortcuts: shortcuts), issues)
    }

    private func resolvedShortcut(
        for action: KeymapAction,
        configured: String?
    ) -> (HotKey?, String?) {
        guard let configured else { return (action.defaultShortcut, nil) }

        let value = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return (nil, nil) }

        guard let parsed = HotKey.parse(value) else {
            let fallback = action.defaultShortcut?.displayString ?? "disabled"
            NSLog(
                "Heycast: invalid keymap %@ \"%@\" in config.json, using %@",
                action.rawValue,
                value,
                fallback
            )
            return (action.defaultShortcut, "“\(value)” in config.json is not a valid shortcut; using \(fallback).")
        }
        return (parsed, nil)
    }

    static func load(from url: URL = SupportDirectory.configFile) -> AppConfig {
        (try? loadResult(from: url).get()) ?? AppConfig()
    }

    /// Like `load`, but reports an unreadable file instead of hiding it
    /// behind defaults, so callers can keep the last good config.
    static func loadResult(from url: URL = SupportDirectory.configFile) -> Result<AppConfig, Error> {
        guard FileManager.default.fileExists(atPath: url.path) else { return .success(AppConfig()) }
        do {
            return .success(try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: url)))
        } catch {
            NSLog(
                "Heycast: ignoring unreadable config at %@: %@",
                url.path,
                error.localizedDescription
            )
            return .failure(error)
        }
    }

    enum SaveError: Error, LocalizedError {
        case invalidExistingFile

        var errorDescription: String? {
            "config.json is not valid JSON; fix or remove it first"
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
    /// exist yet, then returns the file to edit. "Edit Config…" in Settings
    /// uses this; the settings window writes through `save` otherwise.
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

    /// Writes the settings the window owns, leaving every other key in the
    /// file alone. Atomic, so a failed write leaves the previous config in
    /// place and the running app never sees a half-written file. An existing
    /// file that is not a JSON object is never overwritten: starting from
    /// `{}` would drop every key the user wrote.
    static func save(
        keymaps: [String: String],
        snippetsDirectory: String?,
        at url: URL = SupportDirectory.configFile
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var object: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            // Valid JSON can still fail to decode (`"keymaps": 5`); the app
            // then runs on defaults, so saving would write them over the
            // user's values. Both must succeed before the file is reused.
            guard (try? JSONDecoder().decode(AppConfig.self, from: data)) != nil,
                  let dictionary = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else {
                throw SaveError.invalidExistingFile
            }
            object = dictionary
        }

        object["keymaps"] = keymaps
        if let snippetsDirectory, !snippetsDirectory.isEmpty {
            object["snippetsDirectory"] = snippetsDirectory
        } else {
            object.removeValue(forKey: "snippetsDirectory")
        }

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
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
                comment: "Bind commands under keymaps by action name; an empty string disables one. Window commands are window.left, window.right, window.top, window.bottom, window.topLeft, window.topRight, window.bottomLeft, window.bottomRight, window.maximize and window.center. snippetsDirectory is optional. The Settings window edits this file; changes apply immediately.",
                keymaps: [
                    "palette": "alt+space",
                    "snippets": "alt+shift+space",
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
