import Foundation

extension Notification.Name {
    static let configDidSaveForCloud = Notification.Name("configDidSaveForCloud")
}

/// Multi-Mac sync via iCloud Drive Documents (opt-in).
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

    static func push(config: AppConfig, profiles: ProfileDocument) {
        guard let folder = ensureFolder() else {
            AppLog.write("iCloud unavailable — enable iCloud Drive for this Mac/user")
            return
        }
        let encoder = JSONCoding.encoder()
        if let data = try? encoder.encode(config) {
            try? data.write(to: folder.appendingPathComponent("config.json"), options: .atomic)
        }
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: folder.appendingPathComponent("profiles.json"), options: .atomic)
        }
        AppLog.write("iCloud sync push OK → \(folder.path)")
    }

    static func pull() -> (AppConfig, ProfileDocument)? {
        guard let folder = containerURL else { return nil }
        let configURL = folder.appendingPathComponent("config.json")
        let profilesURL = folder.appendingPathComponent("profiles.json")
        let decoder = JSONCoding.decoder()
        guard let configData = try? Data(contentsOf: configURL),
              let config = try? decoder.decode(AppConfig.self, from: configData) else {
            return nil
        }
        let profiles = (try? decoder.decode(ProfileDocument.self, from: Data(contentsOf: profilesURL))) ?? .default
        AppLog.write("iCloud sync pull OK")
        return (config, profiles)
    }
}
