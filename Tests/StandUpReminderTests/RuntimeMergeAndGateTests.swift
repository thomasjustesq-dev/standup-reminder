import XCTest
@testable import StandUpReminder

final class RuntimeMergeAndGateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Runtime merge

    func testClearSnoozeWhenRemoteIsNewerAndNil() {
        let local = RuntimeMerge.Local(
            snoozeUntil: now.addingTimeInterval(600),
            lastRuntimeMutationAt: now.addingTimeInterval(-120)
        )
        let remote = CloudSync.RuntimeDoc(
            updatedAt: now.addingTimeInterval(-30),
            deviceName: "phone",
            snoozeUntil: nil
        )
        let outcome = RuntimeMerge.apply(local: local, remote: remote, now: now)
        XCTAssertTrue(outcome.changed)
        XCTAssertNil(outcome.local.snoozeUntil)
    }

    func testStaleRemoteCannotClearSnooze() {
        let local = RuntimeMerge.Local(
            snoozeUntil: now.addingTimeInterval(600),
            lastRuntimeMutationAt: now
        )
        let remote = CloudSync.RuntimeDoc(
            updatedAt: now.addingTimeInterval(-60),
            deviceName: "phone",
            snoozeUntil: nil
        )
        let outcome = RuntimeMerge.apply(local: local, remote: remote, now: now)
        XCTAssertFalse(outcome.changed)
        XCTAssertEqual(outcome.local.snoozeUntil, local.snoozeUntil)
    }

    func testRemoteFutureSnoozeExtendsLocal() {
        let local = RuntimeMerge.Local(
            snoozeUntil: now.addingTimeInterval(60),
            lastRuntimeMutationAt: now.addingTimeInterval(-300)
        )
        let remoteSnooze = now.addingTimeInterval(900)
        let remote = CloudSync.RuntimeDoc(
            updatedAt: now,
            deviceName: "mac",
            snoozeUntil: remoteSnooze
        )
        let outcome = RuntimeMerge.apply(local: local, remote: remote, now: now)
        XCTAssertTrue(outcome.changed)
        XCTAssertEqual(outcome.local.snoozeUntil, remoteSnooze)
    }

    func testClearSkipTodayWhenRemoteInactive() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let today = calendar.startOfDay(for: now)
        let local = RuntimeMerge.Local(
            skipRestOfDayDate: today,
            lastRuntimeMutationAt: now.addingTimeInterval(-60)
        )
        let remote = CloudSync.RuntimeDoc(
            updatedAt: now,
            deviceName: "phone",
            skipRestOfDayDate: nil
        )
        let outcome = RuntimeMerge.apply(local: local, remote: remote, now: now, calendar: calendar)
        XCTAssertTrue(outcome.changed)
        XCTAssertNil(outcome.local.skipRestOfDayDate)
    }

    func testEffectiveIntervalPropagates() {
        let local = RuntimeMerge.Local(lastRuntimeMutationAt: now.addingTimeInterval(-10))
        let remote = CloudSync.RuntimeDoc(
            updatedAt: now,
            deviceName: "mac",
            effectiveIntervalMinutes: 22
        )
        let outcome = RuntimeMerge.apply(local: local, remote: remote, now: now)
        XCTAssertEqual(outcome.local.effectiveIntervalMinutes, 22)
    }

    func testPauseAuthoritativeOnNewerDoc() {
        let local = RuntimeMerge.Local(
            isPaused: false,
            lastRuntimeMutationAt: now.addingTimeInterval(-60)
        )
        let remote = CloudSync.RuntimeDoc(
            updatedAt: now,
            deviceName: "phone",
            isPaused: true
        )
        let outcome = RuntimeMerge.apply(local: local, remote: remote, now: now)
        XCTAssertTrue(outcome.changed)
        XCTAssertTrue(outcome.local.isPaused)
    }

    func testResumeClearsPauseOnNewerDoc() {
        let local = RuntimeMerge.Local(
            isPaused: true,
            lastRuntimeMutationAt: now.addingTimeInterval(-60)
        )
        let remote = CloudSync.RuntimeDoc(
            updatedAt: now,
            deviceName: "mac",
            isPaused: false
        )
        let outcome = RuntimeMerge.apply(local: local, remote: remote, now: now)
        XCTAssertFalse(outcome.local.isPaused)
    }

    func testForwardOnlyAnchors() {
        let earlier = now.addingTimeInterval(-3600)
        let later = now.addingTimeInterval(-60)
        let local = RuntimeMerge.Local(
            lastAcknowledgedAt: later,
            lastRuntimeMutationAt: now.addingTimeInterval(-30)
        )
        let remote = CloudSync.RuntimeDoc(
            updatedAt: now,
            deviceName: "phone",
            lastAcknowledgedAt: earlier
        )
        let outcome = RuntimeMerge.apply(local: local, remote: remote, now: now)
        XCTAssertEqual(outcome.local.lastAcknowledgedAt, later)
    }

    // MARK: Fire gates

    func testArmedWhenDefaultContext() {
        let result = FireGateEvaluator.evaluate(FireGateContext())
        XCTAssertTrue(result.allowed)
        XCTAssertEqual(result.status, "Armed")
    }

    func testPausedBlocks() {
        var ctx = FireGateContext()
        ctx.paused = true
        let result = FireGateEvaluator.evaluate(ctx)
        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.status, "Paused")
    }

    func testDeepWorkBlocksUntilOverdue() {
        var ctx = FireGateContext()
        ctx.deepWork = true
        ctx.deepWorkEnabled = true
        ctx.sinceAnchor = 10 * 60
        ctx.overdueLimit = 60 * 60
        XCTAssertFalse(FireGateEvaluator.evaluate(ctx).allowed)

        ctx.sinceAnchor = 90 * 60
        XCTAssertTrue(FireGateEvaluator.evaluate(ctx).allowed)
    }

    func testMeetingAndFocusAndIdle() {
        var ctx = FireGateContext()
        ctx.inMeeting = true
        XCTAssertEqual(FireGateEvaluator.evaluate(ctx).status, "In a meeting")
        ctx.inMeeting = false
        ctx.focused = true
        XCTAssertEqual(FireGateEvaluator.evaluate(ctx).status, "Focus mode on")
        ctx.focused = false
        ctx.idle = true
        XCTAssertEqual(FireGateEvaluator.evaluate(ctx).status, "Away")
    }

    func testWarmUpSkippedForLunch() {
        var ctx = FireGateContext()
        ctx.minActiveSeconds = 20 * 60
        ctx.activeFor = 30
        ctx.isLunchOrWindDown = false
        XCTAssertFalse(FireGateEvaluator.evaluate(ctx).allowed)
        ctx.isLunchOrWindDown = true
        XCTAssertTrue(FireGateEvaluator.evaluate(ctx).allowed)
    }

    func testEnvironmentGateIgnoresFocus() {
        var ctx = FireGateContext()
        ctx.focused = true
        ctx.inMeeting = true
        XCTAssertTrue(FireGateEvaluator.environmentAllows(ctx))
        ctx.screenLocked = true
        XCTAssertFalse(FireGateEvaluator.environmentAllows(ctx))
    }

    // MARK: Diagnostics URL

    func testDiagnosticsRequiresHTTPS() {
        XCTAssertEqual(DiagnosticsURL.validate("http://example.com/hook").error, .notHTTPS)
        XCTAssertNil(DiagnosticsURL.validate("https://example.com/hook").error)
        XCTAssertEqual(DiagnosticsURL.validate("https://localhost/x").error, .blockedHost)
        XCTAssertEqual(DiagnosticsURL.validate("https://192.168.1.1/x").error, .blockedHost)
        XCTAssertEqual(DiagnosticsURL.validate("").error, .empty)
    }

    // MARK: Identity + version

    func testAppIdentityStable() {
        XCTAssertEqual(AppIdentity.appGroupID, "group.com.thomasjust.standupreminder")
        XCTAssertEqual(AppIdentity.iCloudContainer, "iCloud.com.thomasjust.standupreminder")
        XCTAssertEqual(AppVersion.marketing, "4.2.4")
    }
}

private extension Result where Failure == DiagnosticsURL.Rejection {
    var error: DiagnosticsURL.Rejection? {
        if case .failure(let e) = self { return e }
        return nil
    }
}
