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
        #expect(snippet?.body == "\nBest regards,\nNilambar\n")
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
        #expect(snippet?.body == "\nBody\n")
    }

    @Test func bodyIsPreservedVerbatim() {
        let snippet = SnippetLibrary.parse(
            "---\nkeyword: ;code\n---\n\n\tindented();\n  trailing  \n\n",
            url: fileURL
        )

        #expect(snippet?.body == "\n\tindented();\n  trailing  \n\n")
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

    @Test func whitespaceOnlyBodyIsSkipped() {
        #expect(
            SnippetLibrary.parse("---\nkeyword: ;blank\n---\n\n  \n", url: fileURL) == nil
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

        let scan = SnippetLibrary.scan(from: directory)

        #expect(scan.snippets.map(\.keyword) == [";notes", ";sig"])
        #expect(scan.snippets.map(\.url.lastPathComponent) == ["second.md", "first.md"])
        #expect(scan.invalid.isEmpty)
    }

    @Test func missingDirectoryLoadsNothing() {
        let scan = SnippetLibrary.scan(
            from: URL(fileURLWithPath: "/nonexistent-heycast/snippets")
        )
        #expect(scan.snippets.isEmpty)
        #expect(scan.invalid.isEmpty)
    }

    @Test func scanReportsWhyAFileIsInvalid() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try "Just text\n".write(
            to: directory.appendingPathComponent("plain.md"),
            atomically: true,
            encoding: .utf8
        )
        try "---\nkeyword: ;macro\ntype: macro\n---\nBody\n".write(
            to: directory.appendingPathComponent("macro.md"),
            atomically: true,
            encoding: .utf8
        )
        try "---\nkeyword: ;sig\n---\nBody\n".write(
            to: directory.appendingPathComponent("sig.md"),
            atomically: true,
            encoding: .utf8
        )

        let scan = SnippetLibrary.scan(from: directory)

        #expect(scan.snippets.map(\.keyword) == [";sig"])
        #expect(scan.invalid.map(\.name) == ["macro", "plain"])
        #expect(
            scan.invalid.map(\.reason) == [
                "Unknown type “macro”. Use text or script.",
                "No front matter; start the file with ---.",
            ]
        )
    }

    @Test func validationNamesTheProblem() {
        #expect(
            SnippetLibrary.validate("Just text\n", url: fileURL)
                == .failure(.missingFrontMatter)
        )
        #expect(
            SnippetLibrary.validate("---\nname: Nameless\n---\nBody\n", url: fileURL)
                == .failure(.missingKeyword)
        )
        #expect(
            SnippetLibrary.validate(
                "---\nkeyword: ;empty\n---\n",
                url: fileURL
            ) == .failure(.emptyBody)
        )
        #expect(
            SnippetLibrary.validate(
                "---\nkeyword: ;x\ntype: macro\n---\nBody\n",
                url: fileURL
            ) == .failure(.unknownType("macro"))
        )
    }
}
