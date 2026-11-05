import Foundation

/// One row of the palette: either an application to launch or a snippet to
/// paste. The panel shows both through the same list, ranking and keyboard
/// handling.
enum PaletteItem: Identifiable, Hashable, Sendable {
    case application(LaunchableApp)
    case snippet(Snippet)

    var id: String {
        switch self {
        case .application(let app): "app:\(app.url.path)"
        case .snippet(let snippet): "snippet:\(snippet.url.path)"
        }
    }

    var title: String {
        switch self {
        case .application(let app): app.name
        case .snippet(let snippet): snippet.name
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
}

/// Ranks applications and snippets together.
///
/// Both kinds use the same name tiers, so an exact snippet keyword beats a
/// prefix-matching application name. With no query, applications keep their
/// usage-driven order and snippets follow alphabetically by keyword, since
/// usage is only tracked for launches.
enum PaletteSearch {
    static func rank(
        applications: [LaunchableApp],
        snippets: [Snippet],
        matching rawQuery: String,
        usage: UsageRanking = .empty
    ) -> [PaletteItem] {
        let query = ApplicationSearch.folded(
            rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard !query.isEmpty else {
            return ApplicationSearch.rank(applications, matching: "", usage: usage)
                .map(PaletteItem.application)
                + snippets.sorted(by: isOrderedBefore).map(PaletteItem.snippet)
        }

        var ranked: [Ranked] = []
        for app in applications {
            guard let match = ApplicationSearch.nameMatch(candidate: app.name, query: query) else {
                continue
            }
            ranked.append(Ranked(item: .application(app), match: match, usageScore: usage.score(for: app)))
        }
        for snippet in snippets {
            guard let match = bestMatch(for: snippet, query: query) else { continue }
            ranked.append(Ranked(item: .snippet(snippet), match: match, usageScore: 0))
        }

        return ranked
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
    }

    private struct Ranked {
        let item: PaletteItem
        let match: ApplicationSearch.NameMatch
        let usageScore: Double
    }

    /// A snippet is found by its keyword or its title, whichever matches better.
    private static func bestMatch(
        for snippet: Snippet,
        query: String
    ) -> ApplicationSearch.NameMatch? {
        [snippet.keyword, snippet.name]
            .compactMap { ApplicationSearch.nameMatch(candidate: $0, query: query) }
            .min { lhs, rhs in
                if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
                return lhs.detail < rhs.detail
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
