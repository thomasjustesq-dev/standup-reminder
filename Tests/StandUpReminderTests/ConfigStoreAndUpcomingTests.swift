import XCTest
@testable import StandUpReminder

final class ConfigStoreAndUpcomingTests: XCTestCase {
    private let timeZone = "America/Chicago"

    override func setUp() {
        super.setUp()
        _ = Paths.useTemporarySupportDirectory(label: "config-tests")
    }

    override func tearDown() {
        Paths.resetSupportDirectoryOverride()
        super.tearDown()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    func testUpcomingChainUsesEffectiveInterval() {
        var config = AppConfig.default
        config.scheduleTimeZoneIdentifier = timeZone
        config.lunch.enabled = false
        config.windDown.enabled = false
        let input = Scheduler.Input(
            config: config,
            intervalMinutes: 20,
            now: date(2026, 7, 15, 10, 0),
            paused: false,
            snoozeUntil: nil,
            lastReminderAt: date(2026, 7, 15, 10, 0),
            lastAcknowledgedAt: date(2026, 7, 15, 10, 0),
            deskPhaseStartedAt: nil,
            lunchFiredDayKey: nil,
            windDownFiredDayKey: nil
        )
        let chain = Scheduler.upcoming(input, count: 3)
        XCTAssertEqual(chain.count, 3)
        XCTAssertEqual(chain[0].date, date(2026, 7, 15, 10, 20))
        XCTAssertEqual(chain[1].date, date(2026, 7, 15, 10, 40))
        XCTAssertEqual(chain[2].date, date(2026, 7, 15, 11, 0))
    }

    func testCorruptConfigPreservedOnDisk() throws {
        let url = Paths.configFile
        let garbage = Data(#"{"enabled": "not-a-bool", "features": 1}"#.utf8)
        try garbage.write(to: url, options: .atomic)
        let loaded = ConfigStore.load()
        XCTAssertEqual(loaded.intervalMinutes, AppConfig.default.intervalMinutes)
        let corrupt = url.appendingPathExtension("corrupt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: corrupt.path))
        let preserved = try Data(contentsOf: corrupt)
        XCTAssertEqual(preserved, garbage)
        XCTAssertEqual(try Data(contentsOf: url), garbage)
    }

    func testRuntimeDocRoundTripWithEffectiveIntervalAndPause() throws {
        let doc = CloudSync.RuntimeDoc(
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName: "mac",
            lastAcknowledgedAt: Date(timeIntervalSince1970: 1_700_000_100),
            snoozeUntil: nil,
            effectiveIntervalMinutes: 27,
            isPaused: true
        )
        let data = try JSONCoding.encoder().encode(doc)
        let decoded = try JSONCoding.decoder().decode(CloudSync.RuntimeDoc.self, from: data)
        XCTAssertEqual(decoded.effectiveIntervalMinutes, 27)
        XCTAssertNil(decoded.snoozeUntil)
        XCTAssertEqual(decoded.isPaused, true)
        XCTAssertEqual(decoded.deviceName, "mac")
    }

    func testWeekHighlights() {
        var stats = StatsSnapshot()
        stats.recordDone(on: "2026-07-14")
        stats.recordDone(on: "2026-07-14")
        stats.recordDone(on: "2026-07-15")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        let ref = date(2026, 7, 15, 12, 0)
        let h = stats.weekHighlights(reference: ref, calendar: calendar)
        XCTAssertEqual(h?.bestDay, "2026-07-14")
        XCTAssertEqual(h?.bestDone, 2)
    }

    func testGuidedBreakOpenModes() {
        XCTAssertFalse(GuidedBreakOpenMode.never.shouldAutoOpen(mode: "breakPrompt"))
        XCTAssertFalse(GuidedBreakOpenMode.bannerOnly.shouldAutoOpen(mode: "sitStand"))
        XCTAssertTrue(GuidedBreakOpenMode.catchUpAndSitStand.shouldAutoOpen(mode: "sitStand"))
        XCTAssertFalse(GuidedBreakOpenMode.catchUpAndSitStand.shouldAutoOpen(mode: "breakPrompt"))
        XCTAssertTrue(GuidedBreakOpenMode.always.shouldAutoOpen(mode: "breakPrompt"))
    }

    func testAdaptiveHysteresis() {
        XCTAssertFalse(RuntimeMerge.shouldPublishAdaptiveChange(from: 30, to: 32))
        XCTAssertTrue(RuntimeMerge.shouldPublishAdaptiveChange(from: 30, to: 35))
    }
}
