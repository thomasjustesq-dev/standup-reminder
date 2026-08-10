import XCTest
@testable import StandUpReminder

final class AuthorityLeaseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let ttl: TimeInterval = 15 * 60

    func testAliveWithinTTL() {
        let stamp = now.addingTimeInterval(-5 * 60)
        XCTAssertTrue(AuthorityLease.isAlive(updatedAt: stamp, now: now, ttl: ttl))
    }

    func testExpiredPastTTL() {
        let stamp = now.addingTimeInterval(-(ttl + 1))
        XCTAssertFalse(AuthorityLease.isAlive(updatedAt: stamp, now: now, ttl: ttl))
    }

    func testNilStampIsDead() {
        XCTAssertFalse(AuthorityLease.isAlive(updatedAt: nil, now: now, ttl: ttl))
    }

    func testHonorAuthorityOnlyWhenFollowerAndAlive() {
        let alive = now.addingTimeInterval(-60)
        XCTAssertTrue(AuthorityLease.shouldHonorAuthority(
            isFollower: true, authorityUpdatedAt: alive, now: now, ttl: ttl
        ))
        XCTAssertFalse(AuthorityLease.shouldHonorAuthority(
            isFollower: true, authorityUpdatedAt: now.addingTimeInterval(-(ttl + 30)), now: now, ttl: ttl
        ))
        XCTAssertFalse(AuthorityLease.shouldHonorAuthority(
            isFollower: false, authorityUpdatedAt: alive, now: now, ttl: ttl
        ))
    }

    func testModeDegradedWhenExpired() {
        XCTAssertEqual(
            AuthorityLease.mode(
                isFollower: true,
                authorityUpdatedAt: now.addingTimeInterval(-(ttl + 1)),
                now: now,
                ttl: ttl
            ),
            .degraded
        )
        XCTAssertEqual(
            AuthorityLease.mode(
                isFollower: true,
                authorityUpdatedAt: now.addingTimeInterval(-30),
                now: now,
                ttl: ttl
            ),
            .following
        )
    }

    func testFollowerStatusOfflineLocal() {
        let text = AuthorityLease.followerStatusText(
            configEnabled: true,
            isPaused: false,
            isSkipToday: false,
            isSnoozing: false,
            notificationsAuthorized: true,
            authorityPresence: .meeting,
            authorityName: "iMac",
            authorityUpdatedAt: now.addingTimeInterval(-(ttl + 60)),
            upcomingEmpty: false,
            now: now,
            ttl: ttl
        )
        XCTAssertTrue(text.contains("offline") || text.contains("local schedule"), text)
    }

    func testFollowerStatusHonorsMeetingWhenAlive() {
        let text = AuthorityLease.followerStatusText(
            configEnabled: true,
            isPaused: false,
            isSkipToday: false,
            isSnoozing: false,
            notificationsAuthorized: true,
            authorityPresence: .meeting,
            authorityName: "iMac",
            authorityUpdatedAt: now.addingTimeInterval(-30),
            upcomingEmpty: false,
            now: now,
            ttl: ttl
        )
        XCTAssertTrue(text.contains("meeting") || text.contains("Meeting"), text)
    }

    func testFollowerStatusNotificationsDenied() {
        let text = AuthorityLease.followerStatusText(
            configEnabled: true,
            isPaused: false,
            isSkipToday: false,
            isSnoozing: false,
            notificationsAuthorized: false,
            authorityPresence: nil,
            authorityName: nil,
            authorityUpdatedAt: nil,
            upcomingEmpty: true,
            now: now,
            ttl: ttl
        )
        XCTAssertEqual(text, "Notifications denied")
    }

    func testDegradationBadgeNilWhenAlive() {
        XCTAssertNil(AuthorityLease.degradationBadge(
            authorityUpdatedAt: now.addingTimeInterval(-10),
            authorityName: "Mac",
            now: now,
            ttl: ttl
        ))
    }

    func testDegradationBadgeWhenNeverSeen() {
        let badge = AuthorityLease.degradationBadge(
            authorityUpdatedAt: nil,
            authorityName: nil,
            now: now,
            ttl: ttl
        )
        XCTAssertNotNil(badge)
        XCTAssertTrue(badge!.lowercased().contains("push") || badge!.lowercased().contains("authority"))
    }

    func testApplyAuthorityFiltersSkippedWhenNotHonoring() {
        let near = Scheduler.Next(date: now.addingTimeInterval(300), kind: .breakPrompt)
        let chain = [near]
        let filtered = FollowerSchedulePolicy.applyAuthorityFilters(
            chain: chain,
            authorityPresence: .meeting,
            authorityNextFireAt: now.addingTimeInterval(3600),
            now: now,
            honorAuthority: false
        )
        XCTAssertEqual(filtered.count, 1)
    }

    func testApplyAuthorityFiltersDropsBreakBeforeGateWhenHonoring() {
        let near = Scheduler.Next(date: now.addingTimeInterval(300), kind: .breakPrompt)
        let filtered = FollowerSchedulePolicy.applyAuthorityFilters(
            chain: [near],
            authorityPresence: .atDesk,
            authorityNextFireAt: now.addingTimeInterval(1800),
            now: now,
            honorAuthority: true
        )
        XCTAssertTrue(filtered.isEmpty || filtered[0].date >= now.addingTimeInterval(1800))
    }

    func testDiagnosticsDumpContainsVersion() {
        let text = DiagnosticsDump.render(DiagnosticsDump.Input(
            marketingVersion: "4.2.2",
            build: "8",
            bundleId: "com.thomasjust.standupreminder",
            appGroup: "group.com.thomasjust.standupreminder",
            iCloudContainer: "iCloud.com.thomasjust.standupreminder",
            configPath: "/tmp/config.json",
            supportDir: "/tmp/support",
            presence: "At desk",
            cadenceRole: "authority",
            isAuthority: true,
            enabled: true,
            paused: false,
            intervalMinutes: 45,
            baseIntervalMinutes: 45,
            statusMessage: "ok",
            nextFireDescription: "2:00 PM",
            notificationsAuthorized: "authorized",
            iCloudEnabled: true,
            syncSummary: "push just now",
            syncDoctorBody: "container: available",
            authorityLeaseLine: "alive",
            blockStatsReport: "none",
            evidenceLine: "evidence",
            weekStatsLine: "week",
            corruptArtifacts: ["config.json.corrupt"]
        ))
        XCTAssertTrue(text.contains("4.2.2"))
        XCTAssertTrue(text.contains("config.json.corrupt"))
        XCTAssertTrue(text.contains("At desk"))
    }

    func testSyncHealthSeedBanner() {
        var h = SyncHealth(cloudContainerEmpty: true, seedBannerDismissed: false)
        XCTAssertTrue(h.shouldShowSeedBanner)
        h.seedBannerDismissed = true
        XCTAssertFalse(h.shouldShowSeedBanner)
    }

    func testSyncHealthDecodesWithoutNewKeys() throws {
        let json = """
        {"lastPullWasStale":true,"lastPullMessage":"ok"}
        """.data(using: .utf8)!
        let h = try JSONCoding.decoder().decode(SyncHealth.self, from: json)
        XCTAssertTrue(h.lastPullWasStale)
        XCTAssertEqual(h.lastPullMessage, "ok")
        XCTAssertFalse(h.cloudContainerEmpty)
    }
}
