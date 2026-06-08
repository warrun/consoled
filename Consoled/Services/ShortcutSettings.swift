import AppKit
import Foundation
import Observation

/// A captured key combination: a physical key plus its modifier flags.
struct KeyBinding: Codable, Hashable {
    var keyCode: UInt16
    /// `NSEvent.ModifierFlags` rawValue, masked to ⌘/⌥/⌃/⇧.
    var modifiers: UInt
    /// Display text for the key itself, e.g. "←" or "W".
    var keyLabel: String

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var hasModifier: Bool {
        !flags.intersection([.command, .option, .control, .shift]).isEmpty
    }

    /// e.g. "⇧⌘←" — modifier glyphs in Apple's canonical ⌃⌥⇧⌘ order.
    var displayString: String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result + keyLabel
    }
}

/// User-customizable shortcuts for reordering sessions. Persists to UserDefaults,
/// following the same `@Observable` + didSet/init pattern as the other settings stores.
@Observable
@MainActor
final class ShortcutSettings {
    private static let storageKey = "sessionShortcuts"

    private var bindings: [ShortcutAction: KeyBinding]

    /// Set while a recorder field is capturing, so the global key monitor stands down.
    var isRecording = false

    init() {
        let defaults = Self.defaultBindings()
        var resolved = defaults
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: KeyBinding].self, from: data) {
            for action in ShortcutAction.allCases {
                if let stored = decoded[action.rawValue] {
                    resolved[action] = stored
                }
            }
        }
        bindings = resolved
    }

    func binding(for action: ShortcutAction) -> KeyBinding {
        bindings[action] ?? Self.defaultBindings()[action]!
    }

    func label(for action: ShortcutAction) -> String {
        binding(for: action).displayString
    }

    /// Commit a new binding. Rejected (returns false) if it has no modifier, which
    /// would otherwise swallow a bare keystroke from the terminal.
    @discardableResult
    func setBinding(_ binding: KeyBinding, for action: ShortcutAction) -> Bool {
        guard binding.hasModifier else { return false }
        bindings[action] = binding
        persist()
        return true
    }

    /// Which action, if any, a key event maps to.
    func action(forKeyCode keyCode: UInt16, modifiers: UInt) -> ShortcutAction? {
        for action in ShortcutAction.allCases {
            let candidate = binding(for: action)
            if candidate.keyCode == keyCode, candidate.modifiers == modifiers {
                return action
            }
        }
        return nil
    }

    func resetToDefaults() {
        bindings = Self.defaultBindings()
        persist()
    }

    /// Masks raw event modifier flags to the four we care about — used by both the
    /// recorder and the monitor so stored and live values always compare equal.
    static func maskedModifiers(_ flags: NSEvent.ModifierFlags) -> UInt {
        flags.intersection([.command, .option, .control, .shift]).rawValue
    }

    private func persist() {
        let dict = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func defaultBindings() -> [ShortcutAction: KeyBinding] {
        let mods = maskedModifiers([.command, .shift])
        return [
            .moveLeft: KeyBinding(keyCode: 123, modifiers: mods, keyLabel: "←"),
            .moveRight: KeyBinding(keyCode: 124, modifiers: mods, keyLabel: "→"),
            .moveUp: KeyBinding(keyCode: 126, modifiers: mods, keyLabel: "↑"),
            .moveDown: KeyBinding(keyCode: 125, modifiers: mods, keyLabel: "↓"),
            .fontIncrease: KeyBinding(keyCode: 24, modifiers: mods, keyLabel: "+"),
            .fontDecrease: KeyBinding(keyCode: 27, modifiers: mods, keyLabel: "−"),
        ]
    }
}
