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

    static func load() -> ProfileDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(ProfileDocument.self, from: data),
              !doc.profiles.isEmpty else {
            let doc = ProfileDocument.default
            save(doc)
            return doc
        }
        return doc
    }

    static func save(_ document: ProfileDocument) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(document) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func activeProfile(in document: ProfileDocument) -> ReminderProfile {
        document.profiles.first(where: { $0.id == document.activeProfileId }) ?? document.profiles[0]
    }
}
