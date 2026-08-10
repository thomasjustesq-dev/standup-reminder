import XCTest
@testable import StandUpReminder

final class FollowerSchedulePolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testLunchAlwaysScheduled() {
        let lunch = Scheduler.Next(date: now.addingTimeInterval(60), kind: .lunch)
        XCTAssertTrue(FollowerSchedulePolicy.shouldSchedule(
            lunch,
            authorityPresence: .meeting,
            authorityNextFireAt: now.addingTimeInterval(3600),
            now: now
        ))
    }

    func testBreakBeforeAuthorityGateDropped() {
        let breakSoon = Scheduler.Next(date: now.addingTimeInterval(300), kind: .breakPrompt)
        let gate = now.addingTimeInterval(1800)
        XCTAssertFalse(FollowerSchedulePolicy.shouldSchedule(
            breakSoon,
            authorityPresence: .atDesk,
            authorityNextFireAt: gate,
            now: now
        ))
    }

    func testBreakAfterAuthorityGateKept() {
        let gate = now.addingTimeInterval(600)
        let breakLater = Scheduler.Next(date: now.addingTimeInterval(900), kind: .breakPrompt)
        XCTAssertTrue(FollowerSchedulePolicy.shouldSchedule(
            breakLater,
            authorityPresence: .atDesk,
            authorityNextFireAt: gate,
            now: now
        ))
    }

    func testMeetingSuppressesNearBreaksWithoutGate() {
        let near = Scheduler.Next(date: now.addingTimeInterval(600), kind: .breakPrompt)
        let far = Scheduler.Next(date: now.addingTimeInterval(5 * 3600), kind: .breakPrompt)
        XCTAssertFalse(FollowerSchedulePolicy.shouldSchedule(
            near, authorityPresence: .meeting, authorityNextFireAt: nil, now: now
        ))
        XCTAssertTrue(FollowerSchedulePolicy.shouldSchedule(
            far, authorityPresence: .meeting, authorityNextFireAt: nil, now: now
        ))
    }

    func testClampFirstBreakToGate() {
        let gate = now.addingTimeInterval(1200)
        let chain = [
            Scheduler.Next(date: now.addingTimeInterval(300), kind: .breakPrompt),
            Scheduler.Next(date: now.addingTimeInterval(2400), kind: .breakPrompt)
        ]
        let clamped = FollowerSchedulePolicy.clampFirstBreak(chain: chain, authorityNextFireAt: gate)
        XCTAssertEqual(clamped[0].date, gate)
        XCTAssertEqual(clamped[1].date, now.addingTimeInterval(2400))
    }

    func testBlocksFullFirePresence() {
        XCTAssertTrue(FollowerSchedulePolicy.blocksFullFire(.meeting))
        XCTAssertTrue(FollowerSchedulePolicy.blocksFullFire(.away))
        XCTAssertFalse(FollowerSchedulePolicy.blocksFullFire(.atDesk))
    }

    func testHonorAuthorityFalseKeepsAllSlots() {
        let breakSoon = Scheduler.Next(date: now.addingTimeInterval(300), kind: .breakPrompt)
        XCTAssertTrue(FollowerSchedulePolicy.shouldSchedule(
            breakSoon,
            authorityPresence: .meeting,
            authorityNextFireAt: now.addingTimeInterval(3600),
            now: now,
            honorAuthority: false
        ))
    }

    func testClampNoOpWhenNotHonoring() {
        let gate = now.addingTimeInterval(1200)
        let chain = [Scheduler.Next(date: now.addingTimeInterval(300), kind: .breakPrompt)]
        let clamped = FollowerSchedulePolicy.clampFirstBreak(
            chain: chain, authorityNextFireAt: gate, honorAuthority: false
        )
        XCTAssertEqual(clamped[0].date, now.addingTimeInterval(300))
    }
}
