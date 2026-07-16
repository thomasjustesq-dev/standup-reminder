import AppKit
import SwiftUI

@main
struct StandUpReminderApp: App {
    @ObservedObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            if appState.config.showMenuBarCountdown, !appState.menuBarTitle.isEmpty {
                Text("\(appState.menuBarTitle)")
                    .accessibilityLabel("Next break in \(appState.menuBarTitle)")
            } else {
                Image(systemName: appState.menuBarSymbolName)
                    .accessibilityLabel("Stand Up Reminder")
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        Window("Welcome", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

        Window("Guided Break", id: "guided-break") {
            GuidedBreakView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

        Window("Sample Day", id: "sample-day") {
            SampleDayTourView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var guidedObserver: Any?
    private var tourObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if CLI.runIfNeeded() {
                try? await Task.sleep(nanoseconds: 700_000_000)
                NSApp.terminate(nil)
                return
            }

            NSApp.setActivationPolicy(.accessory)
            AppState.shared.start()

            guidedObserver = NotificationCenter.default.addObserver(
                forName: .openGuidedBreakWindow,
                object: nil,
                queue: .main
            ) { _ in
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.identifier?.rawValue == "guided-break" {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }

            tourObserver = NotificationCenter.default.addObserver(
                forName: .openSampleDayTour,
                object: nil,
                queue: .main
            ) { _ in
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.identifier?.rawValue == "sample-day" {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

extension Notification.Name {
    static let openGuidedBreakWindow = Notification.Name("openGuidedBreakWindow")
    static let openSampleDayTour = Notification.Name("openSampleDayTour")
}
