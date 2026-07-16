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

    static func deliver(_ payload: ReminderPayload) {
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
                if response.actionIdentifier == NotificationAction.guided.rawValue {
                    let steps = info["guidedSteps"] as? [String] ?? ["Stand up", "Move", "Reset"]
                    let payload = ReminderPayload(
                        kind: ReminderKind(rawValue: info["kind"] as? String ?? "") ?? .breakPrompt,
                        title: response.notification.request.content.title,
                        body: response.notification.request.content.body,
                        promptId: info["promptId"] as? String ?? "",
                        guidedSteps: steps
                    )
                    self.onGuided?(payload)
                }
            default:
                break
            }
        }
        completionHandler()
    }
}
