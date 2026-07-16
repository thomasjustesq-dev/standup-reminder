import Foundation

struct DaySchedule: Codable, Equatable, Hashable {
    var startHour: Int
    var endHour: Int

    static let standard = DaySchedule(startHour: 9, endHour: 17)
}

struct LunchConfig: Codable, Equatable {
    var enabled: Bool
    var hour: Int
    var minute: Int
    var windowMinutes: Int
    var title: String
    var body: String

    static let `default` = LunchConfig(
        enabled: true,
        hour: 12,
        minute: 0,
        windowMinutes: 2,
        title: "Lunch Reminder",
        body: "It's noon — time to take a break and eat lunch."
    )
}

struct WindDownConfig: Codable, Equatable {
    var enabled: Bool
    var hour: Int
    var minute: Int
    var windowMinutes: Int
    var title: String
    var body: String

    static let `default` = WindDownConfig(
        enabled: true,
        hour: 17,
        minute: 0,
        windowMinutes: 2,
        title: "End of Day",
        body: "Workday wrap-up — stretch, tidy your desk, and log off when you can."
    )
}

struct BreakPrompt: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var body: String
    var guidedSteps: [String]

    static let defaults: [BreakPrompt] = ReminderPack.balanced.prompts

    enum CodingKeys: String, CodingKey { case id, title, body, guidedSteps }

    init(id: String, title: String, body: String, guidedSteps: [String]) {
        self.id = id
        self.title = title
        self.body = body
        self.guidedSteps = guidedSteps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        guidedSteps = try c.decodeIfPresent([String].self, forKey: .guidedSteps)
            ?? ["Stand up", "Move for a minute", "Reset posture"]
    }
}

enum ReminderPack: String, Codable, CaseIterable, Identifiable {
    case balanced
    case developer
    case meetingHeavy
    case recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .developer: return "Developer day"
        case .meetingHeavy: return "Meeting-heavy"
        case .recovery: return "Recovery"
        }
    }

    var prompts: [BreakPrompt] {
        switch self {
        case .balanced:
            return [
                BreakPrompt(id: "stand", title: "Stand Up Reminder", body: "Time to stand up and move around for a minute or two.",
                            guidedSteps: ["Stand up", "Roll your shoulders", "Walk to a window or hallway", "Return when ready"]),
                BreakPrompt(id: "stretch", title: "Stretch Break", body: "Roll your shoulders, stretch your hips, and loosen your neck.",
                            guidedSteps: ["Chin tuck ×5", "Shoulder rolls ×10", "Hip hinge stretch 20s", "Shake out your hands"]),
                BreakPrompt(id: "water", title: "Hydration Check", body: "Grab a glass of water and take a short walk.",
                            guidedSteps: ["Stand", "Fill a glass of water", "Drink half", "Walk 30 seconds"]),
                BreakPrompt(id: "eyes", title: "Eye Rest (20-20-20)", body: "Look at something 20 feet away for 20 seconds.",
                            guidedSteps: ["Look 20 feet away", "Blink slowly ×10", "Soft-focus for 20 seconds"]),
                BreakPrompt(id: "posture", title: "Posture Reset", body: "Uncross your legs, sit or stand tall, and relax your jaw.",
                            guidedSteps: ["Uncross legs", "Lengthen your spine", "Relax jaw & tongue", "Take one deep breath"])
            ]
        case .developer:
            return [
                BreakPrompt(id: "eyes", title: "Screen Break", body: "Look away from the screen and blink for 20 seconds.",
                            guidedSteps: ["Look far away", "Blink ×20", "Palm eyes for 10s"]),
                BreakPrompt(id: "hands", title: "Wrist & Hands", body: "Shake out your hands and stretch your wrists.",
                            guidedSteps: ["Shake hands 10s", "Wrist flex/extend ×10", "Finger spreads ×10"]),
                BreakPrompt(id: "stand", title: "Compile Walk", body: "Stand and walk while something builds or syncs.",
                            guidedSteps: ["Stand", "Walk a short loop", "Shoulder rolls"]),
                BreakPrompt(id: "water", title: "Hydrate", body: "Water break — step away from the keyboard.",
                            guidedSteps: ["Stand", "Drink water", "Look outdoors if you can"])
            ]
        case .meetingHeavy:
            return [
                BreakPrompt(id: "posture", title: "Camera Posture", body: "Reset posture before your next call.",
                            guidedSteps: ["Sit/stand tall", "Relax shoulders", "Soften your gaze"]),
                BreakPrompt(id: "water", title: "Sip & Reset", body: "Quick water sip and a neck stretch between meetings.",
                            guidedSteps: ["Sip water", "Neck side stretch L/R", "Two deep breaths"]),
                BreakPrompt(id: "eyes", title: "Eye Soften", body: "Soft-focus away from slides for 20 seconds.",
                            guidedSteps: ["Look away from screen", "Blink slowly", "Relax forehead"])
            ]
        case .recovery:
            return [
                BreakPrompt(id: "breathe", title: "Breathing Break", body: "Two minutes of easy breathing.",
                            guidedSteps: ["Inhale 4 counts", "Exhale 6 counts", "Repeat 6 times"]),
                BreakPrompt(id: "walk", title: "Gentle Walk", body: "Take a slow walk — no phone scrolling.",
                            guidedSteps: ["Stand slowly", "Walk comfortably", "Notice your feet"]),
                BreakPrompt(id: "stretch", title: "Easy Stretch", body: "Gentle mobility only — nothing forced.",
                            guidedSteps: ["Shoulder rolls", "Cat-cow at desk", "Hamstring stretch light"])
            ]
        }
    }
}

