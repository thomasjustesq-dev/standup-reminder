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

    init(id: String = UUID().uuidString, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, label: String) {
        self.id = id
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.label = label
    }

    enum CodingKeys: String, CodingKey { case id, startHour, startMinute, endHour, endMinute, label }

    init(from decoder: Decoder) throws {
        let d = try decoder.container(keyedBy: CodingKeys.self)
        id = try d.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        startHour = try d.decodeIfPresent(Int.self, forKey: .startHour) ?? 0
        startMinute = try d.decodeIfPresent(Int.self, forKey: .startMinute) ?? 0
        endHour = try d.decodeIfPresent(Int.self, forKey: .endHour) ?? 0
        endMinute = try d.decodeIfPresent(Int.self, forKey: .endMinute) ?? 0
        label = try d.decodeIfPresent(String.self, forKey: .label) ?? ""
    }
}

struct TeamQuietConfig: Codable, Equatable {
    var enabled: Bool
    /// Remote JSON URL with `{ "windows": [ { "startHour":…, "label":… } ] }`
    var feedURL: String
    var windows: [QuietWindow]
    var lastFetchedAt: Date?

    static let `default` = TeamQuietConfig(enabled: false, feedURL: "", windows: [], lastFetchedAt: nil)

    init(enabled: Bool, feedURL: String, windows: [QuietWindow], lastFetchedAt: Date?) {
        self.enabled = enabled
        self.feedURL = feedURL
        self.windows = windows
        self.lastFetchedAt = lastFetchedAt
    }

    enum CodingKeys: String, CodingKey { case enabled, feedURL, windows, lastFetchedAt }

    init(from decoder: Decoder) throws {
        let d = try decoder.container(keyedBy: CodingKeys.self)
        let base = TeamQuietConfig.default
        enabled = try d.decodeIfPresent(Bool.self, forKey: .enabled) ?? base.enabled
        feedURL = try d.decodeIfPresent(String.self, forKey: .feedURL) ?? base.feedURL
        windows = try d.decodeIfPresent([QuietWindow].self, forKey: .windows) ?? base.windows
        lastFetchedAt = try d.decodeIfPresent(Date.self, forKey: .lastFetchedAt)
    }
}

