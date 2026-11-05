import Foundation

/// Every file Heycast owns lives under one Application Support folder:
/// `usage.json`, `config.json` and the default `snippets/` directory.
enum SupportDirectory {
    /// Fallback for `swift run`, which has no bundle identifier. Without it,
    /// development would read a different folder than the installed app.
    static let fallbackIdentifier = "net.nilambar.heycast"

    static var identifier: String {
        Bundle.main.bundleIdentifier ?? fallbackIdentifier
    }

    static var url: URL {
        let fileManager = FileManager.default
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return root.appendingPathComponent(identifier, isDirectory: true)
    }

    static var configFile: URL { url.appendingPathComponent("config.json") }
    static var usageFile: URL { url.appendingPathComponent("usage.json") }
    static var defaultSnippets: URL { url.appendingPathComponent("snippets", isDirectory: true) }
}
