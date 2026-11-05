import AppKit

/// An installed `.app` that the palette can launch.
struct LaunchableApp: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let bundleIdentifier: String?

    var id: URL { url }
}

/// Builds the list of launchable applications from the usual install roots.
enum ApplicationCatalog {
    /// Scans off the main actor because every bundle reads its Info.plist.
    static func load() async -> [LaunchableApp] {
        await Task.detached(priority: .userInitiated) {
            scan()
        }.value
    }

    private static func scan() -> [LaunchableApp] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]

        var seenApps = Set<URL>()
        var visitedDirectories = Set<URL>()
        var apps: [LaunchableApp] = []

        for root in roots {
            collectApps(
                in: root,
                depth: 0,
                fileManager: fileManager,
                visitedDirectories: &visitedDirectories,
                seenApps: &seenApps,
                apps: &apps
            )
        }

        apps.sort {
            let comparison = $0.name.localizedStandardCompare($1.name)
            if comparison == .orderedSame {
                return $0.url.path < $1.url.path
            }
            return comparison == .orderedAscending
        }
        return apps
    }

    /// Recurses instead of using `FileManager.enumerator` so symlinked
    /// bundles (Safari lives behind one on recent macOS) are still yielded.
    private static func collectApps(
        in directory: URL,
        depth: Int,
        fileManager: FileManager,
        visitedDirectories: inout Set<URL>,
        seenApps: inout Set<URL>,
        apps: inout [LaunchableApp]
    ) {
        guard depth <= 4 else { return }

        let canonicalDirectory = directory.resolvingSymlinksInPath().standardizedFileURL
        guard visitedDirectories.insert(canonicalDirectory).inserted else { return }

        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        for entry in entries {
            guard !entry.lastPathComponent.hasPrefix(".") else { continue }

            if entry.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                addApp(
                    at: entry,
                    seenApps: &seenApps,
                    apps: &apps
                )
                continue
            }

            var isDirectory: ObjCBool = false
            let canonicalEntry = entry.resolvingSymlinksInPath().standardizedFileURL
            guard fileManager.fileExists(
                atPath: canonicalEntry.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else { continue }

            collectApps(
                in: entry,
                depth: depth + 1,
                fileManager: fileManager,
                visitedDirectories: &visitedDirectories,
                seenApps: &seenApps,
                apps: &apps
            )
        }
    }

    private static func addApp(
        at url: URL,
        seenApps: inout Set<URL>,
        apps: inout [LaunchableApp]
    ) {
        let canonicalURL = url.resolvingSymlinksInPath().standardizedFileURL
        guard seenApps.insert(canonicalURL).inserted else { return }

        let bundle = Bundle(url: canonicalURL)
        if let mainIdentifier = Bundle.main.bundleIdentifier,
           bundle?.bundleIdentifier == mainIdentifier {
            return
        }

        let name = displayName(for: canonicalURL, bundle: bundle)
        apps.append(
            LaunchableApp(
                url: canonicalURL,
                name: name,
                bundleIdentifier: bundle?.bundleIdentifier
            )
        )
    }

    private static func displayName(for url: URL, bundle: Bundle?) -> String {
        if let bundle {
            let names = [
                bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String,
                bundle.localizedInfoDictionary?["CFBundleName"] as? String,
                bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ]
            if let name = names.compactMap({ $0 }).first(where: { !$0.isEmpty }) {
                return name
            }
        }

        let fallback = FileManager.default.displayName(atPath: url.path)
        return fallback.isEmpty ? url.deletingPathExtension().lastPathComponent : fallback
    }
}

/// Ranks application names for the palette: exact, prefix, word prefix,
/// acronym, substring, then loose subsequence matches.
enum ApplicationSearch {
    static func rank(_ apps: [LaunchableApp], matching rawQuery: String) -> [LaunchableApp] {
        let query = folded(rawQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !query.isEmpty else { return apps }

        return apps
            .compactMap { app -> (app: LaunchableApp, score: Int)? in
                guard let score = matchScore(candidate: app.name, query: query) else {
                    return nil
                }
                return (app, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score < rhs.score
                }
                let comparison = lhs.app.name.localizedStandardCompare(rhs.app.name)
                if comparison == .orderedSame {
                    return lhs.app.url.path < rhs.app.url.path
                }
                return comparison == .orderedAscending
            }
            .map(\.app)
    }

    private static func matchScore(candidate rawCandidate: String, query: String) -> Int? {
        let candidate = folded(rawCandidate)
        guard !candidate.isEmpty else { return nil }

        if candidate == query { return 0 }
        if candidate.hasPrefix(query) {
            return 10 + candidate.count - query.count
        }

        let words = words(in: rawCandidate).map(folded)
        if words.count > 1 {
            let initials = String(words.compactMap(\.first))
            if initials.hasPrefix(query) {
                return 20 + candidate.count - query.count
            }
        }

        if let wordIndex = words.firstIndex(where: { $0.hasPrefix(query) }) {
            return 30 + wordIndex
        }

        if let range = candidate.range(of: query) {
            return 40 + candidate.distance(from: candidate.startIndex, to: range.lowerBound)
        }

        if let gaps = subsequenceGaps(candidate: candidate, query: query) {
            return 100 + gaps
        }
        return nil
    }

    private static func folded(_ string: String) -> String {
        string.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }

    private static func words(in string: String) -> [String] {
        var result: [String] = []
        var current = ""
        var previousWasLowercase = false

        for character in string {
            guard character.isLetter || character.isNumber else {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
                previousWasLowercase = false
                continue
            }

            if character.isUppercase, previousWasLowercase, !current.isEmpty {
                result.append(current)
                current = ""
            }
            current.append(character)
            previousWasLowercase = character.isLowercase
        }

        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    private static func subsequenceGaps(candidate: String, query: String) -> Int? {
        var searchStart = candidate.startIndex
        var previousMatch: String.Index?
        var gaps = 0

        for character in query {
            guard let match = candidate[searchStart...].firstIndex(of: character) else {
                return nil
            }
            if let previousMatch {
                gaps += candidate.distance(from: candidate.index(after: previousMatch), to: match)
            } else {
                gaps += candidate.distance(from: candidate.startIndex, to: match)
            }
            previousMatch = match
            searchStart = candidate.index(after: match)
        }
        return gaps
    }
}