/// Decoding is per-field tolerant, like AppConfig: a missing or unknown key
/// falls back to its default instead of failing the whole document. A strict
/// synthesized decoder here once meant "add one flag in an update → every
/// existing config.json fails to decode → user settings wiped to defaults".
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
    /// Manual weather coordinates. When set they beat both CoreLocation and
    /// the timezone city table (which maps all of US Central to Chicago).
    var weatherLatitude: Double?
    var weatherLongitude: Double?
    /// iOS Lock Screen / Dynamic Island countdown.
    var liveActivityEnabled: Bool
    /// Optional Fighting Shape backend: on low-recovery days the cadence
    /// gently tightens. Base URL only — the API key lives in a local file
    /// (fightingshape-api-key in Application Support), never in synced config.
    var fightingShapeEnabled: Bool
    var fightingShapeBaseURL: String
    /// When true, a meeting-heavy calendar day auto-selects the Meeting-heavy pack.
    var autoProfileFromCalendar: Bool
    /// Record how often each quiet rule blocked a fire (menu/CLI report).
    var recordBlockReasons: Bool
    /// Soft-credit a break when the Apple Stand hour for the current hour is already closed.
    var creditStandHourAsBreak: Bool
    /// Calendar event title substrings that are never treated as meetings.
    var calendarTitleDenylist: [String]
    /// Time-of-day pack rules (first match wins).
    var scheduleProfileRules: [ScheduleProfileRule]
    /// When true, guided break may activate the app over full-screen / denylist apps.
    var guidedBreakStealFocus: Bool

    /// Quiet defaults for new installs — power features stay opt-in.
    static let `default` = FeatureFlags(
        iCloudSyncEnabled: false,
        teamQuiet: .default,
        voiceAnnouncementsEnabled: false,
        speakOnlyWithHeadphones: true,
        watchCompanionEnabled: false,
        learnedScheduleEnabled: false,
        applyLearnedScheduleAutomatically: false,
        webcamStillnessEnabled: false,
        webcamStillnessMinutes: 45,
        weatherBreaksEnabled: false,
        diagnosticsEnabled: false,
        diagnosticsEndpoint: "",
        sparkleFeedURL: "",
        preferSparkleUpdates: false,
        showSampleDayTour: true,
        reduceMotionOverrides: true,
        breakDemoSymbolsEnabled: false,
        weatherLatitude: nil,
        weatherLongitude: nil,
        liveActivityEnabled: true,
        fightingShapeEnabled: false,
        fightingShapeBaseURL: "",
        autoProfileFromCalendar: false,
        recordBlockReasons: true,
        creditStandHourAsBreak: false,
        calendarTitleDenylist: ["focus block", "blocked", "deep work", "no meetings", "hold"],
        scheduleProfileRules: [],
        guidedBreakStealFocus: false
    )

    init(
        iCloudSyncEnabled: Bool, teamQuiet: TeamQuietConfig, voiceAnnouncementsEnabled: Bool,
        speakOnlyWithHeadphones: Bool, watchCompanionEnabled: Bool, learnedScheduleEnabled: Bool,
        applyLearnedScheduleAutomatically: Bool, webcamStillnessEnabled: Bool, webcamStillnessMinutes: Int,
        weatherBreaksEnabled: Bool, diagnosticsEnabled: Bool, diagnosticsEndpoint: String,
        sparkleFeedURL: String, preferSparkleUpdates: Bool, showSampleDayTour: Bool,
        reduceMotionOverrides: Bool, breakDemoSymbolsEnabled: Bool,
        weatherLatitude: Double? = nil, weatherLongitude: Double? = nil,
        liveActivityEnabled: Bool = true,
        fightingShapeEnabled: Bool = false, fightingShapeBaseURL: String = "",
        autoProfileFromCalendar: Bool = false,
        recordBlockReasons: Bool = true,
        creditStandHourAsBreak: Bool = false,
        calendarTitleDenylist: [String] = [],
        scheduleProfileRules: [ScheduleProfileRule] = [],
        guidedBreakStealFocus: Bool = false
    ) {
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.teamQuiet = teamQuiet
        self.voiceAnnouncementsEnabled = voiceAnnouncementsEnabled
        self.speakOnlyWithHeadphones = speakOnlyWithHeadphones
        self.watchCompanionEnabled = watchCompanionEnabled
        self.learnedScheduleEnabled = learnedScheduleEnabled
        self.applyLearnedScheduleAutomatically = applyLearnedScheduleAutomatically
        self.webcamStillnessEnabled = webcamStillnessEnabled
        self.webcamStillnessMinutes = webcamStillnessMinutes
        self.weatherBreaksEnabled = weatherBreaksEnabled
        self.diagnosticsEnabled = diagnosticsEnabled
        self.diagnosticsEndpoint = diagnosticsEndpoint
        self.sparkleFeedURL = sparkleFeedURL
        self.preferSparkleUpdates = preferSparkleUpdates
        self.showSampleDayTour = showSampleDayTour
        self.reduceMotionOverrides = reduceMotionOverrides
        self.breakDemoSymbolsEnabled = breakDemoSymbolsEnabled
        self.weatherLatitude = weatherLatitude
        self.weatherLongitude = weatherLongitude
        self.liveActivityEnabled = liveActivityEnabled
        self.fightingShapeEnabled = fightingShapeEnabled
        self.fightingShapeBaseURL = fightingShapeBaseURL
        self.autoProfileFromCalendar = autoProfileFromCalendar
        self.recordBlockReasons = recordBlockReasons
        self.creditStandHourAsBreak = creditStandHourAsBreak
        self.calendarTitleDenylist = calendarTitleDenylist
        self.scheduleProfileRules = scheduleProfileRules
        self.guidedBreakStealFocus = guidedBreakStealFocus
    }

    enum CodingKeys: String, CodingKey {
        case iCloudSyncEnabled, teamQuiet, voiceAnnouncementsEnabled, speakOnlyWithHeadphones
        case watchCompanionEnabled, learnedScheduleEnabled, applyLearnedScheduleAutomatically
        case webcamStillnessEnabled, webcamStillnessMinutes, weatherBreaksEnabled
        case diagnosticsEnabled, diagnosticsEndpoint, sparkleFeedURL, preferSparkleUpdates
        case showSampleDayTour, reduceMotionOverrides, breakDemoSymbolsEnabled
        case weatherLatitude, weatherLongitude
        case liveActivityEnabled, fightingShapeEnabled, fightingShapeBaseURL
        case autoProfileFromCalendar, recordBlockReasons, creditStandHourAsBreak
        case calendarTitleDenylist, scheduleProfileRules, guidedBreakStealFocus
    }

    init(from decoder: Decoder) throws {
        let d = try decoder.container(keyedBy: CodingKeys.self)
        let base = FeatureFlags.default
        iCloudSyncEnabled = try d.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled) ?? base.iCloudSyncEnabled
        teamQuiet = try d.decodeIfPresent(TeamQuietConfig.self, forKey: .teamQuiet) ?? base.teamQuiet
        voiceAnnouncementsEnabled = try d.decodeIfPresent(Bool.self, forKey: .voiceAnnouncementsEnabled) ?? base.voiceAnnouncementsEnabled
        speakOnlyWithHeadphones = try d.decodeIfPresent(Bool.self, forKey: .speakOnlyWithHeadphones) ?? base.speakOnlyWithHeadphones
        watchCompanionEnabled = try d.decodeIfPresent(Bool.self, forKey: .watchCompanionEnabled) ?? base.watchCompanionEnabled
        learnedScheduleEnabled = try d.decodeIfPresent(Bool.self, forKey: .learnedScheduleEnabled) ?? base.learnedScheduleEnabled
        applyLearnedScheduleAutomatically = try d.decodeIfPresent(Bool.self, forKey: .applyLearnedScheduleAutomatically) ?? base.applyLearnedScheduleAutomatically
        webcamStillnessEnabled = try d.decodeIfPresent(Bool.self, forKey: .webcamStillnessEnabled) ?? base.webcamStillnessEnabled
        webcamStillnessMinutes = try d.decodeIfPresent(Int.self, forKey: .webcamStillnessMinutes) ?? base.webcamStillnessMinutes
        weatherBreaksEnabled = try d.decodeIfPresent(Bool.self, forKey: .weatherBreaksEnabled) ?? base.weatherBreaksEnabled
        diagnosticsEnabled = try d.decodeIfPresent(Bool.self, forKey: .diagnosticsEnabled) ?? base.diagnosticsEnabled
        diagnosticsEndpoint = try d.decodeIfPresent(String.self, forKey: .diagnosticsEndpoint) ?? base.diagnosticsEndpoint
        sparkleFeedURL = try d.decodeIfPresent(String.self, forKey: .sparkleFeedURL) ?? base.sparkleFeedURL
        preferSparkleUpdates = try d.decodeIfPresent(Bool.self, forKey: .preferSparkleUpdates) ?? base.preferSparkleUpdates
        showSampleDayTour = try d.decodeIfPresent(Bool.self, forKey: .showSampleDayTour) ?? base.showSampleDayTour
        reduceMotionOverrides = try d.decodeIfPresent(Bool.self, forKey: .reduceMotionOverrides) ?? base.reduceMotionOverrides
        breakDemoSymbolsEnabled = try d.decodeIfPresent(Bool.self, forKey: .breakDemoSymbolsEnabled) ?? base.breakDemoSymbolsEnabled
        weatherLatitude = try d.decodeIfPresent(Double.self, forKey: .weatherLatitude)
        weatherLongitude = try d.decodeIfPresent(Double.self, forKey: .weatherLongitude)
        liveActivityEnabled = try d.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? base.liveActivityEnabled
        fightingShapeEnabled = try d.decodeIfPresent(Bool.self, forKey: .fightingShapeEnabled) ?? base.fightingShapeEnabled
        fightingShapeBaseURL = try d.decodeIfPresent(String.self, forKey: .fightingShapeBaseURL) ?? base.fightingShapeBaseURL
        autoProfileFromCalendar = try d.decodeIfPresent(Bool.self, forKey: .autoProfileFromCalendar) ?? base.autoProfileFromCalendar
        recordBlockReasons = try d.decodeIfPresent(Bool.self, forKey: .recordBlockReasons) ?? base.recordBlockReasons
        creditStandHourAsBreak = try d.decodeIfPresent(Bool.self, forKey: .creditStandHourAsBreak) ?? base.creditStandHourAsBreak
        calendarTitleDenylist = try d.decodeIfPresent([String].self, forKey: .calendarTitleDenylist) ?? base.calendarTitleDenylist
        scheduleProfileRules = try d.decodeIfPresent([ScheduleProfileRule].self, forKey: .scheduleProfileRules) ?? base.scheduleProfileRules
        guidedBreakStealFocus = try d.decodeIfPresent(Bool.self, forKey: .guidedBreakStealFocus) ?? base.guidedBreakStealFocus
    }
}
