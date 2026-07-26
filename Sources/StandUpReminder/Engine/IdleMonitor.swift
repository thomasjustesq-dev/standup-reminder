import CoreGraphics
import Foundation

enum IdleMonitor {
    /// Seconds since any input event in the login session.
    static func secondsIdle() -> TimeInterval {
        let anyEvent = CGEventType(rawValue: ~UInt32(0))!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
    }

    static func isIdle(thresholdMinutes: Int) -> Bool {
        guard thresholdMinutes > 0 else { return false }
        return secondsIdle() >= TimeInterval(thresholdMinutes * 60)
    }
}
