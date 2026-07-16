import Foundation
import Intents

enum FocusMonitor {
    /// Best-effort Focus / DND check. Returns false if status is unavailable.
    static func isFocused() -> Bool {
        if #available(macOS 12.0, *) {
            return INFocusStatusCenter.default.focusStatus.isFocused == true
        }
        return false
    }

    static func requestAuthorizationIfNeeded() {
        if #available(macOS 12.0, *) {
            INFocusStatusCenter.default.requestAuthorization { status in
                AppLog.write("Focus authorization: \(status.rawValue)")
            }
        }
    }
}
