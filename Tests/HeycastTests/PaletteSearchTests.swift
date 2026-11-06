import Foundation
import Testing

@testable import Heycast

private func app(_ name: String) -> LaunchableApp {
    LaunchableApp(
        url: URL(fileURLWithPath: "/Applications/\(name).app"),
        name: name,
        bundleIdentifier: name
    )
}

private func snippet(_ keyword: String, name: String? = nil) -> Snippet {
    Snippet(
        keyword: keyword,
        name: name ?? keyword,
        body: "Body of \(keyword)",
        url: URL(fileURLWithPath: "/tmp/\(keyword.replacingOccurrences(of: ";", with: "")).md")
    )
}

@Suite struct PaletteSearchTests {
    @Test func exactKeywordBeatsPrefixMatchingApplication() {
        let ranked = PaletteSearch.rank(
            applications: [app("Signal")],
            snippets: [snippet("sig")],
            matching: "sig"
        )

        #expect(ranked.map(\.title) == ["sig", "Signal"])
    }

    @Test func snippetMatchesOnlyItsExactCaseSensitiveKeyword() {
        let snippets = [snippet(";sig", name: "Signature")]

        #expect(
            PaletteSearch.rank(applications: [], snippets: snippets, matching: ";sig")
                .map(\.title) == ["Signature"]
        )
        #expect(
            PaletteSearch.rank(applications: [], snippets: snippets, matching: ";si")
                .isEmpty
        )
        #expect(
            PaletteSearch.rank(applications: [], snippets: snippets, matching: ";SIG")
                .isEmpty
        )
        #expect(
            PaletteSearch.rank(applications: [], snippets: snippets, matching: "Signature")
                .isEmpty
        )
    }

    @Test func invalidSnippetsTrailResultsAndMatchByFilename() {
        let issue = InvalidSnippet(
            url: URL(fileURLWithPath: "/tmp/broken-note.md"),
            reason: "The body is empty."
        )

        let ranked = PaletteSearch.rank(
            applications: [],
            snippets: [snippet(";sig")],
            invalidSnippets: [issue],
            matching: ";sig"
        )
        #expect(ranked.map(\.title) == [";sig"])

        let unfiltered = PaletteSearch.rank(
            applications: [],
            snippets: [snippet(";sig")],
            invalidSnippets: [issue],
            matching: ""
        )
        #expect(unfiltered.map(\.title) == [";sig", "broken-note"])

        let byName = PaletteSearch.rank(
            applications: [],
            snippets: [],
            invalidSnippets: [issue],
            matching: "broken"
        )
        #expect(byName.map(\.title) == ["broken-note"])
        #expect(byName.first?.invalidSnippet?.reason == "The body is empty.")
    }

    @Test func emptyQueryKeepsUsageOrderThenListsSnippets() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let usage = UsageRanking(
            entries: ["Zulu": AppUsage(launchCount: 2, lastLaunched: now)],
            now: now
        )

        let ranked = PaletteSearch.rank(
            applications: [app("Alpha"), app("Zulu")],
            snippets: [snippet(";sig"), snippet(";notes")],
            matching: "   ",
            usage: usage
        )

        #expect(ranked.map(\.title) == ["Zulu", "Alpha", ";notes", ";sig"])
    }

    @Test func commandsMatchByName() {
        let ranked = PaletteSearch.rank(
            applications: [],
            snippets: [],
            commands: PaletteCommand.allCases,
            matching: "sleep"
        )

        #expect(ranked.map(\.title) == ["Sleep"])
        #expect(ranked.first?.command == .sleep)
    }

    @Test func commandsFollowResultsWithoutQuery() {
        let ranked = PaletteSearch.rank(
            applications: [],
            snippets: [snippet(";sig")],
            commands: PaletteCommand.allCases,
            matching: ""
        )

        #expect(
            ranked.map(\.title)
                == [";sig", "Open Config", "Open Permissions", "Sleep"]
        )
    }

    @Test func unmatchedSnippetsAreFilteredOut() {
        let ranked = PaletteSearch.rank(
            applications: [],
            snippets: [snippet(";sig")],
            matching: "zzz"
        )

        #expect(ranked.isEmpty)
    }
}
