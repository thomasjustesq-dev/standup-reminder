import Combine
import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

#if !canImport(WatchConnectivity)
/// WatchConnectivity is an iOS/watchOS framework and does not exist in the macOS SDK.
/// The Watch companion only functions when built as part of the iOS/watchOS targets
/// (see project.yml); this stub keeps the Mac app compiling with the same API.
@MainActor
final class WatchBridge: ObservableObject {
    static let shared = WatchBridge()

    @Published var isWatchReachable = false
    @Published var lastWatchEvent: String = "—"

    func start(enabled: Bool) {
        if enabled { AppLog.write("Watch companion unavailable on macOS (no WatchConnectivity)") }
    }

    func sendStatus(status: String, nextFire: Date?, countdownMinutes: Int?) {}
    func notifyReminder(title: String, body: String) {}
}
#else

/// Mac side of the Apple Watch companion (Done / snooze / status).
@MainActor
final class WatchBridge: NSObject, ObservableObject {
    static let shared = WatchBridge()

    @Published var isWatchReachable = false
    @Published var lastWatchEvent: String = "—"

    private var activated = false

    func start(enabled: Bool) {
        guard enabled else { return }
        guard WCSession.isSupported() else {
            AppLog.write("WatchConnectivity unsupported on this Mac")
            return
        }
        let session = WCSession.default
        session.delegate = self
        if !activated {
            session.activate()
            activated = true
        }
    }

    func sendStatus(status: String, nextFire: Date?, countdownMinutes: Int?) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        var payload: [String: Any] = ["status": status]
        if let nextFire { payload["nextFire"] = nextFire.timeIntervalSince1970 }
        if let countdownMinutes { payload["countdown"] = countdownMinutes }
        try? WCSession.default.updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    func notifyReminder(title: String, body: String) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let payload: [String: Any] = [
            "event": "reminder",
            "title": title,
            "body": body,
            "haptic": true
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error { AppLog.write("Watch activation error: \(error.localizedDescription)") }
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            let action = message["action"] as? String ?? ""
            self.lastWatchEvent = action
            switch action {
            case "done":
                AppState.shared.acknowledgeDone()
            case "snooze":
                let minutes = message["minutes"] as? Int ?? 10
                AppState.shared.snooze(minutes: minutes)
            case "skipToday":
                AppState.shared.skipToday()
            default:
                break
            }
            AppLog.write("Watch action: \(action)")
        }
    }
}

#endif
