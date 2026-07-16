import Foundation

struct DayStats: Codable, Equatable {
    var shown: Int = 0
    var done: Int = 0
    var snoozed: Int = 0
    var skipped: Int = 0
}

struct StatsSnapshot: Codable, Equatable {
    var acknowledgedTotal: Int = 0
    var skippedTotal: Int = 0
    var snoozedTotal: Int = 0
    var shownTotal: Int = 0
    var byDay: [String: DayStats] = [:]

    mutating func recordShown(on day: String) {
        shownTotal += 1
        byDay[day, default: DayStats()].shown += 1
    }

    mutating func recordDone(on day: String) {
        acknowledgedTotal += 1
        byDay[day, default: DayStats()].done += 1
    }

    mutating func recordSnooze(on day: String) {
        snoozedTotal += 1
        byDay[day, default: DayStats()].snoozed += 1
    }

    mutating func recordSkip(on day: String) {
        skippedTotal += 1
        byDay[day, default: DayStats()].skipped += 1
    }

    func weekSummary(reference: Date = Date(), calendar: Calendar = .current) -> (shown: Int, done: Int, skipped: Int, snoozed: Int) {
        var shown = 0, done = 0, skipped = 0, snoozed = 0
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: reference) else { continue }
            let key = Self.dayKey(day, calendar: calendar)
            if let stats = byDay[key] {
                shown += stats.shown
                done += stats.done
                skipped += stats.skipped
                snoozed += stats.snoozed
            }
        }
        return (shown, done, skipped, snoozed)
    }

    static func dayKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// Note: callers may pass a schedule-specific calendar (time zone aware).

enum StatsStore {
    static func load() -> StatsSnapshot {
        let url = Paths.statsFile
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let stats = try? JSONCoding.decoder().decode(StatsSnapshot.self, from: data) else {
            return StatsSnapshot()
        }
        return stats
    }

    static func save(_ stats: StatsSnapshot) {
        guard let data = try? JSONCoding.encoder().encode(stats) else { return }
        try? data.write(to: Paths.statsFile, options: .atomic)
    }
}