struct AppConfig: Codable, Equatable {
    var enabled: Bool
    var intervalMinutes: Int
    var weekdaysOnly: Bool
    var skipWhenLocked: Bool
    var skipWhenDisplayAsleep: Bool
    var skipWhenFocused: Bool
    var skipWhenInMeeting: Bool
    var idleSkipMinutes: Int
    var minActiveMinutes: Int
    var soundName: String
    var lunch: LunchConfig
    var windDown: WindDownConfig
    var scheduleByWeekday: [String: DaySchedule]
    var prompts: [BreakPrompt]
    var reminderPack: ReminderPack
    var hasCompletedOnboarding: Bool

    // Sit / stand desk
    var sitStandModeEnabled: Bool
    var sitStandPhaseMinutes: Int

    // Adaptive cadence
    var adaptiveIntervalEnabled: Bool
    var adaptiveMinMinutes: Int
    var adaptiveMaxMinutes: Int

    // Meeting catch-up
    var meetingCatchUpEnabled: Bool

    // PTO / OOO
    var skipOnPTO: Bool
    var ptoKeywords: [String]

    // Deep work heuristic
    var deepWorkEnabled: Bool
    var deepWorkQuietMinutes: Int
    var deepWorkRequireFullscreen: Bool

    // Frontmost app denylist (bundle IDs)
    var denylistBundleIds: [String]

    // Health
    var healthLoggingEnabled: Bool
    var healthMindfulMinutes: Double

    // Guided break overlay
    var guidedBreakEnabled: Bool
    var guidedBreakSeconds: Int

    // Menu bar countdown (Mac Live Activity stand-in)
    var showMenuBarCountdown: Bool

    // Time zone for schedule math (empty = autoupdating current)
    var scheduleTimeZoneIdentifier: String

    // Updates
    var updateCheckEnabled: Bool
    var githubReleasesURL: String

    static func defaultSchedule() -> [String: DaySchedule] {
        var map: [String: DaySchedule] = [:]
        for day in 1...5 { map[String(day)] = .standard }
        return map
    }

