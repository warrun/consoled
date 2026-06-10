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

import Foundation

@Observable
@MainActor
final class TerminalSettings {
    private static let profileKey = "terminalProfileID"
    private static let fontSizeKey = "defaultTerminalFontSize"

    private let themeRegistry: TerminalThemeRegistry

    var defaultThemeID: String {
        didSet {
            guard defaultThemeID != oldValue else { return }
            save()
            onChange?()
        }
    }

    var defaultFontSize: CGFloat {
        didSet {
            let clamped = min(max(defaultFontSize, TerminalTheme.minFontSize), TerminalTheme.maxFontSize)
            if clamped != defaultFontSize {
                defaultFontSize = clamped
                return
            }
            guard defaultFontSize != oldValue else { return }
            UserDefaults.standard.set(Double(defaultFontSize), forKey: Self.fontSizeKey)
        }
    }

    var onChange: (() -> Void)?

    var defaultTheme: TerminalTheme {
        themeRegistry.theme(id: defaultThemeID) ?? themeRegistry.defaultTheme()
    }

    init(themeRegistry: TerminalThemeRegistry) {
        self.themeRegistry = themeRegistry
        if let id = UserDefaults.standard.string(forKey: Self.profileKey),
           themeRegistry.theme(id: id) != nil {
            defaultThemeID = id
        } else {
            defaultThemeID = BuiltInTerminalThemes.defaultID
        }

        let storedFont = UserDefaults.standard.object(forKey: Self.fontSizeKey) as? Double
        let resolvedFont = storedFont.map { CGFloat($0) } ?? TerminalTheme.defaultFontSize
        defaultFontSize = min(max(resolvedFont, TerminalTheme.minFontSize), TerminalTheme.maxFontSize)
    }

    private func save() {
        UserDefaults.standard.set(defaultThemeID, forKey: Self.profileKey)
    }
}
