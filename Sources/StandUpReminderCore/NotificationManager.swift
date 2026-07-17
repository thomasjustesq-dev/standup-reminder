import Foundation
import UserNotifications

enum NotificationAction: String {
    case done = "DONE_ACTION"
    case snooze = "SNOOZE_ACTION"
    case skipToday = "SKIP_TODAY_ACTION"
    case guided = "GUIDED_ACTION"
}

enum NotificationManager {
    static let categoryId = "STANDUP_REMINDER"
    static let requestIdPrefix = "standup-"

    static func configure() {
        let done = UNNotificationAction(identifier: NotificationAction.done.rawValue, title: "Done", options: [])
        let snooze = UNNotificationAction(identifier: NotificationAction.snooze.rawValue, title: "Snooze 10m", options: [])
        let guided = UNNotificationAction(identifier: NotificationAction.guided.rawValue, title: "Guided break", options: [.foreground])
        let skip = UNNotificationAction(identifier: NotificationAction.skipToday.rawValue, title: "Skip today", options: [.destructive])
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [done, guided, snooze, skip],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { AppLog.write("Notification auth error: \(error.localizedDescription)") }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Stale banners from earlier breaks are noise once a new one lands;
    /// clear this app's previously delivered immediate reminders (never the
    /// iOS pre-scheduled queue — its delivered entries feed stats reconcile).
    static func clearStaleDelivered() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            let stale = delivered.map(\.request.identifier)
                .filter { $0.hasPrefix(requestIdPrefix) && !$0.hasPrefix(queuedIdPrefix) }
            if !stale.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: stale)
            }
        }
    }

    static func deliver(_ payload: ReminderPayload) {
        clearStaleDelivered()
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        // Sound is played by the app via NSSound (honoring the configured
        // sound name); a notification sound here would double it up.
        content.sound = nil
        content.categoryIdentifier = categoryId
        content.userInfo = [
            "kind": payload.kind.rawValue,
            "promptId": payload.promptId,
            "guidedSteps": payload.guidedSteps
        ]
        content.interruptionLevel = .timeSensitive

        let id = requestIdPrefix + UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLog.write("Failed to deliver notification: \(error.localizedDescription)")
            } else {
                AppLog.write("notified (\(payload.kind.rawValue)): \(payload.body)")
            }
        }
    }

    /// Pre-schedule a reminder for a future date (iOS: the app cannot tick in
    /// the background, so upcoming reminders are queued as local notifications).
    static func schedule(_ payload: ReminderPayload, at date: Date, calendar: Calendar, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.categoryIdentifier = categoryId
        content.userInfo = [
            "kind": payload.kind.rawValue,
            "promptId": payload.promptId,
            "guidedSteps": payload.guidedSteps
        ]
        content.interruptionLevel = .timeSensitive

        // A calendar trigger for a past date never fires — and the scheduler
        // deliberately keeps overdue entries (an expired snooze or a resumed
        // pause is due *now*). Deliver those after a short interval instead
        // of silently dropping them.
        let trigger: UNNotificationTrigger
        if date.timeIntervalSinceNow <= 1 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        } else {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLog.write("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    /// Identifier prefix for the pre-scheduled queue. Each rebuild uses a
    /// fresh generation stamp in the identifier so a delivered slot is never
    /// confused with a later rebuild reusing the same slot number.
    static let queuedIdPrefix = requestIdPrefix + "queued-"

    static func queuedIdentifier(generation: Int, slot: String) -> String {
        "\(queuedIdPrefix)\(generation)-\(slot)"
    }

    /// Remove every pending local notification. The queue is the only thing
    /// this app schedules, so a full clear is the race-free way to cancel a
    /// generation whose identifiers embed a stamp.
    static func cancelScheduledQueue() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onDone: (() -> Void)?
    var onSnooze: (() -> Void)?
    var onSkipToday: (() -> Void)?
    var onGuided: ((ReminderPayload) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        DispatchQueue.main.async {
            switch response.actionIdentifier {
            case NotificationAction.done.rawValue:
                self.onDone?()
            case NotificationAction.snooze.rawValue:
                self.onSnooze?()
            case NotificationAction.skipToday.rawValue:
                self.onSkipToday?()
            case NotificationAction.guided.rawValue, UNNotificationDefaultActionIdentifier:
                // Clicking the banner body was a no-op; route it to the same
                // guided-break flow as the explicit button.
                let steps = info["guidedSteps"] as? [String] ?? ["Stand up", "Move", "Reset"]
                let payload = ReminderPayload(
                    kind: ReminderKind(rawValue: info["kind"] as? String ?? "") ?? .breakPrompt,
                    title: response.notification.request.content.title,
                    body: response.notification.request.content.body,
                    promptId: info["promptId"] as? String ?? "",
                    guidedSteps: steps
                )
                self.onGuided?(payload)
            default:
                break
            }
        }
        completionHandler()
    }
}