    static let defaultDenylist = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.FinalCut",
        "com.apple.Keynote",
        "com.apple.keynote",
        "com.microsoft.Powerpoint"
    ]

    static let `default` = AppConfig(
        enabled: true,
        intervalMinutes: 30,
        weekdaysOnly: true,
        skipWhenLocked: true,
        skipWhenDisplayAsleep: true,
        skipWhenFocused: true,
        skipWhenInMeeting: true,
        idleSkipMinutes: 5,
        minActiveMinutes: 20,
        soundName: "Glass",
        lunch: .default,
        windDown: .default,
        scheduleByWeekday: defaultSchedule(),
        prompts: ReminderPack.balanced.prompts,
        reminderPack: .balanced,
        hasCompletedOnboarding: false,
        sitStandModeEnabled: false,
        sitStandPhaseMinutes: 30,
        adaptiveIntervalEnabled: true,
        adaptiveMinMinutes: 20,
        adaptiveMaxMinutes: 45,
        meetingCatchUpEnabled: true,
        skipOnPTO: true,
        ptoKeywords: ["ooo", "out of office", "pto", "vacation", "holiday", "leave", "sick"],
        deepWorkEnabled: true,
        deepWorkQuietMinutes: 25,
        deepWorkRequireFullscreen: false,
        denylistBundleIds: defaultDenylist,
        healthLoggingEnabled: false,
        healthMindfulMinutes: 1,
        guidedBreakEnabled: true,
        guidedBreakSeconds: 45,
        showMenuBarCountdown: true,
        scheduleTimeZoneIdentifier: "",
        updateCheckEnabled: true,
        githubReleasesURL: ""
    )

    var scheduleTimeZone: TimeZone {
        if scheduleTimeZoneIdentifier.isEmpty {
            return .autoupdatingCurrent
        }
        return TimeZone(identifier: scheduleTimeZoneIdentifier) ?? .autoupdatingCurrent
    }

    var scheduleCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = scheduleTimeZone
        return cal
    }

    func schedule(for date: Date = Date()) -> DaySchedule? {
        let calendar = scheduleCalendar
        let weekday = calendar.component(.weekday, from: date)
        let iso = weekday == 1 ? 7 : weekday - 1
        if weekdaysOnly && iso >= 6 { return nil }
        return scheduleByWeekday[String(iso)]
    }

    func isWithinWorkHours(at date: Date = Date()) -> Bool {
        guard let schedule = schedule(for: date) else { return false }
        let hour = scheduleCalendar.component(.hour, from: date)
        return hour >= schedule.startHour && hour < schedule.endHour
    }

    func isLunchTime(at date: Date = Date()) -> Bool {
        guard lunch.enabled else { return false }
        return isNear(hour: lunch.hour, minute: lunch.minute, window: lunch.windowMinutes, at: date)
    }

    func isWindDownTime(at date: Date = Date()) -> Bool {
        guard windDown.enabled else { return false }
        return isNear(hour: windDown.hour, minute: windDown.minute, window: windDown.windowMinutes, at: date)
    }

    private func isNear(hour: Int, minute: Int, window: Int, at date: Date) -> Bool {
        let h = scheduleCalendar.component(.hour, from: date)
        let m = scheduleCalendar.component(.minute, from: date)
        let target = hour * 60 + minute
        let now = h * 60 + m
        return abs(now - target) <= window
    }

    func applying(pack: ReminderPack) -> AppConfig {
        var copy = self
        copy.reminderPack = pack
        copy.prompts = pack.prompts
        return copy
    }

    enum CodingKeys: String, CodingKey {
        case enabled, intervalMinutes, weekdaysOnly, skipWhenLocked, skipWhenDisplayAsleep
        case skipWhenFocused, skipWhenInMeeting, idleSkipMinutes, minActiveMinutes, soundName
        case lunch, windDown, scheduleByWeekday, prompts, reminderPack, hasCompletedOnboarding
        case sitStandModeEnabled, sitStandPhaseMinutes
        case adaptiveIntervalEnabled, adaptiveMinMinutes, adaptiveMaxMinutes
        case meetingCatchUpEnabled, skipOnPTO, ptoKeywords
        case deepWorkEnabled, deepWorkQuietMinutes, deepWorkRequireFullscreen
        case denylistBundleIds, healthLoggingEnabled, healthMindfulMinutes
        case guidedBreakEnabled, guidedBreakSeconds, showMenuBarCountdown
        case scheduleTimeZoneIdentifier, updateCheckEnabled, githubReleasesURL
    }

    init(from decoder: Decoder) throws {
        let d = try decoder.container(keyedBy: CodingKeys.self)
        let base = AppConfig.default
        enabled = try d.decodeIfPresent(Bool.self, forKey: .enabled) ?? base.enabled
        intervalMinutes = try d.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? base.intervalMinutes
        weekdaysOnly = try d.decodeIfPresent(Bool.self, forKey: .weekdaysOnly) ?? base.weekdaysOnly
        skipWhenLocked = try d.decodeIfPresent(Bool.self, forKey: .skipWhenLocked) ?? base.skipWhenLocked
        skipWhenDisplayAsleep = try d.decodeIfPresent(Bool.self, forKey: .skipWhenDisplayAsleep) ?? base.skipWhenDisplayAsleep
        skipWhenFocused = try d.decodeIfPresent(Bool.self, forKey: .skipWhenFocused) ?? base.skipWhenFocused
        skipWhenInMeeting = try d.decodeIfPresent(Bool.self, forKey: .skipWhenInMeeting) ?? base.skipWhenInMeeting
        idleSkipMinutes = try d.decodeIfPresent(Int.self, forKey: .idleSkipMinutes) ?? base.idleSkipMinutes
        minActiveMinutes = try d.decodeIfPresent(Int.self, forKey: .minActiveMinutes) ?? base.minActiveMinutes
        soundName = try d.decodeIfPresent(String.self, forKey: .soundName) ?? base.soundName
        lunch = try d.decodeIfPresent(LunchConfig.self, forKey: .lunch) ?? base.lunch
        windDown = try d.decodeIfPresent(WindDownConfig.self, forKey: .windDown) ?? base.windDown
        scheduleByWeekday = try d.decodeIfPresent([String: DaySchedule].self, forKey: .scheduleByWeekday) ?? base.scheduleByWeekday
        reminderPack = try d.decodeIfPresent(ReminderPack.self, forKey: .reminderPack) ?? base.reminderPack
        prompts = try d.decodeIfPresent([BreakPrompt].self, forKey: .prompts) ?? reminderPack.prompts
        hasCompletedOnboarding = try d.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        sitStandModeEnabled = try d.decodeIfPresent(Bool.self, forKey: .sitStandModeEnabled) ?? base.sitStandModeEnabled
        sitStandPhaseMinutes = try d.decodeIfPresent(Int.self, forKey: .sitStandPhaseMinutes) ?? base.sitStandPhaseMinutes
        adaptiveIntervalEnabled = try d.decodeIfPresent(Bool.self, forKey: .adaptiveIntervalEnabled) ?? base.adaptiveIntervalEnabled
        adaptiveMinMinutes = try d.decodeIfPresent(Int.self, forKey: .adaptiveMinMinutes) ?? base.adaptiveMinMinutes
        adaptiveMaxMinutes = try d.decodeIfPresent(Int.self, forKey: .adaptiveMaxMinutes) ?? base.adaptiveMaxMinutes
        meetingCatchUpEnabled = try d.decodeIfPresent(Bool.self, forKey: .meetingCatchUpEnabled) ?? base.meetingCatchUpEnabled
        skipOnPTO = try d.decodeIfPresent(Bool.self, forKey: .skipOnPTO) ?? base.skipOnPTO
        ptoKeywords = try d.decodeIfPresent([String].self, forKey: .ptoKeywords) ?? base.ptoKeywords
        deepWorkEnabled = try d.decodeIfPresent(Bool.self, forKey: .deepWorkEnabled) ?? base.deepWorkEnabled
        deepWorkQuietMinutes = try d.decodeIfPresent(Int.self, forKey: .deepWorkQuietMinutes) ?? base.deepWorkQuietMinutes
        deepWorkRequireFullscreen = try d.decodeIfPresent(Bool.self, forKey: .deepWorkRequireFullscreen) ?? base.deepWorkRequireFullscreen
        denylistBundleIds = try d.decodeIfPresent([String].self, forKey: .denylistBundleIds) ?? base.denylistBundleIds
        healthLoggingEnabled = try d.decodeIfPresent(Bool.self, forKey: .healthLoggingEnabled) ?? base.healthLoggingEnabled
        healthMindfulMinutes = try d.decodeIfPresent(Double.self, forKey: .healthMindfulMinutes) ?? base.healthMindfulMinutes
        guidedBreakEnabled = try d.decodeIfPresent(Bool.self, forKey: .guidedBreakEnabled) ?? base.guidedBreakEnabled
        guidedBreakSeconds = try d.decodeIfPresent(Int.self, forKey: .guidedBreakSeconds) ?? base.guidedBreakSeconds
        showMenuBarCountdown = try d.decodeIfPresent(Bool.self, forKey: .showMenuBarCountdown) ?? base.showMenuBarCountdown
        scheduleTimeZoneIdentifier = try d.decodeIfPresent(String.self, forKey: .scheduleTimeZoneIdentifier) ?? base.scheduleTimeZoneIdentifier
        updateCheckEnabled = try d.decodeIfPresent(Bool.self, forKey: .updateCheckEnabled) ?? base.updateCheckEnabled
        githubReleasesURL = try d.decodeIfPresent(String.self, forKey: .githubReleasesURL) ?? base.githubReleasesURL

        // Migrate prompts missing guidedSteps
        prompts = prompts.map { p in
            if p.guidedSteps.isEmpty {
                var q = p
                q.guidedSteps = ["Stand up", "Move for a minute", "Reset posture"]
                return q
            }
            return p
        }
    }

    init(
        enabled: Bool, intervalMinutes: Int, weekdaysOnly: Bool, skipWhenLocked: Bool,
        skipWhenDisplayAsleep: Bool, skipWhenFocused: Bool, skipWhenInMeeting: Bool,
        idleSkipMinutes: Int, minActiveMinutes: Int, soundName: String, lunch: LunchConfig,
        windDown: WindDownConfig, scheduleByWeekday: [String: DaySchedule], prompts: [BreakPrompt],
        reminderPack: ReminderPack, hasCompletedOnboarding: Bool, sitStandModeEnabled: Bool,
        sitStandPhaseMinutes: Int, adaptiveIntervalEnabled: Bool, adaptiveMinMinutes: Int,
        adaptiveMaxMinutes: Int, meetingCatchUpEnabled: Bool, skipOnPTO: Bool, ptoKeywords: [String],
        deepWorkEnabled: Bool, deepWorkQuietMinutes: Int, deepWorkRequireFullscreen: Bool,
        denylistBundleIds: [String], healthLoggingEnabled: Bool, healthMindfulMinutes: Double,
        guidedBreakEnabled: Bool, guidedBreakSeconds: Int, showMenuBarCountdown: Bool,
        scheduleTimeZoneIdentifier: String, updateCheckEnabled: Bool, githubReleasesURL: String
    ) {
        self.enabled = enabled
        self.intervalMinutes = intervalMinutes
        self.weekdaysOnly = weekdaysOnly
        self.skipWhenLocked = skipWhenLocked
        self.skipWhenDisplayAsleep = skipWhenDisplayAsleep
        self.skipWhenFocused = skipWhenFocused
        self.skipWhenInMeeting = skipWhenInMeeting
        self.idleSkipMinutes = idleSkipMinutes
        self.minActiveMinutes = minActiveMinutes
        self.soundName = soundName
        self.lunch = lunch
        self.windDown = windDown
        self.scheduleByWeekday = scheduleByWeekday
        self.prompts = prompts
        self.reminderPack = reminderPack
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.sitStandModeEnabled = sitStandModeEnabled
        self.sitStandPhaseMinutes = sitStandPhaseMinutes
        self.adaptiveIntervalEnabled = adaptiveIntervalEnabled
        self.adaptiveMinMinutes = adaptiveMinMinutes
        self.adaptiveMaxMinutes = adaptiveMaxMinutes
        self.meetingCatchUpEnabled = meetingCatchUpEnabled
        self.skipOnPTO = skipOnPTO
        self.ptoKeywords = ptoKeywords
        self.deepWorkEnabled = deepWorkEnabled
        self.deepWorkQuietMinutes = deepWorkQuietMinutes
        self.deepWorkRequireFullscreen = deepWorkRequireFullscreen
        self.denylistBundleIds = denylistBundleIds
        self.healthLoggingEnabled = healthLoggingEnabled
        self.healthMindfulMinutes = healthMindfulMinutes
        self.guidedBreakEnabled = guidedBreakEnabled
        self.guidedBreakSeconds = guidedBreakSeconds
        self.showMenuBarCountdown = showMenuBarCountdown
        self.scheduleTimeZoneIdentifier = scheduleTimeZoneIdentifier
        self.updateCheckEnabled = updateCheckEnabled
        self.githubReleasesURL = githubReleasesURL
    }
}

enum ConfigStore {
    static func load() -> AppConfig {
        let url = Paths.configFile
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            let config = AppConfig.default
            save(config)
            return config
        }
        return config
    }

    static func save(_ config: AppConfig) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: Paths.configFile, options: .atomic)
        WidgetSnapshotWriter.write(from: config)
    }

    static func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(load())
    }

    static func importJSON(_ data: Data) throws -> AppConfig {
        let config = try JSONDecoder().decode(AppConfig.self, from: data)
        save(config)
        return config
    }
}
