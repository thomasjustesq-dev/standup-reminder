import AppKit
import SwiftUI

@main
struct StandUpReminderApp: App {
    @ObservedObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
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
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if await CLI.runIfNeeded() {
                try? await Task.sleep(nanoseconds: 700_000_000)
                NSApp.terminate(nil)
                return
            }

            NSApp.setActivationPolicy(.accessory)
            installStatusItem()

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
            refreshStatusItem()

            #if DEBUG
            if DebugEnvironment.isDebugMode {
                NotificationCenter.default.post(name: .openDebugPanel, object: nil)
            }
            #endif
        }
    }

    @MainActor
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarMark.image()
        item.button?.image?.isTemplate = true
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Stand Up Reminder"
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(AppState.shared)
        )
        self.popover = popover
    }

    @MainActor
    private func refreshStatusItem() {
        let appState = AppState.shared
        let progress: Double? = {
            guard appState.config.showMenuBarCountdown,
                  appState.config.enabled,
                  !appState.isPaused,
                  let next = appState.nextFireAt else { return nil }
            let now = Date()
            let remaining = max(0, next.timeIntervalSince(now))
            let total = max(60.0, Double(appState.effectiveIntervalMinutes * 60))
            let elapsed = max(0, total - remaining)
            return min(1.0, elapsed / total)
        }()

        statusItem?.button?.image = MenuBarMark.image(
            denied: appState.notificationsAuthorized == false,
            progress: progress
        )
        statusItem?.button?.image?.isTemplate = true
        statusItem?.button?.imagePosition = .imageOnly
    }

    @MainActor
    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        refreshStatusItem()
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(AppState.shared)
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.window?.makeKey()
    }

    private func observe(_ name: Notification.Name, handler: @escaping @MainActor () -> Void) {
        observers.append(NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in handler() }
        })
    }

    /// Status-item popover and notification actions have no SwiftUI window
    /// scene, so openWindow may have no caller. Front the SwiftUI-scene
    /// window if one exists; otherwise host the same view in an AppKit
    /// window. This is the single presentation choke point.
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
