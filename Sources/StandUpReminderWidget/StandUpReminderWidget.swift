#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

/// Notification Center / desktop widget.
/// Embed this target with XcodeGen (`project.yml`) or Xcode, using App Group
/// `group.com.thomasjust.standupreminder` or the shared `widget.json` snapshot.

struct StandUpWidgetEntry: TimelineEntry {
    let date: Date
    let status: String
    let nextText: String
    let nextFireAt: Date?
    let weekDone: Int
    let countdown: Int?
    let profileName: String
}

struct StandUpWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StandUpWidgetEntry {
        StandUpWidgetEntry(date: Date(), status: "Armed", nextText: "Next break soon", nextFireAt: Date().addingTimeInterval(12 * 60), weekDone: 3, countdown: 12, profileName: "Office Mac")
    }

    func getSnapshot(in context: Context, completion: @escaping (StandUpWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StandUpWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh at the fire time (the countdown hits zero there) or in
        // 15 minutes, whichever is sooner.
        var refreshAt = Date().addingTimeInterval(15 * 60)
        if let next = entry.nextFireAt, next > Date(), next < refreshAt {
            refreshAt = next.addingTimeInterval(30)
        }
        completion(Timeline(entries: [entry], policy: .after(refreshAt)))
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
            nextFireAt: snap?.nextFireAt,
            weekDone: snap?.weekDone ?? 0,
            countdown: snap?.countdownMinutes,
            profileName: snap?.profileName ?? "Default"
        )
    }

    private func loadSnapshot() -> WidgetSnapshotDTO? {
        if let data = UserDefaults(suiteName: AppIdentity.appGroupID)?.data(forKey: "widgetSnapshot"),
           let snap = try? decodeSnapshot(data) {
            return snap
        }
        #if os(macOS)
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/StandUpReminder/widget.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decodeSnapshot(data)
        #else
        return nil
        #endif
    }

    private func decodeSnapshot(_ data: Data) throws -> WidgetSnapshotDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WidgetSnapshotDTO.self, from: data)
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
    @Environment(\.widgetFamily) private var family
    var entry: StandUpWidgetEntry

    /// Live countdown when the fire time is known and in the future;
    /// otherwise the static text.
    @ViewBuilder
    private var countdownText: some View {
        if let next = entry.nextFireAt, next > entry.date {
            Text(timerInterval: entry.date...next, countsDown: true)
                .monospacedDigit()
        } else if let countdown = entry.countdown {
            Text("\(countdown)m")
        } else {
            Text("—")
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "figure.stand")
                countdownText
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
        case .accessoryInline:
            HStack {
                Image(systemName: "figure.stand")
                countdownText
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.stand")
                    Text("Next break")
                        .font(.headline)
                }
                countdownText
                    .font(.title3.weight(.semibold))
                Text("\(entry.weekDone) done this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("Stand Up")
                    .font(.headline)
                countdownText
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text(entry.nextText)
                    .font(.caption)
                Text("\(entry.weekDone) done this week · \(entry.profileName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

@main
struct StandUpReminderWidgetBundle: WidgetBundle {
    var body: some Widget {
        StandUpReminderWidget()
        #if os(iOS)
        BreakLiveActivityWidget()
        #endif
    }
}

struct StandUpReminderWidget: Widget {
    let kind = "StandUpReminderWidget"

    private var families: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #elseif os(watchOS)
        return [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        return [.systemSmall, .systemMedium]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StandUpWidgetProvider()) { entry in
            if #available(iOS 17.0, macOS 14.0, watchOS 10.0, *) {
                StandUpReminderWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                StandUpReminderWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Stand Up Reminder")
        .description("Next break countdown and weekly done count.")
        .supportedFamilies(families)
    }
}

#if os(iOS)
/// Lock Screen / Dynamic Island countdown to the next break. The countdown
/// renders natively from the date interval, so it stays live without pushes;
/// the app refreshes the state whenever it rebuilds the queue.
struct BreakLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreakActivityAttributes.self) { context in
            // One clock read per builder: a second Date() past nextFireAt
            // would build an invalid range and crash.
            let now = Date()
            HStack {
                Image(systemName: "figure.stand")
                VStack(alignment: .leading) {
                    Text(context.state.title)
                        .font(.headline)
                    if context.state.nextFireAt > now {
                        Text(timerInterval: now...context.state.nextFireAt, countsDown: true)
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                    } else {
                        Text("Break time")
                            .font(.title3.weight(.semibold))
                    }
                }
                Spacer()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.stand")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let now = Date()
                    if context.state.nextFireAt > now {
                        Text(timerInterval: now...context.state.nextFireAt, countsDown: true)
                            .monospacedDigit()
                            .frame(maxWidth: 60)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.stand")
            } compactTrailing: {
                let now = Date()
                if context.state.nextFireAt > now {
                    Text(timerInterval: now...context.state.nextFireAt, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Image(systemName: "figure.stand")
            }
        }
    }
}
#endif
#endif
