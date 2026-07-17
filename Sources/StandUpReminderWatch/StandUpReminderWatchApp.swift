#if os(watchOS)
import SwiftUI
import WatchConnectivity
import WatchKit
import WidgetKit

@main
struct StandUpReminderWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(model)
        }
    }
}

@MainActor
final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
    // The Watch pairs with the iPhone, never the Mac.
    @Published var status = "Waiting for iPhone…"
    @Published var nextFireAt: Date?
    @Published var lastTitle = "Stand Up"

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func send(action: String, minutes: Int? = nil) {
        var payload: [String: Any] = ["action": action]
        if let minutes { payload["minutes"] = minutes }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(payload)
        }
        WKInterfaceDevice.current().play(.click)
    }

    private var weekDone = 0

    private func apply(_ payload: [String: Any]) {
        if let status = payload["status"] as? String { self.status = status }
        if let done = payload["weekDone"] as? Int { self.weekDone = done }
        if let epoch = payload["nextFire"] as? TimeInterval {
            self.nextFireAt = Date(timeIntervalSince1970: epoch)
        } else if payload["status"] != nil {
            self.nextFireAt = nil
        }
        publishComplicationSnapshot()
    }

    /// The complication runs in its own extension and can't reach
    /// WatchConnectivity; hand it the latest state via the app group.
    private func publishComplicationSnapshot() {
        guard let defaults = UserDefaults(suiteName: "group.com.user.StandUpReminder") else { return }
        let iso = ISO8601DateFormatter()
        var snapshot: [String: Any] = [
            "statusMessage": status,
            "weekDone": weekDone,
            "weekShown": 0,
            "profileName": "Watch",
            "updatedAt": iso.string(from: Date())
        ]
        if let nextFireAt {
            snapshot["nextFireAt"] = iso.string(from: nextFireAt)
            snapshot["countdownMinutes"] = max(0, Int(nextFireAt.timeIntervalSinceNow / 60))
        }
        if let data = try? JSONSerialization.data(withJSONObject: snapshot) {
            defaults.set(data, forKey: "widgetSnapshot")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // The phone's last context is available immediately on activation —
        // without reading it the UI sat on its placeholder until the next push.
        let context = session.receivedApplicationContext
        Task { @MainActor in
            if !context.isEmpty { self.apply(context) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.apply(message)
            if message["event"] as? String == "reminder" {
                self.lastTitle = message["title"] as? String ?? "Break"
                self.status = message["body"] as? String ?? self.status
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.apply(applicationContext)
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(model.lastTitle).font(.headline)
                // A live timer interval, not a static minute count that froze
                // at whatever the phone last pushed.
                if let nextFire = model.nextFireAt, nextFire > Date() {
                    Text(timerInterval: Date()...nextFire, countsDown: true)
                        .font(.largeTitle.monospacedDigit())
                        .multilineTextAlignment(.center)
                }
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Done") { model.send(action: "done") }
                Button("Snooze 10m") { model.send(action: "snooze", minutes: 10) }
                Button("Skip today") { model.send(action: "skipToday") }
            }
            .padding()
        }
    }
}
#endif
