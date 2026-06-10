//
//  Consoled — A lightweight SSH session and terminal window manager for macOS.
//  Copyright (C) 2026 Warrun Lewis
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

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

    /// A "not bound" placeholder (used after a combo is reassigned away from an action).
    static let unset = KeyBinding(keyCode: .max, modifiers: 0, keyLabel: "—")
    var isUnset: Bool { self == .unset }

    /// Same physical key + modifiers (ignores the display label).
    func matches(_ other: KeyBinding) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }

    /// e.g. "⌃⌥⌘←" — modifier glyphs in Apple's canonical ⌃⌥⇧⌘ order.
    var displayString: String {
        if isUnset { return "Not set" }
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
    private static let schemaVersionKey = "sessionShortcutsSchemaVersion"
    /// v2 = ⇧⌘ → ⌥⌘ (free ⇧⌘+arrows for text selection).
    /// v3 = ⌥⌘ → ⌃⌥⌘ (avoid window-manager clashes like Rectangle/Magnet).
    private static let currentSchemaVersion = 3

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

        // One-time migration: upgrade any binding still equal to a prior default
        // (⇧⌘ or ⌥⌘) to the current ⌃⌥⌘ default. Explicit customisations are untouched.
        let storedVersion = UserDefaults.standard.integer(forKey: Self.schemaVersionKey)
        let migrating = storedVersion < Self.currentSchemaVersion
        if migrating {
            let legacySets = Self.legacyDefaultBindingSets()
            for action in ShortcutAction.allCases
            where legacySets.contains(where: { $0[action] == resolved[action] }) {
                resolved[action] = defaults[action]
            }
        }

        bindings = resolved

        if migrating {
            persist()
            UserDefaults.standard.set(Self.currentSchemaVersion, forKey: Self.schemaVersionKey)
        }
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
        // Reassign: a combo can belong to only one action — clear it from any other.
        for other in ShortcutAction.allCases where other != action {
            if bindings[other]?.matches(binding) == true {
                bindings[other] = .unset
            }
        }
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

    /// Current shipped defaults: focus = ⌥⌘+arrows, swap & font = ⌃⌥⌘.
    private static func defaultBindings() -> [ShortcutAction: KeyBinding] {
        var result = swapAndFontBindings(modifiers: [.control, .option, .command])
        let focusMods = maskedModifiers([.command, .option])
        result[.focusLeft] = KeyBinding(keyCode: 123, modifiers: focusMods, keyLabel: "←")
        result[.focusRight] = KeyBinding(keyCode: 124, modifiers: focusMods, keyLabel: "→")
        result[.focusUp] = KeyBinding(keyCode: 126, modifiers: focusMods, keyLabel: "↑")
        result[.focusDown] = KeyBinding(keyCode: 125, modifiers: focusMods, keyLabel: "↓")

        // Remote file transfer: ⌃⌥⌘ + U (upload/send) / D (download/get) / S (SFTP).
        let transferMods = maskedModifiers([.control, .option, .command])
        result[.scpSend] = KeyBinding(keyCode: 32, modifiers: transferMods, keyLabel: "U")
        result[.scpGet] = KeyBinding(keyCode: 2, modifiers: transferMods, keyLabel: "D")
        result[.openSFTP] = KeyBinding(keyCode: 1, modifiers: transferMods, keyLabel: "S")
        return result
    }

    /// Prior shipped swap/font defaults, used only to detect untouched bindings during
    /// migration: v1 = ⇧⌘, v2 = ⌥⌘ (focus didn't exist then, so it's excluded).
    private static func legacyDefaultBindingSets() -> [[ShortcutAction: KeyBinding]] {
        [
            swapAndFontBindings(modifiers: [.command, .shift]),
            swapAndFontBindings(modifiers: [.command, .option]),
        ]
    }

    private static func swapAndFontBindings(modifiers flags: NSEvent.ModifierFlags) -> [ShortcutAction: KeyBinding] {
        let mods = maskedModifiers(flags)
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
