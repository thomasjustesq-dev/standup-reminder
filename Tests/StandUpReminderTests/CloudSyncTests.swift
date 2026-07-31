import XCTest

@testable import StandUpReminder

/// `CloudSync.decodeStamped` decides whether bytes found in iCloud become the
/// user's live settings, and its failure mode is silent rather than loud:
/// `AppConfig` decodes "successfully" from any JSON object because every field
/// falls back to a default. A decode that is one notch too permissive therefore
/// replaces real settings with factory defaults instead of refusing the pull.
/// These tests pin that contract.
final class CloudSyncTests: XCTestCase {
    private let configMarkers = ["enabled", "intervalMinutes", "features"]

    private func defaultConfig() throws -> AppConfig {
        try JSONCoding.decoder().decode(AppConfig.self, from: Data("{}".utf8))
    }

    private func tempFile(_ json: String, modified: Date? = nil) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloudsync-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        if let modified {
            try FileManager.default.setAttributes(
                [.modificationDate: modified], ofItemAtPath: url.path)
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // MARK: envelope form (v4.2+)

    func testEnvelopeStampWinsOverFileModificationDate() throws {
        var config = try defaultConfig()
        config.intervalMinutes = 42
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try JSONCoding.encoder().encode(
            CloudEnvelope(updatedAt: stamp, deviceName: "unit-test", payload: config))
        // Deliberately ancient mtime: the envelope's own stamp must be used.
        let url = try tempFile(String(decoding: data, as: UTF8.self),
                               modified: Date(timeIntervalSince1970: 1))

        let result = CloudSync.decodeStamped(
            AppConfig.self, from: data, fileURL: url, bareMarkerKeys: configMarkers)

        let (decoded, date) = try XCTUnwrap(result)
        XCTAssertEqual(decoded.intervalMinutes, 42)
        XCTAssertEqual(date.timeIntervalSince1970, stamp.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: bare payload form (v4.1 and earlier)

    func testBarePayloadIsStampedWithFileModificationDate() throws {
        let mtime = Date(timeIntervalSince1970: 1_600_000_000)
        let json = #"{"enabled": true, "intervalMinutes": 37}"#
        let url = try tempFile(json, modified: mtime)

        let result = CloudSync.decodeStamped(
            AppConfig.self, from: Data(json.utf8), fileURL: url, bareMarkerKeys: configMarkers)

        let (decoded, date) = try XCTUnwrap(result)
        XCTAssertEqual(decoded.intervalMinutes, 37)
        XCTAssertEqual(date.timeIntervalSince1970, mtime.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: the no-wipe contract

    func testJSONObjectWithoutMarkerKeysIsRefused() throws {
        // This decodes cleanly into a fully-defaulted AppConfig. Accepting it
        // would overwrite the user's real settings with factory defaults, so
        // the marker-key gate must reject it outright.
        let json = #"{"someUnrelatedKey": 1}"#
        let url = try tempFile(json)

        let result = CloudSync.decodeStamped(
            AppConfig.self, from: Data(json.utf8), fileURL: url, bareMarkerKeys: configMarkers)

        XCTAssertNil(result, "a payload with no marker key must not be treated as config")
    }

    func testEmptyObjectIsRefused() throws {
        let json = "{}"
        let url = try tempFile(json)

        let result = CloudSync.decodeStamped(
            AppConfig.self, from: Data(json.utf8), fileURL: url, bareMarkerKeys: configMarkers)

        XCTAssertNil(result)
    }

    func testEnvelopeShapedButUndecodableIsRefusedRatherThanFallingBackToBare() throws {
        // Has both envelope keys, so the bare path must not be attempted — a
        // fallback here would silently downgrade a corrupt envelope to defaults.
        let json = #"{"payload": {"enabled": true}, "updatedAt": "not-a-date"}"#
        let url = try tempFile(json)

        let result = CloudSync.decodeStamped(
            AppConfig.self, from: Data(json.utf8), fileURL: url, bareMarkerKeys: configMarkers)

        XCTAssertNil(result)
    }

    func testNonObjectJSONIsRefused() throws {
        let json = "[1, 2, 3]"
        let url = try tempFile(json)

        let result = CloudSync.decodeStamped(
            AppConfig.self, from: Data(json.utf8), fileURL: url, bareMarkerKeys: configMarkers)

        XCTAssertNil(result)
    }

    func testGarbageBytesAreRefused() throws {
        let json = "not json at all"
        let url = try tempFile(json)

        let result = CloudSync.decodeStamped(
            AppConfig.self, from: Data(json.utf8), fileURL: url, bareMarkerKeys: configMarkers)

        XCTAssertNil(result)
    }

    // MARK: envelope round trip

    func testEnvelopeRoundTripsThroughTheSharedCoders() throws {
        var config = try defaultConfig()
        config.intervalMinutes = 55
        config.enabled = false
        let stamp = Date(timeIntervalSince1970: 1_650_000_000)

        let data = try JSONCoding.encoder().encode(
            CloudEnvelope(updatedAt: stamp, deviceName: "mac-mini", payload: config))
        let decoded = try JSONCoding.decoder().decode(CloudEnvelope<AppConfig>.self, from: data)

        XCTAssertEqual(decoded.deviceName, "mac-mini")
        XCTAssertEqual(decoded.payload.intervalMinutes, 55)
        XCTAssertFalse(decoded.payload.enabled)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970, stamp.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: outcome messaging

    func testEveryPullOutcomeHasANonEmptyUserMessage() throws {
        let config = try defaultConfig()
        let outcomes: [CloudSync.PullOutcome] = [
            .success(config: config, profiles: nil, remoteUpdatedAt: Date()),
            .unavailable,
            .empty,
            .downloading,
            .corrupt("config.json failed to decode"),
            .staleRemote(remote: Date(timeIntervalSince1970: 1), local: Date()),
        ]
        for outcome in outcomes {
            XCTAssertFalse(outcome.userMessage.isEmpty, "\(outcome) has no user message")
        }
    }
}
