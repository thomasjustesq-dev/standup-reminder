import Foundation

/// Time-of-day / day-of-week rule that selects a reminder pack without calendar access.
struct ScheduleProfileRule: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    /// ISO weekday 1=Mon … 7=Sun; empty = every day.
    var weekdays: [Int] = []
    var startHour: Int
    var endHour: Int
    var pack: ReminderPack

    enum CodingKeys: String, CodingKey { case id, weekdays, startHour, endHour, pack }

    init(id: String = UUID().uuidString, weekdays: [Int] = [], startHour: Int, endHour: Int, pack: ReminderPack) {
        self.id = id
        self.weekdays = weekdays
        self.startHour = startHour
        self.endHour = endHour
        self.pack = pack
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        weekdays = try c.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
        startHour = try c.decodeIfPresent(Int.self, forKey: .startHour) ?? 9
        endHour = try c.decodeIfPresent(Int.self, forKey: .endHour) ?? 12
        pack = try c.decodeIfPresent(ReminderPack.self, forKey: .pack) ?? .balanced
    }

    func matches(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let iso = weekday == 1 ? 7 : weekday - 1
        if !weekdays.isEmpty, !weekdays.contains(iso) { return false }
        if startHour <= endHour {
            return hour >= startHour && hour < endHour
        }
        return hour >= startHour || hour < endHour
    }

    /// First matching rule wins; nil if none.
    static func activePack(rules: [ScheduleProfileRule], at date: Date, calendar: Calendar) -> ReminderPack? {
        rules.first { $0.matches(date, calendar: calendar) }?.pack
    }
}
