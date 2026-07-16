import Foundation

/// Shared snapshot for WidgetKit / menu bar consumers.
struct WidgetSnapshot: Codable, Equatable {
    var nextFireAt: Date?
    var statusMessage: String
    var weekDone: Int
    var weekShown: Int
    var deskPhase: String?
    var countdownMinutes: Int?
    var profileName: String
    var updatedAt: Date

    static var fileURL: URL { Paths.appSupport.appendingPathComponent("widget.json") }
    static var appGroupID = "group.com.user.StandUpReminder"
}

enum WidgetSnapshotWriter {
    static func write(
        from config: AppConfig? = nil,
        nextFireAt: Date? = nil,
        statusMessage: String = "",
        stats: StatsSnapshot? = nil,
        deskPhase: DeskPhase? = nil,
        profileName: String = "Default"
    ) {
        let week = (stats ?? StatsStore.load()).weekSummary()
        let countdown: Int? = {
            guard let nextFireAt else { return nil }
            return max(0, Int(nextFireAt.timeIntervalSinceNow / 60))
        }()
        let snap = WidgetSnapshot(
            nextFireAt: nextFireAt,
            statusMessage: statusMessage,
            weekDone: week.done,
            weekShown: week.shown,
            deskPhase: deskPhase?.rawValue,
            countdownMinutes: countdown,
            profileName: profileName,
            updatedAt: Date()
        )
        if let data = try? JSONCoding.encoder().encode(snap) {
            try? data.write(to: WidgetSnapshot.fileURL, options: .atomic)
            if let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroupID) {
                defaults.set(data, forKey: "widgetSnapshot")
            }
        }
        _ = config
    }
}
