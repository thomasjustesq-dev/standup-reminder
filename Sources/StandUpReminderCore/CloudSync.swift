import Foundation

extension Notification.Name {
    static let configDidSaveForCloud = Notification.Name("configDidSaveForCloud")
}

/// Envelope written to iCloud so devices can compare freshness before
/// applying a pull. Older bare-payload files (v4.1 and earlier) are still
/// readable; they get their file modification date as the stamp.
struct CloudEnvelope<Payload: Codable>: Codable {
    var updatedAt: Date
    var deviceName: String
    var payload: Payload
}

/// Multi-device sync via iCloud Drive Documents (opt-in).
enum CloudSync {
    static var containerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/StandUpReminder", isDirectory: true)
    }

    static func ensureFolder() -> URL? {
        guard let url = containerURL else { return nil }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    enum PullOutcome {
        /// Config always present on success; profiles nil when never pushed.
        case success(config: AppConfig, profiles: ProfileDocument?, remoteUpdatedAt: Date)
        /// No iCloud container (signed out, iCloud Drive off, or missing entitlement).
        case unavailable
        /// Container reachable but nothing has been pushed yet.
        case empty
        /// Pushed data exists but iCloud hasn't materialized it locally yet.
        case downloading
        /// A present file failed to read/decode — nothing applied.
        case corrupt(String)
        /// Remote is older than the local save — nothing applied (push instead).
        case staleRemote(remote: Date, local: Date)

        var userMessage: String {
            switch self {
            case .success: return "Pulled from iCloud"
            case .unavailable: return "iCloud unavailable — check iCloud Drive"
            case .empty: return "Nothing in iCloud yet — push from a synced device first"
            case .downloading: return "iCloud copy is still downloading — try again in a moment"
            case .corrupt(let detail): return "iCloud copy unreadable (\(detail)) — nothing changed"
            case .staleRemote: return "Local settings are newer than the iCloud copy — push instead"
            }
        }
    }

    @discardableResult
    static func push(config: AppConfig, profiles: ProfileDocument, deviceName: String = defaultDeviceName()) -> Bool {
        guard let folder = ensureFolder() else {
            AppLog.write("iCloud push failed — no ubiquity container (iCloud Drive off or entitlement missing)")
            return false
        }
        let encoder = JSONCoding.encoder()
        let stamp = Date()
        do {
            let configData = try encoder.encode(CloudEnvelope(updatedAt: stamp, deviceName: deviceName, payload: config))
            try configData.write(to: folder.appendingPathComponent("config.json"), options: .atomic)
            let profilesData = try encoder.encode(CloudEnvelope(updatedAt: stamp, deviceName: deviceName, payload: profiles))
            try profilesData.write(to: folder.appendingPathComponent("profiles.json"), options: .atomic)
        } catch {
            AppLog.write("iCloud push failed: \(error.localizedDescription)")
            return false
        }
        AppLog.write("iCloud sync push OK → \(folder.path)")
        return true
    }

    /// `localModifiedAt` is the timestamp of the last *user* save; a remote
    /// stamp at or before it is refused so a pull can never clobber newer
    /// local state. Pass nil to accept any remote — callers must pass nil on
    /// a fresh install (the auto-created defaults file does not count as
    /// user state, or a new device could never pull its settings down).
    static func pull(localModifiedAt: Date?) -> PullOutcome {
        guard let folder = containerURL else { return .unavailable }
        let configURL = folder.appendingPathComponent("config.json")
        let profilesURL = folder.appendingPathComponent("profiles.json")
        startDownloadIfNeeded(configURL)
        startDownloadIfNeeded(profilesURL)

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            // An evicted iCloud file exists only as its ".name.icloud"
            // placeholder — that is pushed data mid-download, not "empty".
            return isUndownloadedPlaceholder(configURL) ? .downloading : .empty
        }
        guard let configData = try? Data(contentsOf: configURL) else {
            return .corrupt("config.json unreadable")
        }
        guard let (config, remoteStamp) = decodeStamped(
            AppConfig.self, from: configData, fileURL: configURL,
            bareMarkerKeys: ["enabled", "intervalMinutes", "features"]
        ) else {
            return .corrupt("config.json failed to decode")
        }
        if let local = localModifiedAt, remoteStamp <= local {
            AppLog.write("iCloud pull refused — remote \(remoteStamp) is not newer than local \(local)")
            return .staleRemote(remote: remoteStamp, local: local)
        }

        var profiles: ProfileDocument?
        if FileManager.default.fileExists(atPath: profilesURL.path) {
            guard let profilesData = try? Data(contentsOf: profilesURL),
                  let (doc, _) = decodeStamped(
                    ProfileDocument.self, from: profilesData, fileURL: profilesURL,
                    bareMarkerKeys: ["profiles", "activeProfileId"]
                  ),
                  !doc.profiles.isEmpty else {
                // A present-but-broken profiles file must fail the pull rather
                // than silently substituting factory defaults for every profile.
                return .corrupt("profiles.json failed to decode")
            }
            profiles = doc
        } else if isUndownloadedPlaceholder(profilesURL) {
            // Don't half-apply a pull while profiles are still materializing.
            return .downloading
        }
        AppLog.write("iCloud sync pull OK (remote stamp \(remoteStamp))")
        return .success(config: config.validated(), profiles: profiles, remoteUpdatedAt: remoteStamp)
    }

    /// Decode an envelope, or a v4.1 bare payload stamped with file mtime.
    /// The fallback is gated two ways: bytes that *look* like an envelope
    /// (payload + updatedAt keys) but fail envelope decode are corrupt, and a
    /// bare decode only counts when a marker key of the real payload type is
    /// present — AppConfig decodes "successfully" from any JSON object (every
    /// field is optional), which would silently turn garbage into factory
    /// defaults and defeat the whole no-wipe contract.
    /// Internal rather than private so CloudSyncTests can pin the contract
    /// described above; it is not called from outside CloudSync.
    static func decodeStamped<T: Codable>(
        _ type: T.Type, from data: Data, fileURL: URL, bareMarkerKeys: [String]
    ) -> (T, Date)? {
        let decoder = JSONCoding.decoder()
        guard let topLevel = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if topLevel["payload"] != nil, topLevel["updatedAt"] != nil {
            guard let envelope = try? decoder.decode(CloudEnvelope<T>.self, from: data) else { return nil }
            return (envelope.payload, envelope.updatedAt)
        }
        guard bareMarkerKeys.contains(where: { topLevel[$0] != nil }),
              let payload = try? decoder.decode(T.self, from: data) else { return nil }
        let mtime = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
        return (payload, mtime ?? .distantPast)
    }

    private static func isUndownloadedPlaceholder(_ url: URL) -> Bool {
        let placeholder = url.deletingLastPathComponent()
            .appendingPathComponent("." + url.lastPathComponent + ".icloud")
        return FileManager.default.fileExists(atPath: placeholder.path)
    }

    /// iCloud files can be evicted placeholders; request the download so a
    /// retry shortly after succeeds instead of failing forever.
    private static func startDownloadIfNeeded(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    static func defaultDeviceName() -> String {
        ProcessInfo.processInfo.hostName
    }

    // MARK: Cross-device runtime + stats

    /// Break-cadence state shared across devices so "Done" on the phone
    /// re-anchors the Mac (and vice versa) instead of each device running its
    /// own drifting schedule.
    struct RuntimeDoc: Codable {
        var updatedAt: Date
        var deviceName: String
        var lastReminderAt: Date?
        var lastAcknowledgedAt: Date?
        var snoozeUntil: Date?
        var skipRestOfDayDate: Date?
    }

    /// Stable per-install identifier for the per-device stats file.
    static func deviceId() -> String {
        let url = Paths.appSupport.appendingPathComponent("device-id")
        if let existing = try? String(contentsOf: url, encoding: .utf8),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let fresh = UUID().uuidString
        try? fresh.write(to: url, atomically: true, encoding: .utf8)
        return fresh
    }

    @discardableResult
    static func pushRuntime(_ doc: RuntimeDoc) -> Bool {
        guard let folder = ensureFolder(),
              let data = try? JSONCoding.encoder().encode(doc) else { return false }
        do {
            try data.write(to: folder.appendingPathComponent("runtime.json"), options: .atomic)
            return true
        } catch {
            AppLog.write("iCloud runtime push failed: \(error.localizedDescription)")
            return false
        }
    }

    static func pullRuntime() -> RuntimeDoc? {
        guard let folder = containerURL else { return nil }
        let url = folder.appendingPathComponent("runtime.json")
        startDownloadIfNeeded(url)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONCoding.decoder().decode(RuntimeDoc.self, from: data)
    }

    @discardableResult
    static func pushStats(_ stats: StatsSnapshot, deviceId: String) -> Bool {
        guard let folder = ensureFolder(),
              let data = try? JSONCoding.encoder().encode(stats) else { return false }
        do {
            try data.write(to: folder.appendingPathComponent("stats-\(deviceId).json"), options: .atomic)
            return true
        } catch {
            AppLog.write("iCloud stats push failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Every other device's stats snapshot, for a display-time merge. The
    /// local snapshot is never overwritten by remote data.
    static func pullRemoteStats(excludingDeviceId: String) -> [StatsSnapshot] {
        guard let folder = containerURL,
              let entries = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil
              ) else { return [] }
        let decoder = JSONCoding.decoder()
        return entries.compactMap { url in
            let name = url.lastPathComponent
            guard name.hasPrefix("stats-"), name.hasSuffix(".json"),
                  !name.contains(excludingDeviceId) else { return nil }
            startDownloadIfNeeded(url)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(StatsSnapshot.self, from: data)
        }
    }
}
