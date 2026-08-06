import XCTest
@testable import StandUpReminder

final class PresenceAndSimulationTests: XCTestCase {
    private let timeZone = "America/Chicago"

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testPresencePriorityMeetingBeatsAtDesk() {
        var ctx = FireGateContext()
        ctx.inMeeting = true
        XCTAssertEqual(PresenceResolver.resolve(ctx), .meeting)
        let result = FireGateEvaluator.evaluate(ctx)
        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.presence, .meeting)
    }

    func testPresenceAwayBeforeMeeting() {
        var ctx = FireGateContext()
        ctx.idle = true
        ctx.inMeeting = true
        XCTAssertEqual(PresenceResolver.resolve(ctx), .away)
    }

    func testAtDeskAllowsFire() {
        let result = FireGateEvaluator.evaluate(FireGateContext())
        XCTAssertTrue(result.allowed)
        XCTAssertEqual(result.presence, .atDesk)
        XCTAssertEqual(result.status, "Armed")
    }

    func testCadenceRoleAutomatic() {
        XCTAssertEqual(CadenceRole.resolved(configRole: .automatic, isMac: true), .authority)
        XCTAssertEqual(CadenceRole.resolved(configRole: .automatic, isMac: false), .follower)
    }

    func testDaySimulationFiresWhenAtDesk() {
        var config = AppConfig.default
        config.scheduleTimeZoneIdentifier = timeZone
        config.lunch.enabled = false
        config.windDown.enabled = false
        let start = date(2026, 7, 15, 9, 0)
        let timeline = [
            DaySimulation.PresenceSample(at: start, presence: .atDesk)
        ]
        let events = DaySimulation.run(DaySimulation.Input(
            config: config,
            intervalMinutes: 30,
            dayStart: start,
            presenceTimeline: timeline,
            lastAcknowledgedAt: start,
            autoAck: true,
            ackDelay: 30
        ))
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.allSatisfy { $0.presence == .atDesk })
        XCTAssertTrue(events.contains { $0.kind == .breakPrompt })
    }

    func testDaySimulationSuppressesDuringMeeting() {
        var config = AppConfig.default
        config.scheduleTimeZoneIdentifier = timeZone
        config.lunch.enabled = false
        config.windDown.enabled = false
        let start = date(2026, 7, 15, 9, 0)
        let timeline = [
            DaySimulation.PresenceSample(at: start, presence: .meeting)
        ]
        let events = DaySimulation.run(DaySimulation.Input(
            config: config,
            intervalMinutes: 30,
            dayStart: start,
            presenceTimeline: timeline,
            lastAcknowledgedAt: start,
            autoAck: true
        ))
        XCTAssertTrue(events.filter { $0.kind == .breakPrompt }.isEmpty)
    }

    func testAdaptiveCoachLowCompletionLengthens() {
        var stats = StatsSnapshot()
        for i in 0..<7 {
            let key = String(format: "2026-07-%02d", 10 + i)
            stats.recordShown(on: key)
            stats.recordShown(on: key)
            stats.recordSnooze(on: key)
        }
        let ref = date(2026, 7, 16, 12, 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        let suggestion = AdaptiveCoach.suggest(
            config: AppConfig.default,
            stats: stats,
            samples: [5, 5, 5],
            reference: ref,
            calendar: calendar
        )
        XCTAssertGreaterThanOrEqual(suggestion.recommendedMinutes, AppConfig.default.intervalMinutes)
        XCTAssertFalse(suggestion.explanation.isEmpty)
    }

    func testBreakEvidenceBacked() {
        XCTAssertTrue(BreakEvidence.awayReturn.isEvidenceBacked)
        XCTAssertFalse(BreakEvidence.selfLogged.isEvidenceBacked)
    }
}
