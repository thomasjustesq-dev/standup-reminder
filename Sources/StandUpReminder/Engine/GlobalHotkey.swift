import AppKit
import Carbon

/// Lightweight Carbon-based Global Hotkey listener for macOS.
/// Registers global shortcuts (e.g. ⌥⇧S to open popover / log break) without requiring accessibility permissions.
@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]

    enum HotKeyID: UInt32 {
        case togglePopover = 1
        case logBreak = 2
    }

    func setup() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                Task { @MainActor in
                    GlobalHotkeyManager.shared.handleHotKey(id: hotKeyID.id)
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // Register ⌥⇧S (Option + Shift + S) -> Toggle Menu Bar Popover
        register(id: .togglePopover, keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(optionKey | shiftKey))
        // Register ⌥⇧D (Option + Shift + D) -> Quick Log Break Done
        register(id: .logBreak, keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(optionKey | shiftKey))
    }

    private func register(id: HotKeyID, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x53544E44), id: id.rawValue) // 'STND'
        let err = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if err == noErr, let ref = hotKeyRef {
            hotKeyRefs[id.rawValue] = ref
        }
    }

    private func handleHotKey(id: UInt32) {
        guard let hotKey = HotKeyID(rawValue: id) else { return }
        switch hotKey {
        case .togglePopover:
            NotificationCenter.default.post(name: .toggleMenuBarPopover, object: nil)
        case .logBreak:
            AppState.shared.acknowledgeDone()
        }
    }

    deinit {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

extension Notification.Name {
    static let toggleMenuBarPopover = Notification.Name("toggleMenuBarPopover")
}
