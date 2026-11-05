import Foundation

/// User-owned settings read from `config.json` in `SupportDirectory`.
///
/// Heycast reads this file at startup and never writes it; the status-bar menu
/// seeds a template the first time you open it.
struct AppConfig: Decodable {
    /// Path to the snippets folder. `~` expands to the home directory and
    /// relative paths resolve against the config file's own directory.
    var snippetsDirectory: String?
}

extension AppConfig {
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

    /// `_comment` is ignored by the decoder; it documents the only real key in
    /// the file a user will see first.
    private static func template() throws -> Data {
        let snippets = SupportDirectory.defaultSnippets.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let displayPath = snippets.hasPrefix(home)
            ? "~" + String(snippets.dropFirst(home.count))
            : snippets

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode([
            "_comment": "Set snippetsDirectory to keep snippets outside this folder. Restart Heycast after editing.",
            "snippetsDirectory": displayPath,
        ])
    }

    private static func resolve(_ path: String, relativeTo base: URL) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        }
        return base.appendingPathComponent(expanded, isDirectory: true).standardizedFileURL
    }
}
