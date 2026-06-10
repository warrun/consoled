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
import SwiftUI

/// A focusable control that records a key combination. Click it, press the desired
/// combo, and it commits the binding. Modifier-less combos are rejected with a hint.
struct ShortcutRecorderField: NSViewRepresentable {
    let action: ShortcutAction
    /// Passed in (read in the parent body) so SwiftUI re-renders this row when the
    /// binding changes elsewhere — e.g. a reassign that frees another action.
    let currentBinding: KeyBinding
    let shortcutSettings: ShortcutSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action, settings: shortcutSettings)
    }

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.binding = currentBinding
        view.onCapture = { newBinding in
            context.coordinator.settings.setBinding(newBinding, for: context.coordinator.action)
        }
        view.onRecordingChange = { recording in
            context.coordinator.settings.isRecording = recording
        }
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        // Reflect external changes (e.g. reassign / Reset to Defaults) while idle.
        if !shortcutSettings.isRecording {
            nsView.binding = currentBinding
            nsView.needsDisplay = true
        }
    }

    final class Coordinator {
        let action: ShortcutAction
        let settings: ShortcutSettings
        init(action: ShortcutAction, settings: ShortcutSettings) {
            self.action = action
            self.settings = settings
        }
    }
}

final class RecorderView: NSView {
    var binding: KeyBinding?
    /// Returns whether the combo was accepted (it has a modifier).
    var onCapture: ((KeyBinding) -> Bool)?
    var onRecordingChange: ((Bool) -> Void)?

    private var recording = false {
        didSet {
            guard recording != oldValue else { return }
            needsDisplay = true
            onRecordingChange?(recording)
        }
    }
    private var needsModifierHint = false

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 130, height: 24) }

    override func mouseDown(with event: NSEvent) {
        // Recording starts only on an explicit click — never from the window auto-
        // assigning first responder when Settings opens (which previously left the
        // global isRecording flag stuck on, killing all shortcuts).
        window?.makeFirstResponder(self)
        recording = true
        needsModifierHint = false
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        needsModifierHint = false
        needsDisplay = true
        return true
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        // Settings closed mid-record: make sure the global recording flag is cleared.
        if newWindow == nil {
            recording = false
        }
    }

    override func keyDown(with event: NSEvent) {
        guard recording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 { // Escape cancels recording.
            window?.makeFirstResponder(nil)
            return
        }

        let mods = ShortcutSettings.maskedModifiers(event.modifierFlags)
        guard mods != 0 else {
            needsModifierHint = true
            needsDisplay = true
            return
        }

        let candidate = KeyBinding(
            keyCode: event.keyCode,
            modifiers: mods,
            keyLabel: Self.keyLabel(for: event)
        )
        if onCapture?(candidate) == true {
            binding = candidate
            window?.makeFirstResponder(nil)
        } else {
            needsModifierHint = true
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5)

        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.12)
                   : NSColor.controlBackgroundColor).setFill()
        path.fill()

        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 2 : 1
        path.stroke()

        let text: String
        let color: NSColor
        if recording {
            text = needsModifierHint ? "Add a modifier (⌘⌥⌃⇧)" : "Press keys…"
            color = needsModifierHint ? .systemRed : .secondaryLabelColor
        } else {
            text = binding?.displayString ?? "—"
            color = .labelColor
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: recording ? .regular : .medium),
            .foregroundColor: color,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.size()
        let origin = NSPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2
        )
        attributed.draw(at: origin)
    }

    private static func keyLabel(for event: NSEvent) -> String {
        switch event.keyCode {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        default:
            if let chars = event.charactersIgnoringModifiers,
               let scalar = chars.unicodeScalars.first,
               scalar.value >= 0x20 {
                return chars.uppercased()
            }
            return "Key \(event.keyCode)"
        }
    }
}
