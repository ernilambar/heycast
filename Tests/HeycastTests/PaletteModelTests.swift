import Foundation
import Testing

@testable import Heycast

@Suite @MainActor struct PaletteModelTests {
    @Test func snippetsScopeExcludesApplications() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("heycast-palette-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try """
        ---
        keyword: ;sig
        name: Signature
        ---

        Best regards,
        Nilambar
        """.write(
            to: directory.appendingPathComponent("sig.md"),
            atomically: true,
            encoding: .utf8
        )

        let model = PaletteModel(
            usageStore: UsageStore(fileURL: directory.appendingPathComponent("usage.json")),
            snippetsDirectory: directory
        )
        model.reset(scope: .snippets)

        #expect(model.scope == .snippets)
        #expect(!model.results.isEmpty)
        #expect(model.results.allSatisfy { $0.snippet != nil })
        #expect(model.results.allSatisfy { $0.command == nil })

        model.query = ";sig"
        #expect(model.results.map(\.title) == ["Signature"])
    }

    @Test func snippetsScopeShowsInvalidFilesWithReason() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("heycast-palette-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try "Just text\n".write(
            to: directory.appendingPathComponent("broken-note.md"),
            atomically: true,
            encoding: .utf8
        )

        let model = PaletteModel(
            usageStore: UsageStore(fileURL: directory.appendingPathComponent("usage.json")),
            snippetsDirectory: directory
        )
        model.reset(scope: .snippets)

        let invalid = model.results.compactMap(\.invalidSnippet)
        #expect(invalid.map(\.name) == ["broken-note"])
        #expect(invalid.first?.reason == "No front matter; start the file with ---.")

        model.query = "broken"
        #expect(model.results.map(\.title) == ["broken-note"])

        model.reset(scope: .all)
        #expect(model.results.allSatisfy { $0.invalidSnippet == nil })
    }
}
