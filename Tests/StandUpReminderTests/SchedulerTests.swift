import XCTest
@testable import StandUpReminder

/// All dates are built in America/Chicago; 2026-07-15 is a Wednesday.
final class SchedulerTests: XCTestCase {
    private let timeZone = "America/Chicago"

    private func makeConfig(
        lunch: Bool = false,
        windDown: Bool = false,
        sitStand: Bool = false
    ) -> AppConfig {
        var config = AppConfig.default
        config.scheduleTimeZoneIdentifier = timeZone
        config.lunch.enabled = lunch
        config.windDown.enabled = windDown
        config.sitStandModeEnabled = sitStand
        return config
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    private func input(
        config: AppConfig,
        interval: Int = 30,
        now: Date,
        paused: Bool = false,
        snoozeUntil: Date? = nil,
        lastReminderAt: Date? = nil,
        lastAcknowledgedAt: Date? = nil,
        deskPhaseStartedAt: Date? = nil,
        lunchFiredDayKey: String? = nil,
        windDownFiredDayKey: String? = nil
    ) -> Scheduler.Input {
        Scheduler.Input(
            config: config,
            intervalMinutes: interval,
            now: now,
            paused: paused,
            snoozeUntil: snoozeUntil,
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt,
            deskPhaseStartedAt: deskPhaseStartedAt,
            lunchFiredDayKey: lunchFiredDayKey,
            windDownFiredDayKey: windDownFiredDayKey
        )
    }

    func testBreakFollowsAcknowledgementNotWallClock() {
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 7, 15, 10, 8),
            lastAcknowledgedAt: date(2026, 7, 15, 10, 7)
        ))
        XCTAssertEqual(next, Scheduler.Next(date: date(2026, 7, 15, 10, 37), kind: .breakPrompt))
    }

    func testIntervalIsUniformFor45Minutes() {
        // v4.0 fired at :00 and :45 wall-clock, alternating 45/15-minute gaps.
        let afterFirst = Scheduler.next(input(
            config: makeConfig(),
            interval: 45,
            now: date(2026, 7, 15, 10, 45),
            lastReminderAt: date(2026, 7, 15, 10, 45)
        ))
        XCTAssertEqual(afterFirst?.date, date(2026, 7, 15, 11, 30))
    }

    func testLaterOfReminderAndAcknowledgementAnchors() {
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 7, 15, 10, 20),
            lastReminderAt: date(2026, 7, 15, 10, 0),
            lastAcknowledgedAt: date(2026, 7, 15, 10, 15)
        ))
        XCTAssertEqual(next?.date, date(2026, 7, 15, 10, 45))
    }

    func testSnoozePushesBreak() {
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 7, 15, 10, 5),
            snoozeUntil: date(2026, 7, 15, 10, 50),
            lastAcknowledgedAt: date(2026, 7, 15, 10, 0)
        ))
        XCTAssertEqual(next?.date, date(2026, 7, 15, 10, 50))
    }

    func testAfterHoursClampsToNextWorkdayStart() {
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 7, 15, 16, 55),
            lastAcknowledgedAt: date(2026, 7, 15, 16, 50)
        ))
        XCTAssertEqual(next?.date, date(2026, 7, 16, 9, 0))
    }

    func testFridayEveningClampsToMonday() {
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 7, 17, 16, 55),
            lastAcknowledgedAt: date(2026, 7, 17, 16, 50)
        ))
        XCTAssertEqual(next?.date, date(2026, 7, 20, 9, 0))
    }

    func testLunchBeatsLaterBreak() {
        let next = Scheduler.next(input(
            config: makeConfig(lunch: true),
            now: date(2026, 7, 15, 11, 46),
            lastAcknowledgedAt: date(2026, 7, 15, 11, 45)
        ))
        XCTAssertEqual(next, Scheduler.Next(date: date(2026, 7, 15, 12, 0), kind: .lunch))
    }

    func testLunchFiresOncePerDay() {
        let next = Scheduler.next(input(
            config: makeConfig(lunch: true),
            now: date(2026, 7, 15, 12, 1),
            lastReminderAt: date(2026, 7, 15, 12, 0),
            lunchFiredDayKey: "2026-07-15"
        ))
        XCTAssertEqual(next, Scheduler.Next(date: date(2026, 7, 15, 12, 30), kind: .breakPrompt))
    }

    func testMissedLunchPastGraceSkipsToNextWorkday() {
        let next = Scheduler.next(input(
            config: makeConfig(lunch: true),
            now: date(2026, 7, 15, 12, 20),
            lastAcknowledgedAt: date(2026, 7, 15, 12, 15)
        ))
        // Today's 12:00 is gone (2-minute grace); next lunch is tomorrow.
        XCTAssertEqual(next, Scheduler.Next(date: date(2026, 7, 15, 12, 45), kind: .breakPrompt))
    }

    func testWindDownWinsTieOverBreak() {
        let next = Scheduler.next(input(
            config: makeConfig(windDown: true),
            now: date(2026, 7, 15, 16, 45),
            lastAcknowledgedAt: date(2026, 7, 15, 16, 30)
        ))
        XCTAssertEqual(next, Scheduler.Next(date: date(2026, 7, 15, 17, 0), kind: .windDown))
    }

    func testWindDownFiresOncePerDay() {
        let next = Scheduler.next(input(
            config: makeConfig(windDown: true),
            now: date(2026, 7, 15, 17, 1),
            lastReminderAt: date(2026, 7, 15, 17, 0),
            windDownFiredDayKey: "2026-07-15"
        ))
        // Break due 17:30 is after hours → tomorrow 9:00; wind-down is tomorrow 17:00.
        XCTAssertEqual(next, Scheduler.Next(date: date(2026, 7, 16, 9, 0), kind: .breakPrompt))
    }

    func testSitStandDueFromPhaseStart() {
        var config = makeConfig(sitStand: true)
        config.sitStandPhaseMinutes = 40
        let next = Scheduler.next(input(
            config: config,
            now: date(2026, 7, 15, 10, 30),
            lastAcknowledgedAt: date(2026, 7, 15, 10, 15),
            deskPhaseStartedAt: date(2026, 7, 15, 10, 0)
        ))
        // Sit/stand due 10:40 beats the 10:45 break.
        XCTAssertEqual(next, Scheduler.Next(date: date(2026, 7, 15, 10, 40), kind: .sitStand))
    }

    func testPausedReturnsNil() {
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 7, 15, 10, 0),
            paused: true,
            lastAcknowledgedAt: date(2026, 7, 15, 9, 45)
        ))
        XCTAssertNil(next)
    }

    func testFirstRunWithoutAnchorSchedulesOneIntervalOut() {
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 7, 15, 9, 30)
        ))
        XCTAssertEqual(next?.date, date(2026, 7, 15, 10, 0))
    }

    func testOverdueSuppressedBreakStaysDue() {
        // A break that came due mid-meeting keeps its past due date so it
        // fires as soon as suppression lifts.
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 7, 15, 11, 0),
            lastAcknowledgedAt: date(2026, 7, 15, 10, 0)
        ))
        XCTAssertEqual(next?.date, date(2026, 7, 15, 10, 30))
    }
}
