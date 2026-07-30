#if DEBUG
import SwiftUI

/// In-app debug overlay that surfaces the current notification schedule,
/// active rule set, and next-fire timestamps.
///
/// **Access**: only reachable in debug builds when the app is launched with
/// the `--debug` argument — see `DebugEnvironment.isDebugMode`.
struct DebugPanel: View {
    @EnvironmentObject private var appState: AppState

    private var ruleTraceText: String {
        DebugCommands.ruleTrace(input: appState.makeSchedulerInput())
    }

    private var scheduleJson: String {
        DebugCommands.scheduleSnapshot(input: appState.makeSchedulerInput(), count: 20)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Group {
                    Text("Active Rules").font(.headline)
                    Text(ruleTraceText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                Group {
                    Text("Runtime State").font(.headline)
                    if let nextFire = appState.nextFireAt {
                        LabeledContent("Next Fire", value: nextFire.formatted(
                            .dateTime.weekday(.abbreviated).hour().minute().second()))
                    } else {
                        LabeledContent("Next Fire", value: "none")
                    }
                    LabeledContent("Paused", value: appState.isPaused ? "yes" : "no")
                    LabeledContent("Snoozing", value: appState.isSnoozing ? "yes" : "no")
                    LabeledContent("Skip Today", value: appState.isSkipTodayActive ? "yes" : "no")
                    LabeledContent("Interval", value: "\(appState.effectiveIntervalMinutes) min")
                    LabeledContent("Profile", value: appState.activeProfileName)
                    LabeledContent("Notifications", value: {
                        switch appState.notificationsAuthorized {
                        case true: return "authorized"
                        case false: return "denied"
                        default: return "unknown"
                        }
                    }())
                }

                Divider()

                Group {
                    Text("Upcoming Schedule (next 20)").font(.headline)
                    Text(scheduleJson)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}
#endif
