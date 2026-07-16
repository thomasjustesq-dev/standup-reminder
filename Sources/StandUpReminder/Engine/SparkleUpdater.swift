import Foundation

/// Sparkle integration when the framework is linked; otherwise no-op with feed URL stored for packaging.
enum SparkleUpdater {
    static func start(feedURL: String, preferSparkle: Bool) {
        guard preferSparkle, let url = URL(string: feedURL), !feedURL.isEmpty else { return }
        #if canImport(Sparkle)
        // Linked via Xcode / vendored Sparkle.framework in distribution builds.
        AppLog.write("Sparkle feed configured: \(url.absoluteString)")
        // Actual SPUStandardUpdaterController wiring lives in AppDelegate when Sparkle is linked.
        NotificationCenter.default.post(name: .sparkleFeedConfigured, object: url)
        #else
        AppLog.write("Sparkle not linked — using GitHub update checker. Feed reserved: \(url.absoluteString)")
        #endif
    }
}

extension Notification.Name {
    static let sparkleFeedConfigured = Notification.Name("sparkleFeedConfigured")
}
