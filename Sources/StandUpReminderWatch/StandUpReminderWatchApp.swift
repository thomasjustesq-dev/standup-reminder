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
        
        if action == "done" {
            WKInterfaceDevice.current().play(.success)
        } else if action == "snooze" {
            WKInterfaceDevice.current().play(.directionUp)
        } else {
            WKInterfaceDevice.current().play(.click)
        }
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
        guard let defaults = UserDefaults(suiteName: "group.com.thomasjust.standupreminder") else { return }
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

// MARK: - Aero-Kinetic Watch View
struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel

    private let volt = Color(red: 0.824, green: 1.000, blue: 0.227)
    private let slate = Color(red: 0.09, green: 0.10, blue: 0.13)
    private let vaporGray = Color.white.opacity(0.60)

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(volt)
                        .frame(width: 5, height: 5)
                    Text("STANDUP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(volt)
                }

                // Hero Circular Dial
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 6)
                        .frame(width: 110, height: 110)

                    let now = Date()
                    if let nextFire = model.nextFireAt, nextFire > now {
                        Circle()
                            .trim(from: 0.0, to: 0.75)
                            .stroke(
                                LinearGradient(colors: [volt.opacity(0.6), volt], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 110, height: 110)
                            .shadow(color: volt.opacity(0.4), radius: 6)
                        
                        VStack(spacing: 1) {
                            Text(timerInterval: now...nextFire, countsDown: true)
                                .font(.system(size: 20, weight: .bold, design: .default))
                                .monospacedDigit()
                                .foregroundStyle(Color.white)
                            Text("UNTIL BREAK")
                                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(vaporGray)
                        }
                    } else {
                        VStack(spacing: 1) {
                            Text("DONE")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(volt)
                            Text(model.status)
                                .font(.system(size: 8))
                                .foregroundStyle(vaporGray)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 2)

                // Action Buttons
                VStack(spacing: 6) {
                    Button {
                        model.send(action: "done")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Done Break")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(Color.black)
                        .background(volt)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        Button {
                            model.send(action: "snooze", minutes: 10)
                        } label: {
                            Text("Snooze")
                                .font(.system(size: 11, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .foregroundStyle(Color.white)
                                .background(slate)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.send(action: "skipToday")
                        } label: {
                            Text("Skip")
                                .font(.system(size: 11, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .foregroundStyle(vaporGray)
                                .background(slate)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
    }
}
#endif
