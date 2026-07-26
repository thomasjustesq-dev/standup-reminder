import Foundation

struct ReminderProfile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var config: AppConfig
}

struct ProfileDocument: Codable, Equatable {
    var activeProfileId: String
    var profiles: [ReminderProfile]

    static let `default`: ProfileDocument = {
        let office = ReminderProfile(id: "office", name: "Office Mac", config: .default)
        var laptopConfig = AppConfig.default
        laptopConfig.intervalMinutes = 25
        laptopConfig.adaptiveMaxMinutes = 40
        laptopConfig.denylistBundleIds = AppConfig.defaultDenylist.filter { $0 != "com.google.Chrome" }
        let laptop = ReminderProfile(id: "laptop", name: "Laptop", config: laptopConfig)
        return ProfileDocument(activeProfileId: office.id, profiles: [office, laptop])
    }()
}

enum ProfileStore {
    static var fileURL: URL { Paths.appSupport.appendingPathComponent("profiles.json") }

    /// Same contract as ConfigStore.load(): a present-but-broken file is
    /// preserved (profiles.json.corrupt) and defaults are used in memory only;
    /// the user's file is never overwritten by a failed decode.
    static func load() -> ProfileDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let doc = ProfileDocument.default
            save(doc)
            return doc
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            AppLog.write("profiles.json unreadable — running on defaults, file left untouched")
            return ProfileDocument.default
        }
        do {
            let doc = try JSONCoding.decoder().decode(ProfileDocument.self, from: data)
            guard !doc.profiles.isEmpty else {
                AppLog.write("profiles.json has no profiles — running on defaults, file left untouched")
                return ProfileDocument.default
            }
            return doc
        } catch {
            ConfigStore.preserveCorrupt(fileURL)
            AppLog.write("profiles.json failed to decode (\(error)) — preserved as profiles.json.corrupt, running on defaults")
            return ProfileDocument.default
        }
    }

    static func save(_ document: ProfileDocument) {
        guard let data = try? JSONCoding.encoder().encode(document) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func activeProfile(in document: ProfileDocument) -> ReminderProfile {
        document.profiles.first(where: { $0.id == document.activeProfileId }) ?? document.profiles[0]
    }
}
