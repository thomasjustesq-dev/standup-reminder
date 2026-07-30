import Foundation

/// Pure, side-effect-free debug helpers that operate on StandUpReminderCore
/// value types. All functions are safe to call from unit tests and from the
/// four debug CLI sub-commands (`debug-trace`, `debug-snapshot`,
/// `debug-check`, `debug-config`).
enum DebugCommands {

    // MARK: - Rule evaluation trace

    /// Human-readable trace of which scheduling rules are active and the
    /// winning next-fire candidate for the given input.
    static func ruleTrace(input: Scheduler.Input) -> String {
        let fmt = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("=== Rule Evaluation Trace ===")
        lines.append("timestamp : \(fmt.string(from: input.now))")
        lines.append("paused    : \(input.paused)")
        lines.append("interval  : \(input.intervalMinutes) min")
        let anchor = Scheduler.cadenceAnchor(
            lastReminderAt: input.lastReminderAt,
            lastAcknowledgedAt: input.lastAcknowledgedAt
        )
        lines.append("anchor    : \(anchor.map(fmt.string) ?? "none")")

        lines.append("")
        lines.append("--- Enabled rules ---")
        lines.append("breakPrompt : \(input.config.enabled)")
        lines.append("sitStand    : \(input.config.sitStandModeEnabled)")
        lines.append("lunch       : \(input.config.lunch.enabled)")
        lines.append("windDown    : \(input.config.windDown.enabled)")

        lines.append("")
        lines.append("--- Work hours ---")
        lines.append("withinWorkHours(now) : \(input.config.isWithinWorkHours(at: input.now))")

        lines.append("")
        lines.append("--- Result ---")
        if let next = Scheduler.next(input) {
            lines.append("next : \(next.kind.rawValue) @ \(fmt.string(from: next.date))")
        } else {
            lines.append("next : none (paused or no eligible window)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Notification schedule snapshot

    struct ScheduleEntry: Codable {
        let index: Int
        let kind: String
        let isoDate: String
    }

    /// JSON array of the next `count` scheduled reminders, simulated forward
    /// with no user interaction. Output is stable: identical inputs produce
    /// identical JSON.
    static func scheduleSnapshot(input: Scheduler.Input, count: Int = 10) -> String {
        let fmt = ISO8601DateFormatter()
        let entries = Scheduler.upcoming(input, count: count).enumerated().map { i, next in
            ScheduleEntry(index: i + 1, kind: next.kind.rawValue, isoDate: fmt.string(from: next.date))
        }
        guard let data = try? JSONCoding.encoder().encode(entries),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    // MARK: - Determinism check

    /// Evaluate the schedule twice with identical input and confirm the
    /// outputs are bit-for-bit equal. Returns a human-readable report.
    static func determinismCheck(input: Scheduler.Input) -> String {
        let first = scheduleSnapshot(input: input)
        let second = scheduleSnapshot(input: input)
        let pass = (first == second)
        var lines: [String] = []
        lines.append("=== Determinism Check ===")
        lines.append("result : \(pass ? "PASS ✓" : "FAIL ✗")")
        if !pass {
            lines.append("--- first ---")
            lines.append(first)
            lines.append("--- second ---")
            lines.append(second)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Config state report

    /// Full JSON serialization of the active AppConfig — useful for
    /// capturing an exact snapshot of the settings in effect.
    static func configReport(config: AppConfig) -> String {
        guard let data = try? JSONCoding.encoder().encode(config),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }
}
