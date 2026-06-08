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
    private static let storageKey = "reorderShortcuts"

    private(set) var moveLeft: KeyBinding
    private(set) var moveRight: KeyBinding
    private(set) var moveUp: KeyBinding
    private(set) var moveDown: KeyBinding

    /// Set while a recorder field is capturing, so the global key monitor stands down.
    var isRecording = false

    init() {
        let defaults = Self.defaultBindings()
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: KeyBinding].self, from: data) {
            moveLeft = decoded["left"] ?? defaults.left
            moveRight = decoded["right"] ?? defaults.right
            moveUp = decoded["up"] ?? defaults.up
            moveDown = decoded["down"] ?? defaults.down
        } else {
            moveLeft = defaults.left
            moveRight = defaults.right
            moveUp = defaults.up
            moveDown = defaults.down
        }
    }

    func binding(for direction: SessionMoveDirection) -> KeyBinding {
        switch direction {
        case .left: return moveLeft
        case .right: return moveRight
        case .up: return moveUp
        case .down: return moveDown
        }
    }

    func label(for direction: SessionMoveDirection) -> String {
        binding(for: direction).displayString
    }

    /// Commit a new binding. Rejected (returns false) if it has no modifier, which
    /// would otherwise swallow a bare keystroke from the terminal.
    @discardableResult
    func setBinding(_ binding: KeyBinding, for direction: SessionMoveDirection) -> Bool {
        guard binding.hasModifier else { return false }
        switch direction {
        case .left: moveLeft = binding
        case .right: moveRight = binding
        case .up: moveUp = binding
        case .down: moveDown = binding
        }
        persist()
        return true
    }

    /// Which reorder action, if any, a key event maps to.
    func direction(forKeyCode keyCode: UInt16, modifiers: UInt) -> SessionMoveDirection? {
        for direction in [SessionMoveDirection.left, .right, .up, .down] {
            let candidate = binding(for: direction)
            if candidate.keyCode == keyCode, candidate.modifiers == modifiers {
                return direction
            }
        }
        return nil
    }

    func resetToDefaults() {
        let defaults = Self.defaultBindings()
        moveLeft = defaults.left
        moveRight = defaults.right
        moveUp = defaults.up
        moveDown = defaults.down
        persist()
    }

    /// Masks raw event modifier flags to the four we care about — used by both the
    /// recorder and the monitor so stored and live values always compare equal.
    static func maskedModifiers(_ flags: NSEvent.ModifierFlags) -> UInt {
        flags.intersection([.command, .option, .control, .shift]).rawValue
    }

    private func persist() {
        let dict = ["left": moveLeft, "right": moveRight, "up": moveUp, "down": moveDown]
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func defaultBindings() -> (
        left: KeyBinding, right: KeyBinding, up: KeyBinding, down: KeyBinding
    ) {
        let mods = maskedModifiers([.command, .shift])
        return (
            KeyBinding(keyCode: 123, modifiers: mods, keyLabel: "←"),
            KeyBinding(keyCode: 124, modifiers: mods, keyLabel: "→"),
            KeyBinding(keyCode: 126, modifiers: mods, keyLabel: "↑"),
            KeyBinding(keyCode: 125, modifiers: mods, keyLabel: "↓")
        )
    }
}
