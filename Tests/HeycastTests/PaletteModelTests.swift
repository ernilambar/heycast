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

        model.query = "sig"
        #expect(model.results.map(\.title) == ["Signature"])
    }
}
