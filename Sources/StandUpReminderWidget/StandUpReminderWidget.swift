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
        let base = loadEntry()
        let now = Date()
        // Minute-resolution entries keep Lock Screen countdown honest while
        // armed; fall back to a single entry when nothing is scheduled.
        var entries: [StandUpWidgetEntry] = []
        if let next = base.nextFireAt, next > now {
            var t = now
            let cap = min(60, Int(ceil(next.timeIntervalSince(now) / 60)) + 1)
            for _ in 0..<cap {
                entries.append(entry(at: t, template: base))
                t = t.addingTimeInterval(60)
                if t > next { break }
            }
            entries.append(entry(at: next, template: base))
            completion(Timeline(entries: entries, policy: .after(next.addingTimeInterval(30))))
        } else {
            completion(Timeline(entries: [base], policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }

    private func entry(at date: Date, template: StandUpWidgetEntry) -> StandUpWidgetEntry {
        let countdown: Int? = {
            guard let next = template.nextFireAt else { return nil }
            return max(0, Int(ceil(next.timeIntervalSince(date) / 60)))
        }()
        return StandUpWidgetEntry(
            date: date,
            status: template.status,
            nextText: template.nextText,
            nextFireAt: template.nextFireAt,
            weekDone: template.weekDone,
            countdown: countdown,
            profileName: template.profileName
        )
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

// MARK: - Aero-Kinetic Widget Styling Tokens
private enum AeroWidgetColor {
    static let volt = Color(red: 0.824, green: 1.000, blue: 0.227)
    static let ionBlue = Color(red: 0.039, green: 0.518, blue: 1.000)
    static let titaniumWhite = Color.white
    static let vaporGray = Color.white.opacity(0.60)
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
                .monospacedDigit()
        } else {
            Text("—")
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AeroWidgetColor.volt)
                    countdownText
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                }
            }
        case .accessoryInline:
            HStack(spacing: 4) {
                Image(systemName: "figure.stand")
                countdownText
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.stand")
                        .foregroundStyle(AeroWidgetColor.volt)
                    Text("STANDUP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AeroWidgetColor.volt)
                }
                countdownText
                    .font(.system(size: 20, weight: .bold))
                Text("\(entry.weekDone) done this week")
                    .font(.system(size: 9.5))
                    .foregroundStyle(AeroWidgetColor.vaporGray)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "figure.stand")
                        .foregroundStyle(AeroWidgetColor.volt)
                    Text("STANDUP")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AeroWidgetColor.vaporGray)
                    Spacer()
                    Text(entry.profileName.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AeroWidgetColor.vaporGray.opacity(0.8))
                }
                
                Spacer()
                
                countdownText
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(AeroWidgetColor.volt)
                    .shadow(color: AeroWidgetColor.volt.opacity(0.3), radius: 8, x: 0, y: 0)
                
                Text(entry.nextText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AeroWidgetColor.titaniumWhite)
                
                HStack {
                    Text("\(entry.weekDone) completed this week")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AeroWidgetColor.vaporGray)
                }
            }
            .padding(14)
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
                    .containerBackground(Color(red: 0.07, green: 0.08, blue: 0.10), for: .widget)
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
            let now = Date()
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AeroWidgetColor.volt.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "figure.stand")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AeroWidgetColor.volt)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AeroWidgetColor.vaporGray)
                    
                    if context.state.nextFireAt > now {
                        Text(timerInterval: now...context.state.nextFireAt, countsDown: true)
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(AeroWidgetColor.titaniumWhite)
                    } else {
                        Text("Break time")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AeroWidgetColor.volt)
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(Color(red: 0.05, green: 0.06, blue: 0.08))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.stand")
                        .font(.title2)
                        .foregroundStyle(AeroWidgetColor.volt)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.system(size: 14, weight: .semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let now = Date()
                    if context.state.nextFireAt > now {
                        Text(timerInterval: now...context.state.nextFireAt, countsDown: true)
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(AeroWidgetColor.volt)
                            .frame(maxWidth: 60)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.stand")
                    .foregroundStyle(AeroWidgetColor.volt)
            } compactTrailing: {
                let now = Date()
                if context.state.nextFireAt > now {
                    Text(timerInterval: now...context.state.nextFireAt, countsDown: true)
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(AeroWidgetColor.volt)
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Image(systemName: "figure.stand")
                    .foregroundStyle(AeroWidgetColor.volt)
            }
        }
    }
}
#endif
#endif
