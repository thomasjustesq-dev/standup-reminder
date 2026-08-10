import Foundation

/// Pure diagnostics bundle for CLI `diagnostics` / support paste.
/// Callers fill platform-specific fields; no AppKit/UIKit.
enum DiagnosticsDump {
    struct Input: Equatable {
        var marketingVersion: String
        var build: String
        var bundleId: String
        var appGroup: String
        var iCloudContainer: String
        var configPath: String
        var supportDir: String
        var presence: String
        var cadenceRole: String
        var isAuthority: Bool
        var enabled: Bool
        var paused: Bool
        var intervalMinutes: Int
        var baseIntervalMinutes: Int
        var statusMessage: String
        var nextFireDescription: String
        var notificationsAuthorized: String
        var iCloudEnabled: Bool
        var syncSummary: String
        var syncDoctorBody: String
        var authorityLeaseLine: String
        var blockStatsReport: String
        var evidenceLine: String
        var weekStatsLine: String
        var corruptArtifacts: [String]
    }

    static func render(_ input: Input) -> String {
        var lines: [String] = []
        lines.append("=== Stand Up Reminder diagnostics ===")
        lines.append("version: \(input.marketingVersion) (\(input.build))")
        lines.append("bundle: \(input.bundleId)")
        lines.append("app group: \(input.appGroup)")
        lines.append("iCloud: \(input.iCloudContainer)")
        lines.append("support: \(input.supportDir)")
        lines.append("config: \(input.configPath)")
        lines.append("--- state ---")
        lines.append("presence: \(input.presence)")
        lines.append("cadence: \(input.cadenceRole)\(input.isAuthority ? " (authority)" : " (follower)")")
        lines.append("enabled: \(input.enabled)  paused: \(input.paused)")
        lines.append("interval: \(input.intervalMinutes)m (base \(input.baseIntervalMinutes))")
        lines.append("status: \(input.statusMessage)")
        lines.append("next: \(input.nextFireDescription)")
        lines.append("notifications: \(input.notificationsAuthorized)")
        lines.append("authority lease: \(input.authorityLeaseLine)")
        lines.append("--- sync ---")
        lines.append("iCloud config flag: \(input.iCloudEnabled)")
        lines.append(input.syncSummary)
        lines.append(input.syncDoctorBody)
        lines.append("--- blocks ---")
        lines.append(input.blockStatsReport)
        lines.append("--- evidence / week ---")
        lines.append(input.evidenceLine)
        lines.append(input.weekStatsLine)
        if !input.corruptArtifacts.isEmpty {
            lines.append("--- corrupt artifacts ---")
            lines.append(contentsOf: input.corruptArtifacts)
        }
        lines.append("=== end ===")
        return lines.joined(separator: "\n")
    }

    /// List `*.corrupt` siblings next to config/profiles under Application Support.
    static func corruptArtifacts(in supportDir: URL) -> [String] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: supportDir, includingPropertiesForKeys: nil
        ) else { return [] }
        return entries
            .map(\.lastPathComponent)
            .filter { $0.hasSuffix(".corrupt") }
            .sorted()
    }
}
