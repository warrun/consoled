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
final class SessionWorkspaceSettings {
    private static let layoutModeKey = "sessionLayoutMode"

    var layoutMode: SessionLayoutMode {
        didSet {
            guard layoutMode != oldValue else { return }
            UserDefaults.standard.set(layoutMode.rawValue, forKey: Self.layoutModeKey)
            if layoutMode == .tabs {
                restoredTileIsPortrait = nil
            }
        }
    }

    /// When set, tiled layout uses this orientation instead of live window geometry.
    var restoredTileIsPortrait: Bool?

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.layoutModeKey),
           let mode = SessionLayoutMode(rawValue: raw) {
            layoutMode = mode
        } else {
            layoutMode = .tabs
        }
    }

    func tileIsPortrait(for bounds: CGSize) -> Bool {
        restoredTileIsPortrait ?? (bounds.width < bounds.height)
    }
}
