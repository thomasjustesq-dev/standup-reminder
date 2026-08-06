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
            HStack(spacing: 2) {
                if appState.notificationsAuthorized == false {
                    Image(systemName: "bell.slash.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.orange, .primary)
                        .accessibilityLabel("Notifications denied")
                } else if appState.config.showMenuBarCountdown, !appState.menuBarTitle.isEmpty {
                    Text("\(appState.menuBarTitle)")
                        .accessibilityLabel("Next break in \(appState.menuBarTitle)")
                } else {
                    Image(systemName: appState.menuBarSymbolName)
                        .accessibilityLabel("Stand Up Reminder")
                }
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

        Window("Today", id: "day-timeline") {
            DayTimelineView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

        #if DEBUG
        Window("Debug Panel", id: "debug-panel") {
            DebugPanel()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
        #endif
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [Any] = []
    private var fallbackWindows: [String: NSWindow] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if await CLI.runIfNeeded() {
                try? await Task.sleep(nanoseconds: 700_000_000)
                NSApp.terminate(nil)
                return
            }

            NSApp.setActivationPolicy(.accessory)

            // Observers must exist before start() — it posts the onboarding
            // and sample-day notifications synchronously on first launch.
            observe(.openGuidedBreakWindow) { [weak self] in
                self?.present(id: "guided-break", title: "Guided Break") {
                    GuidedBreakView().environmentObject(AppState.shared)
                }
            }
            observe(.openSampleDayTour) { [weak self] in
                self?.present(id: "sample-day", title: "Sample Day") {
                    SampleDayTourView().environmentObject(AppState.shared)
                }
            }
            observe(.openDayTimeline) { [weak self] in
                self?.present(id: "day-timeline", title: "Today") {
                    DayTimelineView().environmentObject(AppState.shared)
                }
            }
            observe(.openOnboardingWindow) { [weak self] in
                self?.present(id: "onboarding", title: "Welcome") {
                    OnboardingView().environmentObject(AppState.shared)
                }
            }

            #if DEBUG
            if DebugEnvironment.isDebugMode {
                observe(.openDebugPanel) { [weak self] in
                    self?.present(id: "debug-panel", title: "Debug Panel") {
                        DebugPanel().environmentObject(AppState.shared)
                    }
                }
            }
            #endif

            AppState.shared.start()

            #if DEBUG
            if DebugEnvironment.isDebugMode {
                NotificationCenter.default.post(name: .openDebugPanel, object: nil)
            }
            #endif
        }
    }

    private func observe(_ name: Notification.Name, handler: @escaping @MainActor () -> Void) {
        observers.append(NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in handler() }
        })
    }

    /// The menu-style MenuBarExtra only mounts its view while the menu is
    /// open, so SwiftUI's openWindow may have no caller when a notification
    /// action or launch path needs a window. Front the SwiftUI-scene window
    /// if one exists; otherwise host the same view in an AppKit window. This
    /// is the single presentation choke point — everything (menu items,
    /// notification actions, launch) opens windows by posting the
    /// notifications above, so the dedup here always applies.
    @MainActor
    private func present<Content: View>(id: String, title: String, @ViewBuilder content: () -> Content) {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.identifier?.rawValue == id {
            window.makeKeyAndOrderFront(nil)
            return
        }
        if let existing = fallbackWindows[id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        // SwiftUI's DismissAction is inert inside a plain hosted NSWindow;
        // hand the views a working close path through the environment.
        // The closure must hold the box STRONGLY — it is the box's only
        // owner, and a weak capture leaves the close action a silent no-op
        // the moment this method returns. There is no retain cycle: the
        // box's back-reference to the window is itself weak.
        let box = FallbackWindowBox()
        let root = content().environment(\.fallbackWindowClose) { [box] in
            box.window?.close()
        }
        let controller = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: controller)
        box.window = window
        window.title = title
        window.identifier = NSUserInterfaceItemIdentifier("fallback-\(id)")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        fallbackWindows[id] = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
private final class FallbackWindowBox {
    weak var window: NSWindow?
}

/// Close action for views hosted in an AppDelegate fallback window, where
/// SwiftUI's DismissAction has no window scene to act on. Views call
/// `fallbackWindowClose?() ?? dismiss()`.
private struct FallbackWindowCloseKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> Void)? = nil
}

extension EnvironmentValues {
    var fallbackWindowClose: (@MainActor () -> Void)? {
        get { self[FallbackWindowCloseKey.self] }
        set { self[FallbackWindowCloseKey.self] = newValue }
    }
}

extension Notification.Name {
    static let openGuidedBreakWindow = Notification.Name("openGuidedBreakWindow")
    static let openSampleDayTour = Notification.Name("openSampleDayTour")
    static let openOnboardingWindow = Notification.Name("openOnboardingWindow")
    static let openDayTimeline = Notification.Name("openDayTimeline")
    #if DEBUG
    static let openDebugPanel = Notification.Name("openDebugPanel")
    #endif
    /// Posted via DistributedNotificationCenter by the CLI process after it
    /// mutates state on disk, so the running app picks it up immediately.
    static let standUpExternalStateChanged = AppIdentity.externalStateChanged
    /// Posted via DistributedNotificationCenter by the CLI process to run a
    /// command (e.g. a test reminder) inside the running app, where windows
    /// and notification actions actually live.
    static let standUpRemoteCommand = AppIdentity.remoteCommand
}
