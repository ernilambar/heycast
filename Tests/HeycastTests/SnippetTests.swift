import Foundation
import Testing

@testable import Heycast

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("heycast-snippets-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private let fileURL = URL(fileURLWithPath: "/tmp/example.md")

@Suite struct SnippetTests {
    @Test func parsesFrontMatterAndBody() {
        let snippet = SnippetLibrary.parse(
            """
            ---
            keyword: ;sig
            name: Email signature
            ---

            Best regards,
            Nilambar

            """,
            url: fileURL
        )

        #expect(snippet?.keyword == ";sig")
        #expect(snippet?.name == "Email signature")
        #expect(snippet?.body == "Best regards,\nNilambar")
    }

    @Test func nameFallsBackToKeyword() {
        let snippet = SnippetLibrary.parse(
            """
            ---
            keyword: ;notes
            ---

            Body
            """,
            url: fileURL
        )

        #expect(snippet?.name == ";notes")
    }

    @Test func quotesAroundValuesAreRemoved() {
        let snippet = SnippetLibrary.parse(
            """
            ---
            keyword: ";sig"
            name: 'Email signature'
            ---

            Body
            """,
            url: fileURL
        )

        #expect(snippet?.keyword == ";sig")
        #expect(snippet?.name == "Email signature")
    }

    @Test func windowsLineEndingsParse() {
        let snippet = SnippetLibrary.parse(
            "---\r\nkeyword: ;sig\r\n---\r\n\r\nBody\r\n",
            url: fileURL
        )

        #expect(snippet?.keyword == ";sig")
        #expect(snippet?.body == "Body")
    }

    @Test func filesWithoutFrontMatterAreSkipped() {
        #expect(SnippetLibrary.parse("Just text\n", url: fileURL) == nil)
    }

    @Test func filesWithoutKeywordAreSkipped() {
        #expect(
            SnippetLibrary.parse(
                """
                ---
                name: Nameless
                ---

                Body
                """,
                url: fileURL
            ) == nil
        )
    }

    @Test func filesWithoutBodyAreSkipped() {
        #expect(
            SnippetLibrary.parse(
                """
                ---
                keyword: ;empty
                ---
                """,
                url: fileURL
            ) == nil
        )
    }

    @Test func loadReadsMarkdownFilesSortedByKeyword() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try """
        ---
        keyword: ;notes
        ---

        Notes
        """.write(
            to: directory.appendingPathComponent("second.md"),
            atomically: true,
            encoding: .utf8
        )
        try """
        ---
        keyword: ;sig
        ---

        Signature
        """.write(
            to: directory.appendingPathComponent("first.md"),
            atomically: true,
            encoding: .utf8
        )
        try "ignored".write(
            to: directory.appendingPathComponent("notes.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "ignored".write(
            to: directory.appendingPathComponent(".hidden.md"),
            atomically: true,
            encoding: .utf8
        )

        let snippets = SnippetLibrary.load(from: directory)

        #expect(snippets.map(\.keyword) == [";notes", ";sig"])
        #expect(snippets.map(\.url.lastPathComponent) == ["second.md", "first.md"])
    }

    @Test func missingDirectoryLoadsNothing() {
        #expect(
            SnippetLibrary.load(from: URL(fileURLWithPath: "/nonexistent-heycast/snippets")).isEmpty
        )
    }
}
