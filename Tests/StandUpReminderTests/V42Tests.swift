import XCTest
@testable import StandUpReminder

/// v4.2 regression coverage: tolerant decoding (the config-wipe class of
/// bug), value clamping, stamped cloud envelopes, and pure engine helpers.
final class V42Tests: XCTestCase {

    // MARK: Tolerant decoding

    func testFeatureFlagsDecodeWithMissingKeys() throws {
        let json = #"{"iCloudSyncEnabled": true}"#.data(using: .utf8)!
        let flags = try JSONCoding.decoder().decode(FeatureFlags.self, from: json)
        XCTAssertTrue(flags.iCloudSyncEnabled)
        XCTAssertEqual(flags.webcamStillnessMinutes, FeatureFlags.default.webcamStillnessMinutes)
    }

    func testFeatureFlagsDecodeEmptyObject() throws {
        let json = "{}".data(using: .utf8)!
        let flags = try JSONCoding.decoder().decode(FeatureFlags.self, from: json)
        XCTAssertEqual(flags, FeatureFlags.default)
    }

    /// The exact failure that used to wipe configs: a `features` object that
    /// exists but lacks keys added in a later version.
    func testAppConfigDecodeWithPartialNestedFeatures() throws {
        let json = #"{"intervalMinutes": 45, "features": {"voiceAnnouncementsEnabled": true}}"#.data(using: .utf8)!
        let config = try JSONCoding.decoder().decode(AppConfig.self, from: json)
        XCTAssertEqual(config.intervalMinutes, 45)
        XCTAssertTrue(config.features.voiceAnnouncementsEnabled)
        XCTAssertEqual(config.features.teamQuiet, TeamQuietConfig.default)
    }

    func testAppConfigDecodeWithPartialLunchAndSchedule() throws {
        let json = #"{"lunch": {"hour": 13}, "scheduleByWeekday": {"1": {"startHour": 8}}}"#.data(using: .utf8)!
        let config = try JSONCoding.decoder().decode(AppConfig.self, from: json)
        XCTAssertEqual(config.lunch.hour, 13)
        XCTAssertEqual(config.lunch.minute, LunchConfig.default.minute)
        XCTAssertEqual(config.scheduleByWeekday["1"]?.startHour, 8)
        XCTAssertEqual(config.scheduleByWeekday["1"]?.endHour, DaySchedule.standard.endHour)
    }

    func testQuietWindowDecodeWithMissingKeys() throws {
        let json = #"{"startHour": 9, "endHour": 10}"#.data(using: .utf8)!
        let window = try JSONCoding.decoder().decode(QuietWindow.self, from: json)
        XCTAssertEqual(window.startHour, 9)
        XCTAssertEqual(window.endHour, 10)
        XCTAssertEqual(window.startMinute, 0)
        XCTAssertFalse(window.id.isEmpty)
    }

    // MARK: Validation

    func testValidatedClampsInsaneValues() {
        var config = AppConfig.default
        config.intervalMinutes = 0
        config.idleSkipMinutes = -5
        config.guidedBreakSeconds = 100_000
        config.lunch.hour = 99
        config.adaptiveMinMinutes = 400
        config.adaptiveMaxMinutes = 10
        let v = config.validated()
        XCTAssertEqual(v.intervalMinutes, 5)
        XCTAssertEqual(v.idleSkipMinutes, 1)
        XCTAssertEqual(v.guidedBreakSeconds, 600)
        XCTAssertEqual(v.lunch.hour, 23)
        XCTAssertGreaterThanOrEqual(v.adaptiveMaxMinutes, v.adaptiveMinMinutes)
    }

    func testValidatedLeavesSaneValuesAlone() {
        let v = AppConfig.default.validated()
        XCTAssertEqual(v, AppConfig.default)
    }

    // MARK: Cloud envelope

    func testCloudEnvelopeRoundTrip() throws {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let envelope = CloudEnvelope(updatedAt: stamp, deviceName: "test-mac", payload: AppConfig.default)
        let data = try JSONCoding.encoder().encode(envelope)
        let decoded = try JSONCoding.decoder().decode(CloudEnvelope<AppConfig>.self, from: data)
        XCTAssertEqual(decoded.updatedAt, stamp)
        XCTAssertEqual(decoded.deviceName, "test-mac")
        XCTAssertEqual(decoded.payload, AppConfig.default)
    }

    /// v4.1 pushed bare payloads; those must still decode as the payload
    /// type (the envelope decode fails first, then the bare fallback hits).
    func testBarePayloadStillDecodesAsConfig() throws {
        let data = try JSONCoding.encoder().encode(AppConfig.default)
        XCTAssertThrowsError(try strictEnvelopeDecode(data))
        let bare = try JSONCoding.decoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(bare, AppConfig.default)
    }

    private func strictEnvelopeDecode(_ data: Data) throws -> CloudEnvelope<AppConfig> {
        try JSONCoding.decoder().decode(CloudEnvelope<AppConfig>.self, from: data)
    }

    // MARK: Engine helpers

    func testFindRecoveryTopLevelAndNested() {
        XCTAssertEqual(FightingShapeMonitor.findRecovery(in: ["recovery": 55.0]), 55.0)
        XCTAssertEqual(FightingShapeMonitor.findRecovery(in: ["kpis": ["recovery_score": 28]]), 28.0)
        XCTAssertNil(FightingShapeMonitor.findRecovery(in: ["recovery": 300.0]))
        XCTAssertNil(FightingShapeMonitor.findRecovery(in: ["unrelated": "x"]))
    }

    func testQueuedIdentifierEmbedsGeneration() {
        let id = NotificationManager.queuedIdentifier(generation: 1_752_000_000, slot: "7")
        XCTAssertTrue(id.hasPrefix(NotificationManager.queuedIdPrefix))
        XCTAssertTrue(id.contains("1752000000"))
        XCTAssertTrue(id.hasSuffix("-7"))
    }

    /// Explicit weekend hours must survive; the skip-weekends preference only
    /// wins when it is on.
    func testWeekendScheduleHonoredWhenWeekdaysOnlyOff() {
        var config = AppConfig.default
        config.scheduleTimeZoneIdentifier = "America/Chicago"
        config.scheduleByWeekday["6"] = DaySchedule(startHour: 10, endHour: 14)
        config.weekdaysOnly = false
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        // 2026-07-18 is a Saturday.
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 11))!
        XCTAssertNotNil(config.schedule(for: saturday))
        config.weekdaysOnly = true
        XCTAssertNil(config.schedule(for: saturday))
    }
}
