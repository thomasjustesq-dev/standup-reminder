#if os(iOS)
import Foundation
import WatchConnectivity

/// iPhone side of the Apple Watch companion. The Watch can only pair with an
/// iPhone (there is no Mac↔Watch channel), so this bridge is the Watch's
/// source of truth; the Mac participates via iCloud sync instead.
@MainActor
final class PhoneWatchBridge: NSObject, ObservableObject {
    static let shared = PhoneWatchBridge()

    @Published var isWatchReachable = false

    private var activated = false

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        if !activated {
            WCSession.default.activate()
            activated = true
        }
    }

    func pushStatus() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let model = PhoneModel.shared
        var payload: [String: Any] = ["status": model.statusText]
        payload["weekDone"] = model.stats.weekSummary().done
        if let next = model.nextFireAt {
            payload["nextFire"] = next.timeIntervalSince1970
            payload["countdown"] = max(0, Int(next.timeIntervalSinceNow / 60))
        }
        try? WCSession.default.updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    private func handle(_ message: [String: Any]) {
        let model = PhoneModel.shared
        switch message["action"] as? String ?? "" {
        case "done":
            model.acknowledgeDone()
        case "snooze":
            model.snooze(minutes: message["minutes"] as? Int ?? 10)
        case "skipToday":
            model.skipToday()
        default:
            break
        }
        pushStatus()
    }
}

extension PhoneWatchBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error { AppLog.write("Watch activation error: \(error.localizedDescription)") }
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            self.pushStatus()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            self.pushStatus()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.handle(message) }
    }

    /// The Watch falls back to transferUserInfo when the phone is unreachable.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.handle(userInfo) }
    }
}
#endif
