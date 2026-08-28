import XCTest
@testable import StandUpReminder

final class AppDenylistAndHealthTests: XCTestCase {
    func testDenylistNormalizesWhitespaceCaseAndDuplicates() {
        XCTAssertEqual(
            AppDenylist.normalized([
                "  COM.MICROSOFT.TEAMS  ",
                "com.microsoft.teams",
                "",
                " us.zoom.xos "
            ]),
            ["com.microsoft.teams", "us.zoom.xos"]
        )
    }

    func testDenylistMatchesBundleIdentifiersCaseInsensitively() {
        XCTAssertTrue(
            AppDenylist.contains(
                bundleIdentifier: "com.apple.Keynote",
                entries: ["COM.APPLE.KEYNOTE"]
            )
        )
        XCTAssertFalse(
            AppDenylist.contains(
                bundleIdentifier: "com.apple.Safari",
                entries: ["com.apple.keynote"]
            )
        )
    }

    func testHealthAccessStatusExplainsActualCapability() {
        XCTAssertEqual(HealthAccessStatus.unavailable.displayName, "Unavailable on this device")
        XCTAssertEqual(HealthAccessStatus.notDetermined.displayName, "Not connected")
        XCTAssertEqual(HealthAccessStatus.authorized.displayName, "Connected")
        XCTAssertEqual(HealthAccessStatus.denied.displayName, "Access denied")
        XCTAssertFalse(HealthAccessStatus.denied.canWriteMindfulSessions)
        XCTAssertTrue(HealthAccessStatus.authorized.canWriteMindfulSessions)
    }
}
