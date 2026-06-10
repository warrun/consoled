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

    /// `handler` performs the action and returns whether it acted; the event is consumed
    /// (swallowed from the terminal) only when it did.
    func start(handler: @escaping @MainActor (ShortcutAction) -> Bool) {
        guard token == nil else { return }
        let settings = shortcutSettings
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                // Stand down only while recording a new binding. The bound combos aren't
                // text-editing commands, so they're safe to intercept even when a notes
                // editor or text field has focus.
                if settings.isRecording { return event }

                let mods = ShortcutSettings.maskedModifiers(event.modifierFlags)
                guard let action = settings.action(forKeyCode: event.keyCode, modifiers: mods) else {
                    return event
                }
                return handler(action) ? nil : event
            }
        }
    }

    func stop() {
        if let token {
            NSEvent.removeMonitor(token)
        }
        token = nil
    }
}
