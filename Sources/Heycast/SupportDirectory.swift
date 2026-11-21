import Foundation

/// Every file Heycast owns lives under one Application Support folder:
/// `usage.json`, `config.json` and the default `snippets/` directory.
enum SupportDirectory {
    /// Fixed rather than read from the bundle: `Heycast Dev` builds carry
    /// `net.nilambar.heycast.dev` for their own TCC entry, and `swift run` has
    /// no identifier at all, yet every build must share one set of files.
    static let identifier = "net.nilambar.heycast"

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
