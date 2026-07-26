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

    func testUpcomingChainSimulatesADay() {
        // 9:05 ack, 30-min interval, lunch + wind-down on: the chain the iOS
        // app pre-schedules must space breaks evenly and fire lunch and
        // wind-down exactly once.
        let chain = Scheduler.upcoming(input(
            config: makeConfig(lunch: true, windDown: true),
            now: date(2026, 7, 15, 9, 6),
            lastAcknowledgedAt: date(2026, 7, 15, 9, 5)
        ), count: 18)

        XCTAssertEqual(chain.first, Scheduler.Next(date: date(2026, 7, 15, 9, 35), kind: .breakPrompt))
        let sameDay = chain.filter { $0.date < date(2026, 7, 16, 0, 0) }
        XCTAssertEqual(sameDay.filter { $0.kind == .lunch }.count, 1)
        XCTAssertEqual(sameDay.filter { $0.kind == .windDown }.count, 1)
        XCTAssertEqual(sameDay.first { $0.kind == .lunch }?.date, date(2026, 7, 15, 12, 0))
        XCTAssertEqual(sameDay.first { $0.kind == .windDown }?.date, date(2026, 7, 15, 17, 0))

        // Breaks stay >= one interval apart.
        let breaks = sameDay.filter { $0.kind == .breakPrompt }.map(\.date)
        for (a, b) in zip(breaks, breaks.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b.timeIntervalSince(a), 30 * 60)
        }
        // The chain rolls into the next workday.
        XCTAssertTrue(chain.contains { $0.date >= date(2026, 7, 16, 9, 0) })
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

    // MARK: DST transitions (America/Chicago: spring forward 2026-03-08, fall back 2026-11-01)

    func testChainAcrossSpringForwardKeepsLocalTimes() {
        // Sunday 2026-03-08 10:00 local; the 02:00→03:00 jump is overnight.
        // With no cadence anchor the chain starts one interval out, clamps to
        // Monday 9:00 local wall-clock (not 8:00 or 10:00 from naive
        // absolute-time math), and fires lunch at local noon.
        let chain = Scheduler.upcoming(input(
            config: makeConfig(lunch: true),
            now: date(2026, 3, 8, 10, 0)
        ), count: 14)

        XCTAssertEqual(chain.first, Scheduler.Next(date: date(2026, 3, 9, 9, 0), kind: .breakPrompt))
        let monday = chain.filter { $0.date < date(2026, 3, 10, 0, 0) }
        XCTAssertEqual(monday.filter { $0.kind == .lunch }.count, 1)
        XCTAssertEqual(monday.first { $0.kind == .lunch }?.date, date(2026, 3, 9, 12, 0))

        // Break spacing never collapses across the boundary.
        let breaks = monday.filter { $0.kind == .breakPrompt }.map(\.date)
        for (a, b) in zip(breaks, breaks.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b.timeIntervalSince(a), 30 * 60)
        }
    }

    func testWorkStartAfterFallBackIsNineAMLocal() {
        // Friday 2026-10-30 16:55 CDT → next is Monday 2026-11-02 9:00 CST.
        let next = Scheduler.next(input(
            config: makeConfig(),
            now: date(2026, 10, 30, 16, 55),
            lastAcknowledgedAt: date(2026, 10, 30, 16, 50)
        ))
        XCTAssertEqual(next, Scheduler.Next(date: date(2026, 11, 2, 9, 0), kind: .breakPrompt))
    }

    func testLunchAfterFallBackFiresAtLocalNoon() {
        let chain = Scheduler.upcoming(input(
            config: makeConfig(lunch: true),
            now: date(2026, 11, 1, 10, 0),
            lastAcknowledgedAt: date(2026, 10, 30, 16, 0)
        ), count: 14)
        let monday = chain.filter { $0.date < date(2026, 11, 3, 0, 0) }
        XCTAssertEqual(monday.filter { $0.kind == .lunch }.count, 1)
        XCTAssertEqual(monday.first { $0.kind == .lunch }?.date, date(2026, 11, 2, 12, 0))
    }
}
