import Foundation

enum ReminderKind: String {
    case lunch
    case breakPrompt
}

struct ReminderPayload: Equatable {
    var kind: ReminderKind
    var title: String
    var body: String
    var promptId: String
}

enum ReminderContent {
    private static var promptCursor = 0

    static func next(config: AppConfig, at date: Date = Date()) -> ReminderPayload {
        if config.isLunchTime(at: date) {
            return ReminderPayload(
                kind: .lunch,
                title: config.lunch.title,
                body: config.lunch.body,
                promptId: "lunch"
            )
        }

        let prompts = config.prompts.isEmpty ? BreakPrompt.defaults : config.prompts
        let index = promptCursor % prompts.count
        promptCursor += 1
        let prompt = prompts[index]
        return ReminderPayload(
            kind: .breakPrompt,
            title: prompt.title,
            body: prompt.body,
            promptId: prompt.id
        )
    }

    static func resetCursor() {
        promptCursor = 0
    }
}
