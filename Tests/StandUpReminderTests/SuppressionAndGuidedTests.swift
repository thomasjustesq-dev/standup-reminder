import XCTest
@testable import StandUpReminder

final class SuppressionAndGuidedTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testHeldLineWhileMeeting() {
        let line = SuppressionStatus.heldLine(
            currentStatus: "In a meeting",
            lastReason: "In a meeting",
            lastAt: now.addingTimeInterval(-120),
            now: now
        )
        XCTAssertEqual(line, "Held: In a meeting · 2m ago")
    }

    func testHeldLineArmedShowsRecentLast() {
        let line = SuppressionStatus.heldLine(
            currentStatus: "Armed",
            lastReason: "Focus mode on",
            lastAt: now.addingTimeInterval(-300),
            now: now
        )
        XCTAssertEqual(line, "Last held: Focus mode on · 5m ago")
    }

    func testHeldLineArmedStaleLastIsNil() {
        let line = SuppressionStatus.heldLine(
            currentStatus: "Armed",
            lastReason: "Focus mode on",
            lastAt: now.addingTimeInterval(-3600),
            now: now
        )
        XCTAssertNil(line)
    }

    func testTopBlockLine() {
        let line = SuppressionStatus.topBlockLine(
            dayKey: "2026-08-10",
            byReason: ["In a meeting": 4, "Away": 1]
        )
        XCTAssertEqual(line, "Top block today: In a meeting (4)")
    }

    func testLeaseLineAliveAndExpired() {
        let alive = SuppressionStatus.leaseLine(
            authorityUpdatedAt: now.addingTimeInterval(-180),
            authorityName: "iMac",
            now: now
        )
        XCTAssertEqual(alive, "lease 3m · iMac")
        let dead = SuppressionStatus.leaseLine(
            authorityUpdatedAt: now.addingTimeInterval(-(20 * 60)),
            authorityName: "iMac",
            now: now
        )
        XCTAssertEqual(dead, "expired 20m · iMac")
    }

    func testBlockStatsRecordsLastHold() {
        var stats = BlockStats()
        stats.record(reason: "In a meeting", dayKey: "2026-08-10", at: now)
        XCTAssertEqual(stats.lastReason, "In a meeting")
        XCTAssertEqual(stats.lastAt, now)
        XCTAssertEqual(stats.byReason["In a meeting"], 1)
        stats.record(reason: "Armed", dayKey: "2026-08-10", at: now)
        // Armed is not a hold — last reason stays meeting
        XCTAssertEqual(stats.lastReason, "In a meeting")
    }

    func testBlockStatsDecodesWithoutLastKeys() throws {
        let json = """
        {"dayKey":"d","byReason":{"Away":2}}
        """.data(using: .utf8)!
        let s = try JSONCoding.decoder().decode(BlockStats.self, from: json)
        XCTAssertEqual(s.byReason["Away"], 2)
        XCTAssertNil(s.lastReason)
    }

    func testEmptyQueueAuthorityBlocking() {
        let r = EmptyQueueReason.classify(
            configEnabled: true,
            isPaused: false,
            isSkipToday: false,
            isSnoozing: false,
            notificationsAuthorized: true,
            upcomingEmpty: true,
            honorsAuthority: true,
            authorityPresence: .meeting
        )
        XCTAssertEqual(r, .authorityBlocking)
        XCTAssertNil(r.displayLine)
    }

    func testEmptyQueueDenied() {
        let r = EmptyQueueReason.classify(
            configEnabled: true,
            isPaused: false,
            isSkipToday: false,
            isSnoozing: false,
            notificationsAuthorized: false,
            upcomingEmpty: true,
            honorsAuthority: false,
            authorityPresence: nil
        )
        XCTAssertEqual(r, .notificationsDenied)
        XCTAssertNotNil(r.displayLine)
    }

    func testGuidedUserInitiatedAlwaysActivates() {
        XCTAssertTrue(GuidedBreakOpenPolicy.shouldActivateApp(
            userInitiated: true,
            stealFocus: false,
            frontmostIsDenylisted: true,
            isFullscreenDeepWork: true
        ))
    }

    func testGuidedAutoNoActivateOnDenylistOrFullscreen() {
        XCTAssertFalse(GuidedBreakOpenPolicy.shouldActivateApp(
            userInitiated: false,
            stealFocus: false,
            frontmostIsDenylisted: true,
            isFullscreenDeepWork: false
        ))
        XCTAssertFalse(GuidedBreakOpenPolicy.shouldActivateApp(
            userInitiated: false,
            stealFocus: false,
            frontmostIsDenylisted: false,
            isFullscreenDeepWork: true
        ))
    }

    func testGuidedAutoActivatesWhenClear() {
        XCTAssertTrue(GuidedBreakOpenPolicy.shouldActivateApp(
            userInitiated: false,
            stealFocus: false,
            frontmostIsDenylisted: false,
            isFullscreenDeepWork: false
        ))
    }
}
