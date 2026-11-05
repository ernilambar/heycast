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

    @Test func snippetsMatchByTitle() {
        let ranked = PaletteSearch.rank(
            applications: [],
            snippets: [snippet(";notes", name: "Meeting notes"), snippet(";sig", name: "Signature")],
            matching: "meeting"
        )

        #expect(ranked.map(\.title) == ["Meeting notes"])
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

    @Test func unmatchedSnippetsAreFilteredOut() {
        let ranked = PaletteSearch.rank(
            applications: [],
            snippets: [snippet(";sig")],
            matching: "zzz"
        )

        #expect(ranked.isEmpty)
    }
}
