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
        handler: @escaping @MainActor (SessionMoveDirection) -> Void
    ) {
        guard token == nil else { return }
        let settings = shortcutSettings
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                // Stand down while recording a new binding or typing in a text field,
                // and when there's nothing meaningful to reorder.
                if settings.isRecording { return event }
                if ShortcutMonitor.firstResponderIsTextInput() { return event }
                guard sessionCount() >= 2 else { return event }

                let mods = ShortcutSettings.maskedModifiers(event.modifierFlags)
                guard let direction = settings.direction(forKeyCode: event.keyCode, modifiers: mods) else {
                    return event
                }
                handler(direction)
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
