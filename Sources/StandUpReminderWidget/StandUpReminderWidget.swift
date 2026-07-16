#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

/// Notification Center / desktop widget.
/// Embed this target with XcodeGen (`project.yml`) or Xcode, using App Group
/// `group.com.user.StandUpReminder` or the shared `widget.json` snapshot.

struct StandUpWidgetEntry: TimelineEntry {
    let date: Date
    let status: String
    let nextText: String
    let weekDone: Int
    let countdown: Int?
    let profileName: String
}

struct StandUpWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StandUpWidgetEntry {
        StandUpWidgetEntry(date: Date(), status: "Armed", nextText: "Next break soon", weekDone: 3, countdown: 12, profileName: "Office Mac")
    }

    func getSnapshot(in context: Context, completion: @escaping (StandUpWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StandUpWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> StandUpWidgetEntry {
        let snap = loadSnapshot()
        let nextText: String = {
            guard let next = snap?.nextFireAt else { return "No upcoming reminder" }
            let f = DateFormatter()
            f.timeStyle = .short
            return "Next \(f.string(from: next))"
        }()
        return StandUpWidgetEntry(
            date: Date(),
            status: snap?.statusMessage ?? "Stand Up Reminder",
            nextText: nextText,
            weekDone: snap?.weekDone ?? 0,
            countdown: snap?.countdownMinutes,
            profileName: snap?.profileName ?? "Default"
        )
    }

    private func loadSnapshot() -> WidgetSnapshotDTO? {
        if let data = UserDefaults(suiteName: "group.com.user.StandUpReminder")?.data(forKey: "widgetSnapshot"),
           let snap = try? JSONDecoder().decode(WidgetSnapshotDTO.self, from: data) {
            return snap
        }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/StandUpReminder/widget.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshotDTO.self, from: data)
    }
}

struct WidgetSnapshotDTO: Codable {
    var nextFireAt: Date?
    var statusMessage: String
    var weekDone: Int
    var weekShown: Int
    var deskPhase: String?
    var countdownMinutes: Int?
    var profileName: String
    var updatedAt: Date
}

struct StandUpReminderWidgetView: View {
    var entry: StandUpWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stand Up")
                .font(.headline)
            if let countdown = entry.countdown {
                Text("\(countdown)m")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
            }
            Text(entry.nextText)
                .font(.caption)
            Text("\(entry.weekDone) done this week · \(entry.profileName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

@main
struct StandUpReminderWidgetBundle: WidgetBundle {
    var body: some Widget {
        StandUpReminderWidget()
    }
}

struct StandUpReminderWidget: Widget {
    let kind = "StandUpReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StandUpWidgetProvider()) { entry in
            StandUpReminderWidgetView(entry: entry)
        }
        .configurationDisplayName("Stand Up Reminder")
        .description("Next break countdown and weekly done count.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#endif
