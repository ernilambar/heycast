import Foundation
import Testing

@testable import Heycast

@Suite @MainActor struct SettingsModelTests {
    private func makeModel(
        applied: @escaping () -> Void = {}
    ) throws -> (SettingsModel, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("heycast-settings-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let snippets = directory.appendingPathComponent("snippets", isDirectory: true)
        try FileManager.default.createDirectory(at: snippets, withIntermediateDirectories: true)

        let model = SettingsModel(
            configURL: directory.appendingPathComponent("config.json"),
            snippetsDirectory: { snippets },
            registrationIssues: { [:] },
            onApply: applied
        )
        return (model, directory)
    }

    @Test func changingAShortcutWritesConfigAndApplies() throws {
        var applied = 0
        let (model, directory) = try makeModel { applied += 1 }
        defer { try? FileManager.default.removeItem(at: directory) }

        model.reload()
        #expect(model.shortcut(for: .palette) == .default)

        model.setShortcut(HotKey.parse("ctrl+alt+k"), for: .palette)

        #expect(applied == 1)
        let saved = AppConfig.load(from: directory.appendingPathComponent("config.json"))
        #expect(saved.keymaps?["palette"] == "ctrl+alt+k")
        #expect(saved.resolvedKeymap()[.palette]?.displayString == "⌃⌥K")
    }

    @Test func removingAShortcutWritesAnEmptyBinding() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        model.reload()
        model.setShortcut(nil, for: .snippets)

        let saved = AppConfig.load(from: directory.appendingPathComponent("config.json"))
        #expect(saved.keymaps?["snippets"] == "")
        #expect(saved.resolvedKeymap()[.snippets] == nil)
    }

    @Test func useDefaultSnippetsDirectoryDropsTheOverride() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configURL = directory.appendingPathComponent("config.json")
        let custom = directory.appendingPathComponent("snippets", isDirectory: true)
        try #"{"snippetsDirectory":"\#(custom.path)"}"#
            .write(to: configURL, atomically: true, encoding: .utf8)

        model.reload()
        #expect(model.isUsingDefaultSnippetsDirectory == false)

        model.useDefaultSnippetsDirectory()

        let saved = AppConfig.load(from: configURL)
        #expect(saved.snippetsDirectory == nil)
        #expect(model.isUsingDefaultSnippetsDirectory)
    }

    @Test func savingAShortcutDoesNotPinTheDefaultSnippetsFolder() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        model.reload()
        model.setShortcut(HotKey.parse("ctrl+alt+k"), for: .palette)

        let saved = AppConfig.load(from: directory.appendingPathComponent("config.json"))
        #expect(saved.snippetsDirectory == nil)
    }

    @Test func systemOwnedShortcutIsReportedAsAnIssue() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        model.reload()
        model.setShortcut(HotKey.parse("cmd+space"), for: .palette)

        #expect(model.issues[.palette]?.contains("Spotlight") == true)
    }
}
