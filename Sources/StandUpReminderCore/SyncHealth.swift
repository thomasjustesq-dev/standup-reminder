import Foundation

/// Last-known multi-device sync status for menu bar / CLI / iOS.
struct SyncHealth: Codable, Equatable {
    var lastPushAt: Date?
    var lastPullAt: Date?
    var lastPullMessage: String?
    var lastPullWasStale: Bool = false
    var lastRuntimeRemoteAt: Date?
    var lastRuntimeRemoteDevice: String?
    var lastMigrationAt: Date?
    var migrationNote: String?
    /// True when last config pull saw an empty container — prompt a seed push.
    var cloudContainerEmpty: Bool = false
    /// Dismissed seed banner until the next empty observation.
    var seedBannerDismissed: Bool = false

    enum CodingKeys: String, CodingKey {
        case lastPushAt, lastPullAt, lastPullMessage, lastPullWasStale
        case lastRuntimeRemoteAt, lastRuntimeRemoteDevice
        case lastMigrationAt, migrationNote
        case cloudContainerEmpty, seedBannerDismissed
    }

    init(
        lastPushAt: Date? = nil,
        lastPullAt: Date? = nil,
        lastPullMessage: String? = nil,
        lastPullWasStale: Bool = false,
        lastRuntimeRemoteAt: Date? = nil,
        lastRuntimeRemoteDevice: String? = nil,
        lastMigrationAt: Date? = nil,
        migrationNote: String? = nil,
        cloudContainerEmpty: Bool = false,
        seedBannerDismissed: Bool = false
    ) {
        self.lastPushAt = lastPushAt
        self.lastPullAt = lastPullAt
        self.lastPullMessage = lastPullMessage
        self.lastPullWasStale = lastPullWasStale
        self.lastRuntimeRemoteAt = lastRuntimeRemoteAt
        self.lastRuntimeRemoteDevice = lastRuntimeRemoteDevice
        self.lastMigrationAt = lastMigrationAt
        self.migrationNote = migrationNote
        self.cloudContainerEmpty = cloudContainerEmpty
        self.seedBannerDismissed = seedBannerDismissed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastPushAt = try c.decodeIfPresent(Date.self, forKey: .lastPushAt)
        lastPullAt = try c.decodeIfPresent(Date.self, forKey: .lastPullAt)
        lastPullMessage = try c.decodeIfPresent(String.self, forKey: .lastPullMessage)
        lastPullWasStale = try c.decodeIfPresent(Bool.self, forKey: .lastPullWasStale) ?? false
        lastRuntimeRemoteAt = try c.decodeIfPresent(Date.self, forKey: .lastRuntimeRemoteAt)
        lastRuntimeRemoteDevice = try c.decodeIfPresent(String.self, forKey: .lastRuntimeRemoteDevice)
        lastMigrationAt = try c.decodeIfPresent(Date.self, forKey: .lastMigrationAt)
        migrationNote = try c.decodeIfPresent(String.self, forKey: .migrationNote)
        cloudContainerEmpty = try c.decodeIfPresent(Bool.self, forKey: .cloudContainerEmpty) ?? false
        seedBannerDismissed = try c.decodeIfPresent(Bool.self, forKey: .seedBannerDismissed) ?? false
    }

    static var fileURL: URL { Paths.appSupport.appendingPathComponent("sync-health.json") }

    static func load() -> SyncHealth {
        guard let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONCoding.decoder().decode(SyncHealth.self, from: data) else {
            return SyncHealth()
        }
        return doc
    }

    static func save(_ health: SyncHealth) {
        guard let data = try? JSONCoding.encoder().encode(health) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Show first-run re-seed UI when the new iCloud container has no config.
    var shouldShowSeedBanner: Bool {
        cloudContainerEmpty && !seedBannerDismissed
    }

    /// Human summary for menu / status / doctor.
    func summary(now: Date = Date(), iCloudEnabled: Bool) -> String {
        guard iCloudEnabled else { return "iCloud sync off" }
        var parts: [String] = []
        if let push = lastPushAt {
            parts.append("push \(Self.age(push, now: now))")
        } else {
            parts.append("never pushed")
        }
        if let pull = lastPullAt {
            parts.append("pull \(Self.age(pull, now: now))")
        }
        if lastPullWasStale {
            parts.append("local newer than remote")
        }
        if cloudContainerEmpty {
            parts.append("iCloud empty — push once to seed")
        }
        if let remoteAt = lastRuntimeRemoteAt {
            let stale = !AuthorityLease.isAlive(updatedAt: remoteAt, now: now)
            let device = lastRuntimeRemoteDevice ?? "peer"
            parts.append(stale ? "runtime stale (\(device))" : "runtime \(device) \(Self.age(remoteAt, now: now))")
        }
        if let note = migrationNote, !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: " · ")
    }

    private static func age(_ date: Date, now: Date) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86400 { return "\(s / 3600)h ago" }
        return "\(s / 86400)d ago"
    }
}

/// Opt-in counters: how often each quiet rule blocked a fire (per day).
struct BlockStats: Codable, Equatable {
    var dayKey: String = ""
    var byReason: [String: Int] = [:]

    static var fileURL: URL { Paths.appSupport.appendingPathComponent("block-stats.json") }

    static func load() -> BlockStats {
        guard let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONCoding.decoder().decode(BlockStats.self, from: data) else {
            return BlockStats()
        }
        return doc
    }

    static func save(_ stats: BlockStats) {
        guard let data = try? JSONCoding.encoder().encode(stats) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    mutating func record(reason: String, dayKey: String) {
        if self.dayKey != dayKey {
            self.dayKey = dayKey
            byReason = [:]
        }
        byReason[reason, default: 0] += 1
    }

    func report() -> String {
        guard !byReason.isEmpty else { return "No blocks recorded today (\(dayKey.isEmpty ? "—" : dayKey))." }
        let lines = byReason.sorted { $0.value > $1.value }.map { "  \($0.key): \($0.value)" }
        return "Blocks \(dayKey):\n" + lines.joined(separator: "\n")
    }
}
