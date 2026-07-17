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
        /// A present file failed to read/decode — nothing applied.
        case corrupt(String)
        /// Remote is older than the local save — nothing applied (push instead).
        case staleRemote(remote: Date, local: Date)

        var userMessage: String {
            switch self {
            case .success: return "Pulled from iCloud"
            case .unavailable: return "iCloud unavailable — check iCloud Drive"
            case .empty: return "Nothing in iCloud yet — push from a synced device first"
            case .corrupt(let detail): return "iCloud copy unreadable (\(detail)) — nothing changed"
            case .staleRemote: return "iCloud copy is older than this device — push instead"
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

    /// `localModifiedAt` is the local config file's last save; a remote stamp
    /// at or before it is refused so a pull can never clobber newer local
    /// state. Pass nil to accept any remote (fresh install).
    static func pull(localModifiedAt: Date?) -> PullOutcome {
        guard let folder = containerURL else { return .unavailable }
        let configURL = folder.appendingPathComponent("config.json")
        let profilesURL = folder.appendingPathComponent("profiles.json")
        startDownloadIfNeeded(configURL)
        startDownloadIfNeeded(profilesURL)

        guard FileManager.default.fileExists(atPath: configURL.path) else { return .empty }
        guard let configData = try? Data(contentsOf: configURL) else {
            return .corrupt("config.json not downloaded or unreadable")
        }
        guard let (config, remoteStamp) = decodeStamped(AppConfig.self, from: configData, fileURL: configURL) else {
            return .corrupt("config.json failed to decode")
        }
        if let local = localModifiedAt, remoteStamp <= local {
            AppLog.write("iCloud pull refused — remote \(remoteStamp) is not newer than local \(local)")
            return .staleRemote(remote: remoteStamp, local: local)
        }

        var profiles: ProfileDocument?
        if FileManager.default.fileExists(atPath: profilesURL.path) {
            guard let profilesData = try? Data(contentsOf: profilesURL),
                  let (doc, _) = decodeStamped(ProfileDocument.self, from: profilesData, fileURL: profilesURL),
                  !doc.profiles.isEmpty else {
                // A present-but-broken profiles file must fail the pull rather
                // than silently substituting factory defaults for every profile.
                return .corrupt("profiles.json failed to decode")
            }
            profiles = doc
        }
        AppLog.write("iCloud sync pull OK (remote stamp \(remoteStamp))")
        return .success(config: config.validated(), profiles: profiles, remoteUpdatedAt: remoteStamp)
    }

    private static func decodeStamped<T: Codable>(_ type: T.Type, from data: Data, fileURL: URL) -> (T, Date)? {
        let decoder = JSONCoding.decoder()
        if let envelope = try? decoder.decode(CloudEnvelope<T>.self, from: data) {
            return (envelope.payload, envelope.updatedAt)
        }
        // v4.1 bare payload — stamp with the file's modification date.
        if let payload = try? decoder.decode(T.self, from: data) {
            let mtime = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
            return (payload, mtime ?? .distantPast)
        }
        return nil
    }

    /// iCloud files can be evicted placeholders; request the download so a
    /// retry shortly after succeeds instead of failing forever.
    private static func startDownloadIfNeeded(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    static func defaultDeviceName() -> String {
        ProcessInfo.processInfo.hostName
    }
}
