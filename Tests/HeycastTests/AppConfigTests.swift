import Foundation
import Testing

@testable import Heycast

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("heycast-config-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

@Suite struct AppConfigTests {
    @Test func missingFileHasNoSettings() {
        let missing = URL(fileURLWithPath: "/nonexistent-heycast/config.json")
        #expect(AppConfig.load(from: missing).snippetsDirectory == nil)
    }

    @Test func readsOnlyTheKnownKey() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("config.json")
        try #"{"snippetsDirectory":"/tmp/snippets","unrelated":true}"#
            .write(to: file, atomically: true, encoding: .utf8)
        #expect(AppConfig.load(from: file).snippetsDirectory == "/tmp/snippets")
    }

    @Test func unreadableFileFallsBackToDefaults() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("config.json")
        try #"{"#.write(to: file, atomically: true, encoding: .utf8)
        #expect(AppConfig.load(from: file).snippetsDirectory == nil)
    }

    @Test func absolutePathIsCreated() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("library", isDirectory: true)
        let resolved = AppConfig(snippetsDirectory: target.path)
            .snippetsDirectoryURL(configURL: directory.appendingPathComponent("config.json"))

        var isDirectory: ObjCBool = false
        #expect(resolved.standardizedFileURL.path == target.standardizedFileURL.path)
        #expect(FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    @Test func relativePathResolvesAgainstConfigDirectory() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let resolved = AppConfig(snippetsDirectory: "nested/snippets")
            .snippetsDirectoryURL(configURL: directory.appendingPathComponent("config.json"))
        let expected = directory.appendingPathComponent("nested/snippets", isDirectory: true)

        #expect(resolved.standardizedFileURL.path == expected.standardizedFileURL.path)
        #expect(FileManager.default.fileExists(atPath: expected.path))
    }

    @Test func prepareForEditingSeedsTemplateOnce() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("config.json")
        #expect(try AppConfig.prepareForEditing(at: file) == file)
        #expect(AppConfig.load(from: file).snippetsDirectory != nil)
        #expect(try String(contentsOf: file, encoding: .utf8).contains("_comment"))

        try #"{"snippetsDirectory":"custom"}"#
            .write(to: file, atomically: true, encoding: .utf8)
        _ = try AppConfig.prepareForEditing(at: file)
        #expect(AppConfig.load(from: file).snippetsDirectory == "custom")
    }
}
