import XCTest
@testable import StandUpReminder

/// Tests for the debug harness commands and the debug panel access gate.
final class DebugHarnessTests: XCTestCase {

    // MARK: - Helpers

    /// A fixed-clock, fully-populated Scheduler.Input so tests are
    /// deterministic regardless of the wall clock.
    private func makeInput(
        now: Date = Date(timeIntervalSince1970: 1_752_566_400), // 2025-07-15 09:00 UTC
        paused: Bool = false
    ) -> Scheduler.Input {
        var config = AppConfig.default
        config.scheduleTimeZoneIdentifier = "America/Chicago"
        config.lunch.enabled = true
        config.windDown.enabled = true
        return Scheduler.Input(
            config: config,
            intervalMinutes: 30,
            now: now,
            paused: paused,
            snoozeUntil: nil,
            lastReminderAt: nil,
            lastAcknowledgedAt: now.addingTimeInterval(-10 * 60),
            deskPhaseStartedAt: nil,
            lunchFiredDayKey: nil,
            windDownFiredDayKey: nil
        )
    }

    // MARK: - Non-empty output

    func testRuleTraceIsNonEmpty() {
        let output = DebugCommands.ruleTrace(input: makeInput())
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(output.contains("Rule Evaluation Trace"),
                      "ruleTrace output should contain the section header")
    }

    func testRuleTraceContainsResultLine() {
        let output = DebugCommands.ruleTrace(input: makeInput())
        XCTAssertTrue(output.contains("next :"),
                      "ruleTrace output should report the next scheduled reminder")
    }

    func testScheduleSnapshotIsNonEmpty() {
        let output = DebugCommands.scheduleSnapshot(input: makeInput())
        XCTAssertFalse(output.isEmpty)
        XCTAssertNotEqual(output, "[]",
                          "scheduleSnapshot should return at least one entry for a normal workday input")
    }

    func testScheduleSnapshotIsValidJSON() throws {
        let output = DebugCommands.scheduleSnapshot(input: makeInput())
        let data = Data(output.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(json is [[String: Any]],
                      "scheduleSnapshot output should be a JSON array of objects")
    }

    func testDeterminismCheckIsNonEmpty() {
        let output = DebugCommands.determinismCheck(input: makeInput())
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(output.contains("Determinism Check"))
    }

    func testConfigReportIsNonEmpty() {
        let output = DebugCommands.configReport(config: AppConfig.default)
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(output.hasPrefix("{"),
                      "configReport output should be a JSON object")
    }

    // MARK: - Snapshot stability

    func testSnapshotIsStableAcrossTwoCalls() {
        let input = makeInput()
        let first = DebugCommands.scheduleSnapshot(input: input)
        let second = DebugCommands.scheduleSnapshot(input: input)
        XCTAssertEqual(first, second,
                       "scheduleSnapshot must be deterministic: same input → same output")
    }

    func testDeterminismCheckReportsPass() {
        let output = DebugCommands.determinismCheck(input: makeInput())
        XCTAssertTrue(output.contains("PASS"),
                      "determinismCheck should report PASS for a pure Scheduler.Input")
    }

    // MARK: - Debug panel access gate

    func testDebugPanelNotAccessibleWithoutFlag() {
        // XCTest does not inject `--debug` into the process arguments.
        // In release builds DebugEnvironment.isDebugMode is unconditionally
        // false; in debug builds it requires the explicit launch argument.
        // Either way the panel must be inaccessible in a normal test run.
        XCTAssertFalse(DebugEnvironment.isDebugMode,
                       "Debug panel must not be accessible without the --debug launch argument")
    }
}
