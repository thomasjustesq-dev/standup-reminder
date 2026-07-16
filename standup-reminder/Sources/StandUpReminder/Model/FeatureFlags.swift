import Foundation

struct QuietWindow: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var label: String

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let mins = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        if start <= end { return mins >= start && mins < end }
        return mins >= start || mins < end
    }
}

struct TeamQuietConfig: Codable, Equatable {
    var enabled: Bool
    /// Remote JSON URL with `{ "windows": [ { "startHour":…, "label":… } ] }`
    var feedURL: String
    var windows: [QuietWindow]
    var lastFetchedAt: Date?

    static let `default` = TeamQuietConfig(enabled: false, feedURL: "", windows: [], lastFetchedAt: nil)
}

struct FeatureFlags: Codable, Equatable {
    var iCloudSyncEnabled: Bool
    var teamQuiet: TeamQuietConfig
    var voiceAnnouncementsEnabled: Bool
    var speakOnlyWithHeadphones: Bool
    var watchCompanionEnabled: Bool
    var learnedScheduleEnabled: Bool
    var applyLearnedScheduleAutomatically: Bool
    var webcamStillnessEnabled: Bool
    var webcamStillnessMinutes: Int
    var weatherBreaksEnabled: Bool
    var diagnosticsEnabled: Bool
    var diagnosticsEndpoint: String
    var sparkleFeedURL: String
    var preferSparkleUpdates: Bool
    var showSampleDayTour: Bool
    var reduceMotionOverrides: Bool
    var breakDemoSymbolsEnabled: Bool

    static let `default` = FeatureFlags(
        iCloudSyncEnabled: false,
        teamQuiet: .default,
        voiceAnnouncementsEnabled: true,
        speakOnlyWithHeadphones: true,
        watchCompanionEnabled: true,
        learnedScheduleEnabled: true,
        applyLearnedScheduleAutomatically: false,
        webcamStillnessEnabled: false,
        webcamStillnessMinutes: 45,
        weatherBreaksEnabled: true,
        diagnosticsEnabled: false,
        diagnosticsEndpoint: "",
        sparkleFeedURL: "",
        preferSparkleUpdates: true,
        showSampleDayTour: true,
        reduceMotionOverrides: true,
        breakDemoSymbolsEnabled: true
    )
}
