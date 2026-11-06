import Foundation

/// Built-in actions offered as palette rows. They are found by name in the
/// all scope, never get a global shortcut, and are not modes: selecting one
/// runs it and closes the palette.
///
/// Lock Screen is deliberately absent. macOS 26 removed `CGSession`, and every
/// remaining way to lock the screen needs a private API or an Automation grant,
/// so shipping it would break the "no new permission" rule.
enum PaletteCommand: String, CaseIterable, Identifiable, Sendable {
    case sleep
    case openPermissions
    case openConfig

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: "Sleep"
        case .openPermissions: "Open Permissions"
        case .openConfig: "Open Config"
        }
    }

    var symbol: String {
        switch self {
        case .sleep: "moon.zzz.fill"
        case .openPermissions: "hand.raised.fill"
        case .openConfig: "doc.text.fill"
        }
    }
}

/// One row of the palette: an application to launch, a snippet to paste, a
/// snippet file that failed validation, or a built-in command. The panel shows
/// all of them through the same list, ranking and keyboard handling.
enum PaletteItem: Identifiable, Hashable, Sendable {
    case application(LaunchableApp)
    case snippet(Snippet)
    case invalidSnippet(InvalidSnippet)
    case command(PaletteCommand)

    var id: String {
        switch self {
        case .application(let app): "app:\(app.url.path)"
        case .snippet(let snippet): "snippet:\(snippet.url.path)"
        case .invalidSnippet(let issue): "invalid:\(issue.url.path)"
        case .command(let command): "command:\(command.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .application(let app): app.name
        case .snippet(let snippet): snippet.name
        case .invalidSnippet(let issue): issue.name
        case .command(let command): command.title
        }
    }

    var application: LaunchableApp? {
        if case .application(let app) = self { return app }
        return nil
    }

    var snippet: Snippet? {
        if case .snippet(let snippet) = self { return snippet }
        return nil
    }

    var invalidSnippet: InvalidSnippet? {
        if case .invalidSnippet(let issue) = self { return issue }
        return nil
    }

    var command: PaletteCommand? {
        if case .command(let command) = self { return command }
        return nil
    }

    /// File a row points at, used by reveal and copy-path.
    var fileURL: URL? {
        switch self {
        case .application(let app): app.url
        case .snippet(let snippet): snippet.url
        case .invalidSnippet(let issue): issue.url
        case .command: nil
        }
    }
}

/// Ranks applications and snippets together.
///
/// Applications use the tiered name matching from `ApplicationSearch`. A
/// snippet matches only when the query is exactly its keyword, case-sensitive:
/// a launcher that drops a half-typed keyword on the clipboard is worse than
/// one that waits for the whole trigger.
///
/// With no query, applications keep their usage-driven order, valid snippets
/// follow alphabetically by keyword, and invalid files come last so their
/// validation status is visible without competing with usable rows.
enum PaletteSearch {
    static func rank(
        applications: [LaunchableApp],
        snippets: [Snippet],
        invalidSnippets: [InvalidSnippet] = [],
        commands: [PaletteCommand] = [],
        matching rawQuery: String,
        usage: UsageRanking = .empty
    ) -> [PaletteItem] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let foldedQuery = ApplicationSearch.folded(query)
        let invalid = matchingInvalid(invalidSnippets, query: foldedQuery)
            .map(PaletteItem.invalidSnippet)

        guard !query.isEmpty else {
            return ApplicationSearch.rank(applications, matching: "", usage: usage)
                .map(PaletteItem.application)
                + snippets.sorted(by: isOrderedBefore).map(PaletteItem.snippet)
                + invalid
                + commands
                    .sorted {
                        $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    }
                    .map(PaletteItem.command)
        }

        var ranked: [Ranked] = []
        for app in applications {
            guard let match = ApplicationSearch.nameMatch(
                candidate: app.name,
                query: foldedQuery
            ) else { continue }
            ranked.append(
                Ranked(
                    item: .application(app),
                    match: match,
                    usageScore: usage.score(for: app)
                )
            )
        }
        for snippet in snippets where snippet.keyword == query {
            ranked.append(
                Ranked(
                    item: .snippet(snippet),
                    match: ApplicationSearch.NameMatch(tier: 0, detail: 0),
                    usageScore: 0
                )
            )
        }
        for command in commands {
            guard let match = ApplicationSearch.nameMatch(
                candidate: command.title,
                query: foldedQuery
            ) else { continue }
            ranked.append(
                Ranked(
                    item: .command(command),
                    match: match,
                    usageScore: 0
                )
            )
        }

        let rankedItems = ranked
            .sorted { lhs, rhs in
                if lhs.match.tier != rhs.match.tier {
                    return lhs.match.tier < rhs.match.tier
                }
                if lhs.usageScore != rhs.usageScore {
                    return lhs.usageScore > rhs.usageScore
                }
                if lhs.match.detail != rhs.match.detail {
                    return lhs.match.detail < rhs.match.detail
                }
                return isOrderedBefore(lhs.item, rhs.item)
            }
            .map(\.item)

        // Invalid rows are diagnostics, not results: they follow the matches
        // so a broken file never outranks a working snippet.
        return rankedItems + invalid
    }

    private struct Ranked {
        let item: PaletteItem
        let match: ApplicationSearch.NameMatch
        let usageScore: Double
    }

    /// Invalid files have no keyword, so they are found by filename. This is
    /// deliberately the only non-exact match in the snippets scope; it helps
    /// locate the file to fix rather than pretending it can be pasted.
    private static func matchingInvalid(
        _ invalid: [InvalidSnippet],
        query: String
    ) -> [InvalidSnippet] {
        let matched = query.isEmpty
            ? invalid
            : invalid.filter {
                ApplicationSearch.folded($0.name).contains(query)
            }
        return matched.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func isOrderedBefore(_ lhs: Snippet, _ rhs: Snippet) -> Bool {
        let comparison = lhs.keyword.localizedStandardCompare(rhs.keyword)
        if comparison == .orderedSame {
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        return comparison == .orderedAscending
    }

    private static func isOrderedBefore(_ lhs: PaletteItem, _ rhs: PaletteItem) -> Bool {
        let comparison = lhs.title.localizedStandardCompare(rhs.title)
        if comparison == .orderedSame {
            return lhs.id < rhs.id
        }
        return comparison == .orderedAscending
    }
}
