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
import SwiftTerm

enum TerminalAppearance {
    static func apply(_ theme: TerminalTheme, to terminal: ConsoledTerminalView) {
        terminal.nativeForegroundColor = theme.accent
        terminal.nativeBackgroundColor = .clear
        terminal.caretColor = theme.accent
        terminal.caretTextColor = NSColor.black
        terminal.selectedTextBackgroundColor = theme.selection
        terminal.font = theme.font
        terminal.useBrightColors = false
        terminal.installColors(theme.ansiPalette)
        terminal.getTerminal().setCursorStyle(.blinkBlock)
        enforceClearLayer(on: terminal)
        DispatchQueue.main.async {
            enforceClearLayer(on: terminal)
        }
    }

    static func applyContainer(_ theme: TerminalTheme, to container: TerminalContainerView) {
        container.updateFrostedBackdrop(theme: theme)
        enforceClearLayer(on: container)
        enforceClearLayer(on: container.terminalView)
    }

    static func enforceClearLayer(on view: NSView) {
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    static func configureWindowForTransparency(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
    }
}
