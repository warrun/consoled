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

enum TerminalPrewarm {
    private static var prewarmView: ConsoledTerminalView?

    static func warm() {
        guard prewarmView == nil else { return }
        let view = ConsoledTerminalView(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        let themeID = UserDefaults.standard.string(forKey: "terminalProfileID") ?? BuiltInTerminalThemes.defaultID
        let definition = BuiltInTerminalThemes.all.first { $0.id == themeID } ?? BuiltInTerminalThemes.all[0]
        let theme = TerminalTheme(definition: definition)
        TerminalAppearance.apply(theme, to: view)
        prewarmView = view
    }
}
