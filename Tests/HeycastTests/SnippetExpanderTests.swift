import Foundation
import Testing

@testable import Heycast

private func snippet(_ keyword: String) -> Snippet {
    Snippet(
        keyword: keyword,
        name: keyword,
        body: "Body of \(keyword)",
        url: URL(fileURLWithPath: "/tmp/\(keyword).md")
    )
}

@Suite struct SnippetExpanderTests {
    @Test func matchesExactKeywordAtEndOfBuffer() {
        let index = SnippetIndex(snippets: [snippet(";sig")])

        #expect(index.expansion(for: "Hello ;sig")?.keyword == ";sig")
        #expect(index.expansion(for: "Hello ;sigx") == nil)
    }

    @Test func longestMatchingKeywordWins() {
        let index = SnippetIndex(snippets: [snippet(";s"), snippet(";sig")])

        #expect(index.expansion(for: ";sig")?.keyword == ";sig")
    }

    @Test func shorterKeywordWaitsWhileLongerCouldStillBeTyped() {
        let index = SnippetIndex(snippets: [snippet(";s"), snippet(";sig")])

        #expect(index.expansion(for: "text ;s") == nil)
    }

    @Test func unrelatedLongerKeywordDoesNotBlockShortMatch() {
        let index = SnippetIndex(snippets: [snippet(";s"), snippet("x;sig")])

        #expect(index.expansion(for: "text ;s")?.keyword == ";s")
    }

    @Test func emptyKeywordsAreIgnored() {
        let index = SnippetIndex(snippets: [snippet(""), snippet(";sig")])

        #expect(index.count == 1)
        #expect(index.maxKeywordLength == 4)
        #expect(index.expansion(for: "anything") == nil)
    }
}