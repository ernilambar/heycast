import Foundation
import Testing

@testable import Heycast

private func app(_ name: String, bundle: String? = nil) -> LaunchableApp {
    LaunchableApp(
        url: URL(fileURLWithPath: "/Applications/\(name).app"),
        name: name,
        bundleIdentifier: bundle ?? name
    )
}

@Suite struct ApplicationSearchTests {
    @Test func noQueryOrdersByUsageThenName() {
        let apps = [app("Alice"), app("Bob"), app("Carol")]
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let usage = UsageRanking(
            entries: ["Bob": AppUsage(launchCount: 3, lastLaunched: now)],
            now: now
        )

        #expect(ApplicationSearch.rank(apps, matching: "").map(\.name) == ["Alice", "Bob", "Carol"])
        #expect(
            ApplicationSearch.rank(apps, matching: "   ", usage: usage).map(\.name)
                == ["Bob", "Alice", "Carol"]
        )
    }

    @Test func exactMatchWins() {
        let apps = [app("Slack"), app("Safari"), app("Sublime Text")]

        #expect(ApplicationSearch.rank(apps, matching: "safari").map(\.name) == ["Safari"])
    }

    @Test func prefixesSortByLength() {
        let apps = [app("System Settings"), app("Sublime Text"), app("Simulator"), app("Safari"), app("Slack")]

        #expect(
            ApplicationSearch.rank(apps, matching: "s").map(\.name)
                == ["Slack", "Safari", "Simulator", "Sublime Text", "System Settings"]
        )
    }

    @Test func acronymMatch() {
        let apps = [app("System Settings"), app("Visual Studio Code"), app("Slack")]

        #expect(ApplicationSearch.rank(apps, matching: "ss").first?.name == "System Settings")
        #expect(ApplicationSearch.rank(apps, matching: "vsc").first?.name == "Visual Studio Code")
    }

    @Test func wordPrefixAndSubstringMatches() {
        let apps = [app("Visual Studio Code"), app("Slack")]

        #expect(ApplicationSearch.rank(apps, matching: "studio").map(\.name) == ["Visual Studio Code"])
        #expect(ApplicationSearch.rank(apps, matching: "udio").first?.name == "Visual Studio Code")
    }

    @Test func subsequenceMatchesWhenNothingElseDoes() {
        // "slk" is not a word prefix or acronym of the single-word name.
        #expect(ApplicationSearch.rank([app("Slack")], matching: "slk").map(\.name) == ["Slack"])
        #expect(ApplicationSearch.rank([app("Sublime Text")], matching: "sbte").map(\.name) == ["Sublime Text"])
    }

    @Test func nonMatchesAreFilteredOut() {
        #expect(ApplicationSearch.rank([app("Safari")], matching: "zzz").isEmpty)
    }

    @Test func foldingIgnoresCaseAndDiacritics() {
        #expect(ApplicationSearch.rank([app("Café")], matching: "cafe").map(\.name) == ["Café"])
    }

    @Test func usageBreaksTiesInsideATier() {
        let older = LaunchableApp(
            url: URL(fileURLWithPath: "/Applications/Old/Beta.app"),
            name: "Beta",
            bundleIdentifier: "beta.old"
        )
        let newer = LaunchableApp(
            url: URL(fileURLWithPath: "/Applications/New/Beta.app"),
            name: "Beta",
            bundleIdentifier: "beta.new"
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let usage = UsageRanking(
            entries: ["beta.new": AppUsage(launchCount: 4, lastLaunched: now)],
            now: now
        )

        let ranked = ApplicationSearch.rank([older, newer], matching: "beta", usage: usage)
        #expect(ranked.map(\.bundleIdentifier) == ["beta.new", "beta.old"])
    }
}
