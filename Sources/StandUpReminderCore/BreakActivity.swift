#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Live Activity contract shared by the iOS app (which starts/updates the
/// activity) and the widget extension (which renders it).
struct BreakActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var nextFireAt: Date
        var title: String
    }

    var profileName: String
}
#endif
