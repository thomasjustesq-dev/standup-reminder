import Foundation

enum ReminderKind: String {
    case lunch
    case windDown
    case sitStand
    case breakPrompt
    case meetingCatchUp
}

struct ReminderPayload: Equatable {
    var kind: ReminderKind
    var title: String
    var body: String
    var promptId: String
    var guidedSteps: [String]
}

enum ReminderContent {
    static func sitStandPayload(phase: DeskPhase) -> ReminderPayload {
        switch phase {
        case .stand:
            return ReminderPayload(
                kind: .sitStand,
                title: "Stand Desk",
                body: "Switch to standing for a while — open your hips and move.",
                promptId: "desk-stand",
                guidedSteps: ["Raise your desk", "Stand tall", "Soft knees", "Move every few minutes"]
            )
        case .sit:
            return ReminderPayload(
                kind: .sitStand,
                title: "Sit Desk",
                body: "Time to sit for a stretch — keep posture easy and neutral.",
                promptId: "desk-sit",
                guidedSteps: ["Lower your desk", "Sit with feet flat", "Relax shoulders", "Uncross legs"]
            )
        }
    }

    static func windDown(config: AppConfig) -> ReminderPayload {
        ReminderPayload(
            kind: .windDown,
            title: config.windDown.title,
            body: config.windDown.body,
            promptId: "wind-down",
            guidedSteps: ["Stand and stretch", "Close leftover tabs", "Note tomorrow’s top task", "Log off when ready"]
        )
    }

    static func meetingCatchUp() -> ReminderPayload {
        ReminderPayload(
            kind: .meetingCatchUp,
            title: "Break Catch-up",
            body: "Your meeting ended — take a quick stand/move break now.",
            promptId: "meeting-catchup",
            guidedSteps: ["Stand up", "Walk 60 seconds", "Drink water", "Reset posture"]
        )
    }
}
