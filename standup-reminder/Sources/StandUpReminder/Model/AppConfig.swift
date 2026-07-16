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
    /// Match lunch if within this many minutes of the configured time.
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

struct BreakPrompt: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var body: String

    static let defaults: [BreakPrompt] = [
        BreakPrompt(id: "stand", title: "Stand Up Reminder", body: "Time to stand up and move around for a minute or two."),
        BreakPrompt(id: "stretch", title: "Stretch Break", body: "Roll your shoulders, stretch your hips, and loosen your neck."),
        BreakPrompt(id: "water", title: "Hydration Check", body: "Grab a glass of water and take a short walk."),
        BreakPrompt(id: "eyes", title: "Eye Rest (20-20-20)", body: "Look at something 20 feet away for 20 seconds."),
        BreakPrompt(id: "posture", title: "Posture Reset", body: "Uncross your legs, sit or stand tall, and relax your jaw.")
    ]
}

struct AppConfig: Codable, Equatable {
    var enabled: Bool
    var intervalMinutes: Int
    var weekdaysOnly: Bool
    var skipWhenLocked: Bool
    var skipWhenDisplayAsleep: Bool
    var skipWhenFocused: Bool
    var skipWhenInMeeting: Bool
    /// Skip reminder if user has been idle at least this many minutes.
    var idleSkipMinutes: Int
    /// Only remind if user has been active for at least this many minutes since last break (0 = off).
    var minActiveMinutes: Int
    var soundName: String
    var lunch: LunchConfig
    /// Keys "1"..."7" (ISO weekday: 1=Monday … 7=Sunday). Missing day = disabled that day if weekdaysOnly logic applies via presence.
    var scheduleByWeekday: [String: DaySchedule]
    var prompts: [BreakPrompt]
    var hasCompletedOnboarding: Bool

    static func defaultSchedule() -> [String: DaySchedule] {
        var map: [String: DaySchedule] = [:]
        for day in 1...5 {
            map[String(day)] = .standard
        }
        return map
    }

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
        scheduleByWeekday: defaultSchedule(),
        prompts: BreakPrompt.defaults,
        hasCompletedOnboarding: false
    )

    func schedule(for date: Date = Date(), calendar: Calendar = .current) -> DaySchedule? {
        let weekday = calendar.component(.weekday, from: date)
        // Calendar: 1=Sunday … 7=Saturday → ISO 1=Monday … 7=Sunday
        let iso = weekday == 1 ? 7 : weekday - 1
        if weekdaysOnly && iso >= 6 { return nil }
        return scheduleByWeekday[String(iso)]
    }

    func isWithinWorkHours(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let schedule = schedule(for: date, calendar: calendar) else { return false }
        let hour = calendar.component(.hour, from: date)
        return hour >= schedule.startHour && hour < schedule.endHour
    }

    func isLunchTime(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard lunch.enabled else { return false }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let target = lunch.hour * 60 + lunch.minute
        let now = hour * 60 + minute
        return abs(now - target) <= lunch.windowMinutes
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
    }
}
