import XCTest
@testable import StandUpReminder

final class ConfigStoreAndUpcomingTests: XCTestCase {
    private let timeZone = "America/Chicago"

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
        let backup = url.deletingLastPathComponent().appendingPathComponent("config.test-backup.json")
        let hadOriginal = FileManager.default.fileExists(atPath: url.path)
        if hadOriginal {
            try? FileManager.default.removeItem(at: backup)
            try FileManager.default.copyItem(at: url, to: backup)
        }
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("corrupt"))
            if hadOriginal {
                try? FileManager.default.copyItem(at: backup, to: url)
                try? FileManager.default.removeItem(at: backup)
            }
        }

        let garbage = Data(#"{"enabled": "not-a-bool", "features": 1}"#.utf8)
        try garbage.write(to: url, options: .atomic)
        let loaded = ConfigStore.load()
        XCTAssertEqual(loaded.intervalMinutes, AppConfig.default.intervalMinutes)
        let corrupt = url.appendingPathExtension("corrupt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: corrupt.path))
        let preserved = try Data(contentsOf: corrupt)
        XCTAssertEqual(preserved, garbage)
        // Original path still holds the garbage (not overwritten with defaults)
        XCTAssertEqual(try Data(contentsOf: url), garbage)
    }

    func testRuntimeDocRoundTripWithEffectiveInterval() throws {
        let doc = CloudSync.RuntimeDoc(
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName: "mac",
            lastAcknowledgedAt: Date(timeIntervalSince1970: 1_700_000_100),
            snoozeUntil: nil,
            effectiveIntervalMinutes: 27
        )
        let data = try JSONCoding.encoder().encode(doc)
        let decoded = try JSONCoding.decoder().decode(CloudSync.RuntimeDoc.self, from: data)
        XCTAssertEqual(decoded.effectiveIntervalMinutes, 27)
        XCTAssertNil(decoded.snoozeUntil)
        XCTAssertEqual(decoded.deviceName, "mac")
    }
}
