import Foundation
import Testing

@testable import Heycast

private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

private func app(_ name: String, bundle: String? = nil) -> LaunchableApp {
    LaunchableApp(
        url: URL(fileURLWithPath: "/Applications/\(name).app"),
        name: name,
        bundleIdentifier: bundle
    )
}

private func temporaryUsageFile() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("heycast-usage-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("usage.json")
}

@Suite struct AppUsageTests {
    @Test func scoreDampsLaunchCount() {
        #expect(AppUsage(launchCount: 0, lastLaunched: epoch).score(at: epoch) == 0)
        #expect(AppUsage(launchCount: 1, lastLaunched: epoch).score(at: epoch) == 1)
        #expect(AppUsage(launchCount: 7, lastLaunched: epoch).score(at: epoch) == 3)
    }

    @Test func scoreHalvesEveryHalfLife() {
        let fresh = AppUsage(launchCount: 5, lastLaunched: epoch)
        let oneHalfLife = fresh.score(at: epoch.addingTimeInterval(UsageStore.recencyHalfLife))
        let twoHalfLives = fresh.score(at: epoch.addingTimeInterval(2 * UsageStore.recencyHalfLife))

        #expect(abs(oneHalfLife - fresh.score(at: epoch) / 2) < 1e-9)
        #expect(abs(twoHalfLives - fresh.score(at: epoch) / 4) < 1e-9)
    }

    @Test func futureLaunchIsNotAmplified() {
        let future = AppUsage(launchCount: 1, lastLaunched: epoch.addingTimeInterval(3_600))
        #expect(abs(future.score(at: epoch) - 1) < 1e-9)
    }

    @Test func usageKeyPrefersBundleIdentifier() {
        #expect(app("Safari", bundle: "com.apple.Safari").usageKey == "com.apple.Safari")
    }

    @Test func usageKeyFallsBackToPath() {
        let bare = LaunchableApp(
            url: URL(fileURLWithPath: "/Applications/Bare.app"),
            name: "Bare",
            bundleIdentifier: nil
        )
        #expect(bare.usageKey == "/Applications/Bare.app")
    }
}

@Suite struct UsageStoreTests {
    @Test func recordsAndReloadsLaunchHistory() throws {
        let file = try temporaryUsageFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let safari = app("Safari", bundle: "com.apple.Safari")
        let store = UsageStore(fileURL: file)
        store.recordLaunch(of: safari, at: epoch)
        store.recordLaunch(of: safari, at: epoch.addingTimeInterval(60))
        store.recordLaunch(of: safari, at: epoch.addingTimeInterval(120))

        let reloaded = UsageStore(fileURL: file)
        let entry = reloaded.ranking(now: epoch.addingTimeInterval(120)).entries["com.apple.Safari"]
        #expect(entry?.launchCount == 3)
        #expect(entry?.lastLaunched == epoch.addingTimeInterval(120))
    }

    @Test func pruneKeepsMostRecentlyLaunched() throws {
        let file = try temporaryUsageFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let store = UsageStore(fileURL: file)
        let total = UsageStore.maxEntries + 5
        for index in 0..<total {
            store.recordLaunch(
                of: app("App\(index)", bundle: "bundle.\(index)"),
                at: epoch.addingTimeInterval(Double(index))
            )
        }

        let entries = UsageStore(fileURL: file).ranking(now: epoch).entries
        #expect(entries.count == UsageStore.maxEntries)
        #expect(entries["bundle.0"] == nil)
        #expect(entries["bundle.4"] == nil)
        #expect(entries["bundle.5"]?.launchCount == 1)
        #expect(entries["bundle.\(total - 1)"] != nil)
    }

    @Test func unreadableHistoryIsIgnored() throws {
        let file = try temporaryUsageFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        try Data("{".utf8).write(to: file)
        #expect(UsageStore(fileURL: file).ranking(now: epoch).entries.isEmpty)
    }

    @Test func unknownHistoryVersionIsIgnored() throws {
        let file = try temporaryUsageFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let json = #"{"version":2,"apps":{"com.apple.Safari":{"launchCount":9,"lastLaunched":"2023-11-14T22:13:20Z"}}}"#
        try Data(json.utf8).write(to: file)
        #expect(UsageStore(fileURL: file).ranking(now: epoch).entries.isEmpty)
    }
}
