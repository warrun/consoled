import AppKit

/// Installs a local key-event monitor that intercepts the configured reorder
/// shortcuts before they reach the terminal's first responder. Returning `nil` from
/// the monitor consumes the event so SwiftTerm never sees the combo.
@MainActor
final class ShortcutMonitor {
    private var token: Any?
    private let shortcutSettings: ShortcutSettings

    init(shortcutSettings: ShortcutSettings) {
        self.shortcutSettings = shortcutSettings
    }

    func start(
        sessionCount: @escaping @MainActor () -> Int,
        handler: @escaping @MainActor (ShortcutAction) -> Void
    ) {
        guard token == nil else { return }
        let settings = shortcutSettings
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                // Stand down while recording a new binding or typing in a text field.
                if settings.isRecording { return event }
                if ShortcutMonitor.firstResponderIsTextInput() { return event }

                let mods = ShortcutSettings.maskedModifiers(event.modifierFlags)
                guard let action = settings.action(forKeyCode: event.keyCode, modifiers: mods) else {
                    return event
                }
                // Moves need at least two sessions; font tweaks need at least one.
                // Don't consume the key if the action can't act.
                let count = sessionCount()
                if action.moveDirection != nil, count < 2 { return event }
                if action.isFont, count < 1 { return event }

                handler(action)
                return nil
            }
        }
    }

    func stop() {
        if let token {
            NSEvent.removeMonitor(token)
        }
        token = nil
    }

    /// True when an actual text field/editor has focus (not the terminal, which is a
    /// plain NSView). Keeps the shortcut from hijacking host-editor and recorder fields.
    private static func firstResponderIsTextInput() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSText || responder is NSTextView
    }
}
