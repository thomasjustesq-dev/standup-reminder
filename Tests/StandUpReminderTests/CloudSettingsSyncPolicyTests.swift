import XCTest
@testable import StandUpReminder

final class CloudSettingsSyncPolicyTests: XCTestCase {
    private let older = Date(timeIntervalSince1970: 1_000)
    private let newer = Date(timeIntervalSince1970: 2_000)

    func testRemoteSettingsWinWhenRemoteStampIsNewer() {
        var local = AppConfig.default
        local.intervalMinutes = 30
        var remote = local
        remote.intervalMinutes = 45

        let action = CloudSettingsSyncPolicy.decide(
            localConfig: local,
            localProfiles: ProfileDocument.default,
            localModifiedAt: older,
            remoteConfig: remote,
            remoteProfiles: ProfileDocument.default,
            remoteUpdatedAt: newer,
            isFreshInstall: false
        )

        XCTAssertEqual(action, .applyRemote)
    }

    func testLocalSettingsPushWhenLocalStampIsNewer() {
        var local = AppConfig.default
        local.intervalMinutes = 20
        var remote = local
        remote.intervalMinutes = 60

        let action = CloudSettingsSyncPolicy.decide(
            localConfig: local,
            localProfiles: ProfileDocument.default,
            localModifiedAt: newer,
            remoteConfig: remote,
            remoteProfiles: ProfileDocument.default,
            remoteUpdatedAt: older,
            isFreshInstall: false
        )

        XCTAssertEqual(action, .pushLocal)
    }

    func testEqualPayloadDoesNotPingPongWhenLocalFileStampIsNewer() {
        let config = AppConfig.default
        let profiles = ProfileDocument.default

        let action = CloudSettingsSyncPolicy.decide(
            localConfig: config,
            localProfiles: profiles,
            localModifiedAt: newer,
            remoteConfig: config,
            remoteProfiles: profiles,
            remoteUpdatedAt: older,
            isFreshInstall: false
        )

        XCTAssertEqual(action, .unchanged)
    }

    func testFreshInstallPullsExistingRemoteSettingsRegardlessOfLocalFileStamp() {
        var remote = AppConfig.default
        remote.intervalMinutes = 55

        let action = CloudSettingsSyncPolicy.decide(
            localConfig: AppConfig.default,
            localProfiles: ProfileDocument.default,
            localModifiedAt: newer,
            remoteConfig: remote,
            remoteProfiles: ProfileDocument.default,
            remoteUpdatedAt: older,
            isFreshInstall: true
        )

        XCTAssertEqual(action, .applyRemote)
    }

    func testMissingRemoteProfilesAreSeededFromLocalDevice() {
        let action = CloudSettingsSyncPolicy.decide(
            localConfig: AppConfig.default,
            localProfiles: ProfileDocument.default,
            localModifiedAt: newer,
            remoteConfig: AppConfig.default,
            remoteProfiles: nil,
            remoteUpdatedAt: older,
            isFreshInstall: false
        )

        XCTAssertEqual(action, .pushLocal)
    }
}
