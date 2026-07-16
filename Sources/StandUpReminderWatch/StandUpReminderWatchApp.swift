#if os(watchOS)
import SwiftUI
import WatchConnectivity
import WatchKit

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
    @Published var status = "Waiting for Mac…"
    @Published var countdown: Int?
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

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let status = message["status"] as? String { self.status = status }
            if let countdown = message["countdown"] as? Int { self.countdown = countdown }
            if message["event"] as? String == "reminder" {
                self.lastTitle = message["title"] as? String ?? "Break"
                self.status = message["body"] as? String ?? self.status
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let status = applicationContext["status"] as? String { self.status = status }
            if let countdown = applicationContext["countdown"] as? Int { self.countdown = countdown }
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(model.lastTitle).font(.headline)
                if let countdown = model.countdown {
                    Text("\(countdown)m").font(.largeTitle.monospacedDigit())
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
