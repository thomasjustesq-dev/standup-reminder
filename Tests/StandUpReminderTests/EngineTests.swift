import XCTest
@testable import StandUpReminder

final class AdaptiveIntervalTests: XCTestCase {
    private func makeConfig(enabled: Bool = true, base: Int = 30, min: Int = 20, max: Int = 45) -> AppConfig {
        var config = AppConfig.default
        config.adaptiveIntervalEnabled = enabled
        config.intervalMinutes = base
        config.adaptiveMinMinutes = min
        config.adaptiveMaxMinutes = max
        return config
    }

    func testDisabledReturnsBaseInterval() {
        XCTAssertEqual(AdaptiveInterval.resolvedMinutes(config: makeConfig(enabled: false), samples: [0, 0]), 30)
    }

    func testEmptySamplesReturnClampedBase() {
        XCTAssertEqual(AdaptiveInterval.resolvedMinutes(config: makeConfig(base: 60), samples: []), 45)
    }

    func testHighActivityShortensInterval() {
        XCTAssertEqual(AdaptiveInterval.resolvedMinutes(config: makeConfig(), samples: [0, 0, 0]), 20)
    }

    func testIdlePresenceLengthensInterval() {
        XCTAssertEqual(AdaptiveInterval.resolvedMinutes(config: makeConfig(), samples: [200, 300]), 45)
    }
}

final class QuietWindowTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        return cal
    }

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: hour, minute: minute))!
    }

    func testNormalWindow() {
        let window = QuietWindow(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0, label: "standup")
        XCTAssertTrue(window.contains(date(hour: 9, minute: 30), calendar: calendar))
        XCTAssertTrue(window.contains(date(hour: 9, minute: 0), calendar: calendar))
        XCTAssertFalse(window.contains(date(hour: 10, minute: 0), calendar: calendar))
        XCTAssertFalse(window.contains(date(hour: 8, minute: 59), calendar: calendar))
    }

    func testOvernightWindowWraps() {
        let window = QuietWindow(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0, label: "night")
        XCTAssertTrue(window.contains(date(hour: 23, minute: 0), calendar: calendar))
        XCTAssertTrue(window.contains(date(hour: 5, minute: 59), calendar: calendar))
        XCTAssertFalse(window.contains(date(hour: 12, minute: 0), calendar: calendar))
    }
}

final class UpdateCheckerTests: XCTestCase {
    func testCompareVersions() {
        XCTAssertEqual(UpdateChecker.compareVersions("1.2.10", "1.2.9"), 1)
        XCTAssertEqual(UpdateChecker.compareVersions("1.2", "1.2.0"), 0)
        XCTAssertEqual(UpdateChecker.compareVersions("0.9", "1.0"), -1)
        XCTAssertEqual(UpdateChecker.compareVersions("4.1.0", "4.0.0"), 1)
    }
}

final class StatsSnapshotTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        return cal
    }

    func testDayKeyFormat() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 12))!
        XCTAssertEqual(StatsSnapshot.dayKey(date, calendar: calendar), "2026-07-05")
    }

    func testWeekSummaryCountsOnlyLastSevenDays() {
        var stats = StatsSnapshot()
        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: today)!
        stats.recordDone(on: StatsSnapshot.dayKey(today, calendar: calendar))
        stats.recordDone(on: StatsSnapshot.dayKey(sixDaysAgo, calendar: calendar))
        stats.recordDone(on: StatsSnapshot.dayKey(eightDaysAgo, calendar: calendar))
        let week = stats.weekSummary(reference: today, calendar: calendar)
        XCTAssertEqual(week.done, 2)
    }
}

final class JSONCodingTests: XCTestCase {
    func testISO8601RoundTrip() throws {
        let original = TeamQuietConfig(
            enabled: true,
            feedURL: "https://example.com/feed.json",
            windows: [],
            lastFetchedAt: Date(timeIntervalSinceReferenceDate: 774_316_800)
        )
        let data = try JSONCoding.encoder().encode(original)
        let decoded = try JSONCoding.decoder().decode(TeamQuietConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLegacyEpochDoubleDatesStillDecode() throws {
        // v4.0's default-strategy stores wrote dates as seconds since the
        // reference date; upgrades must not lose them.
        let json = """
        {"enabled":false,"feedURL":"","windows":[],"lastFetchedAt":774316800.0}
        """
        let decoded = try JSONCoding.decoder().decode(TeamQuietConfig.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.lastFetchedAt, Date(timeIntervalSinceReferenceDate: 774_316_800))
    }

    func testConfigRoundTripPreservesDates() throws {
        var config = AppConfig.default
        config.features.teamQuiet.lastFetchedAt = Date(timeIntervalSinceReferenceDate: 774_316_800)
        let data = try JSONCoding.encoder().encode(config)
        let decoded = try JSONCoding.decoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.features.teamQuiet.lastFetchedAt, config.features.teamQuiet.lastFetchedAt)
    }
}
