import Foundation

struct DayActivitySample: Codable, Equatable {
    var dayKey: String
    var firstActiveMinute: Int // minutes from midnight
    var lastActiveMinute: Int
}

struct LearnedScheduleStore: Codable, Equatable {
    var samples: [DayActivitySample] = []

    static var fileURL: URL { Paths.appSupport.appendingPathComponent("learned-schedule.json") }

    static func load() -> LearnedScheduleStore {
        guard let data = try? Data(contentsOf: fileURL),
              let store = try? JSONDecoder().decode(LearnedScheduleStore.self, from: data) else {
            return LearnedScheduleStore()
        }
        return store
    }

    static func save(_ store: LearnedScheduleStore) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(store) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    mutating func recordActivity(at date: Date, calendar: Calendar) {
        let day = StatsSnapshot.dayKey(date, calendar: calendar)
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if let idx = samples.firstIndex(where: { $0.dayKey == day }) {
            samples[idx].firstActiveMinute = min(samples[idx].firstActiveMinute, minute)
            samples[idx].lastActiveMinute = max(samples[idx].lastActiveMinute, minute)
        } else {
            samples.append(DayActivitySample(dayKey: day, firstActiveMinute: minute, lastActiveMinute: minute))
        }
        if samples.count > 60 {
            samples = Array(samples.suffix(60))
        }
    }

    /// Suggested start/end hours from median of recent weekdays.
    func suggestion(calendar: Calendar = .current) -> DaySchedule? {
        let recent = Array(samples.suffix(20))
        guard recent.count >= 5 else { return nil }
        let starts = recent.map(\.firstActiveMinute).sorted()
        let ends = recent.map(\.lastActiveMinute).sorted()
        let startMed = starts[starts.count / 2]
        let endMed = ends[ends.count / 2]
        let startHour = max(5, startMed / 60)
        var endHour = min(22, (endMed + 29) / 60) // round up toward next hour
        if endHour <= startHour { endHour = startHour + 8 }
        return DaySchedule(startHour: startHour, endHour: endHour)
    }
}
