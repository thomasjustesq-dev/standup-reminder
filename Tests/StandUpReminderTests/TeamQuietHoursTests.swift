import XCTest

@testable import StandUpReminder

/// `TeamQuietHours.isInTeamQuiet` is the gate iOS uses to drop reminders that
/// would land inside a team quiet window. It matters more on iOS than on the
/// Mac: the Mac re-checks quiet hours at fire time, but iOS pre-schedules local
/// notifications days ahead, so anything this filter lets through is already
/// committed to the notification queue and will ring.
///
/// `QuietWindow.contains` carries the two details worth pinning — the interval
/// is half-open, and a window whose end is before its start wraps midnight.
final class TeamQuietHoursTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Chicago")!

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal
    }

    private func date(_ hour: Int, _ minute: Int, in zone: TimeZone? = nil) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone ?? self.zone
        return cal.date(
            from: DateComponents(year: 2026, month: 3, day: 10, hour: hour, minute: minute))!
    }

    private func window(_ startHour: Int, _ startMinute: Int, _ endHour: Int, _ endMinute: Int)
        -> QuietWindow
    {
        QuietWindow(
            startHour: startHour, startMinute: startMinute,
            endHour: endHour, endMinute: endMinute, label: "test")
    }

    private func flags(enabled: Bool, windows: [QuietWindow]) throws -> FeatureFlags {
        var config = try JSONCoding.decoder().decode(AppConfig.self, from: Data("{}".utf8))
        config.features.teamQuiet.enabled = enabled
        config.features.teamQuiet.windows = windows
        return config.features
    }

    // MARK: the enable switch

    func testDisabledConfigIsNeverQuietEvenInsideAWindow() throws {
        let features = try flags(enabled: false, windows: [window(9, 0, 17, 0)])
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(12, 0), calendar: calendar))
    }

    func testEnabledWithNoWindowsIsNeverQuiet() throws {
        let features = try flags(enabled: true, windows: [])
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(12, 0), calendar: calendar))
    }

    // MARK: same-day window, half-open [start, end)

    func testInsideASameDayWindowIsQuiet() throws {
        let features = try flags(enabled: true, windows: [window(9, 0, 17, 0)])
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(12, 30), calendar: calendar))
    }

    func testStartBoundaryIsInclusive() throws {
        let features = try flags(enabled: true, windows: [window(9, 0, 17, 0)])
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(9, 0), calendar: calendar))
    }

    func testEndBoundaryIsExclusive() throws {
        let features = try flags(enabled: true, windows: [window(9, 0, 17, 0)])
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(17, 0), calendar: calendar),
            "the window is half-open, so a reminder exactly at the end time may fire")
    }

    func testOutsideASameDayWindowIsNotQuiet() throws {
        let features = try flags(enabled: true, windows: [window(9, 0, 17, 0)])
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(8, 59), calendar: calendar))
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(17, 1), calendar: calendar))
    }

    func testMinuteGranularityIsHonored() throws {
        let features = try flags(enabled: true, windows: [window(9, 30, 10, 15)])
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(9, 29), calendar: calendar))
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(9, 30), calendar: calendar))
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(10, 14), calendar: calendar))
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(10, 15), calendar: calendar))
    }

    // MARK: midnight-spanning window (end before start)

    func testOvernightWindowCoversTheEveningSide() throws {
        let features = try flags(enabled: true, windows: [window(22, 0, 6, 0)])
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(23, 0), calendar: calendar))
    }

    func testOvernightWindowCoversTheMorningSide() throws {
        let features = try flags(enabled: true, windows: [window(22, 0, 6, 0)])
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(2, 0), calendar: calendar))
    }

    func testOvernightWindowLeavesTheMiddleOfTheDayOpen() throws {
        let features = try flags(enabled: true, windows: [window(22, 0, 6, 0)])
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(12, 0), calendar: calendar))
    }

    func testOvernightWindowBoundaries() throws {
        let features = try flags(enabled: true, windows: [window(22, 0, 6, 0)])
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(22, 0), calendar: calendar))
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(6, 0), calendar: calendar))
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(5, 59), calendar: calendar))
    }

    // MARK: multiple windows

    func testAnyMatchingWindowMakesItQuiet() throws {
        let features = try flags(
            enabled: true, windows: [window(9, 0, 10, 0), window(14, 0, 15, 0)])
        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(14, 30), calendar: calendar))
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: date(12, 0), calendar: calendar))
    }

    // MARK: the calendar argument actually decides the wall clock

    func testWindowIsEvaluatedInTheSuppliedCalendarsTimeZone() throws {
        let features = try flags(enabled: true, windows: [window(9, 0, 17, 0)])
        // One instant, read against two zones: 12:00 in Chicago is 18:00 in
        // London, which is outside the 09:00–17:00 window.
        let instant = date(12, 0)

        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!

        XCTAssertTrue(
            TeamQuietHours.isInTeamQuiet(config: features, at: instant, calendar: calendar))
        XCTAssertFalse(
            TeamQuietHours.isInTeamQuiet(config: features, at: instant, calendar: london),
            "the supplied calendar's zone must decide the wall-clock hour")
    }

    // MARK: decoding a feed with missing fields

    func testQuietWindowDecodesWithMissingFieldsRatherThanFailing() throws {
        // Feed JSON is fetched from a URL the user configures; a window missing
        // fields must degrade to zeros, not abort the whole decode.
        let json = #"{"windows": [{"startHour": 22, "label": "on-call"}]}"#
        let feed = try JSONCoding.decoder().decode(TeamQuietHours.Feed.self, from: Data(json.utf8))

        let parsed = try XCTUnwrap(feed.windows.first)
        XCTAssertEqual(parsed.startHour, 22)
        XCTAssertEqual(parsed.startMinute, 0)
        XCTAssertEqual(parsed.endHour, 0)
        XCTAssertEqual(parsed.label, "on-call")
        XCTAssertFalse(parsed.id.isEmpty, "a missing id must be generated, not empty")
    }
}
