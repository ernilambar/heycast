import Foundation

/// One application's persisted launch history.
struct AppUsage: Codable, Equatable, Sendable {
    var launchCount: Int
    var lastLaunched: Date

    /// Recency-weighted frequency used for ordering. The log damps raw launch
    /// counts so one app cannot dominate forever; the weight halves every
    /// `halfLife` since the last launch so recent use wins over old habits.
    func score(
        at now: Date,
        halfLife: TimeInterval = UsageStore.recencyHalfLife
    ) -> Double {
        let age = now.timeIntervalSince(lastLaunched)
        let recency = age > 0 ? pow(0.5, age / halfLife) : 1
        return log2(1 + Double(launchCount)) * recency
    }
}

/// Immutable snapshot of usage for one ranking pass.
struct UsageRanking: Sendable {
    static let empty = UsageRanking(entries: [:], now: .distantPast)

    let entries: [String: AppUsage]
    let now: Date

    func score(for app: LaunchableApp) -> Double {
        entries[app.usageKey]?.score(at: now) ?? 0
    }
}

/// Persists launch counts and recency to Application Support so the palette
/// keeps ranking frequently launched apps first across restarts.
final class UsageStore: @unchecked Sendable {
    static let shared = UsageStore()

    /// Older entries are dropped once the history grows past this size.
    static let maxEntries = 200
    /// Time for the recency weight to halve.
    static let recencyHalfLife: TimeInterval = 30 * 24 * 60 * 60

    private static let version = 1

    private let fileURL: URL
    private let lock = NSLock()
    private var entries: [String: AppUsage]

    init(fileURL: URL = UsageStore.defaultFileURL()) {
        self.fileURL = fileURL
        entries = Self.load(from: fileURL)
    }

    /// Current usage plus the timestamp its scores are measured against.
    func ranking(now: Date = Date()) -> UsageRanking {
        lock.lock()
        defer { lock.unlock() }
        return UsageRanking(entries: entries, now: now)
    }

    /// Counts a successful launch and writes the history back atomically.
    func recordLaunch(of app: LaunchableApp, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }

        var usage = entries[app.usageKey] ?? AppUsage(launchCount: 0, lastLaunched: date)
        usage.launchCount += 1
        usage.lastLaunched = date
        entries[app.usageKey] = usage

        prune()
        persist()
    }

    // MARK: - Persistence

    private static func defaultFileURL() -> URL {
        SupportDirectory.usageFile
    }

    private static func load(from url: URL) -> [String: AppUsage] {
        guard let data = try? Data(contentsOf: url) else { return [:] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let stored = try decoder.decode(StoredUsage.self, from: data)
            guard stored.version == version else {
                NSLog("Heycast: ignoring usage history version %d", stored.version)
                return [:]
            }
            return stored.apps
        } catch {
            NSLog(
                "Heycast: ignoring unreadable usage history at %@: %@",
                url.path,
                error.localizedDescription
            )
            return [:]
        }
    }

    private func prune() {
        guard entries.count > Self.maxEntries else { return }
        let kept = entries
            .sorted { $0.value.lastLaunched > $1.value.lastLaunched }
            .prefix(Self.maxEntries)
        entries = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(
                StoredUsage(version: Self.version, apps: entries)
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog(
                "Heycast: could not save usage history to %@: %@",
                fileURL.path,
                error.localizedDescription
            )
        }
    }

    private struct StoredUsage: Codable {
        let version: Int
        let apps: [String: AppUsage]
    }
}
