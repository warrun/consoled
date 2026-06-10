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

import SwiftUI

struct TerminalProfilePicker: View {
    let themes: [TerminalTheme]
    @Binding var selectionID: String

    var body: some View {
        Picker("Profile", selection: $selectionID) {
            ForEach(themes) { theme in
                Label {
                    Text(theme.displayName)
                } icon: {
                    Circle()
                        .fill(Color(nsColor: theme.accent))
                        .frame(width: 8, height: 8)
                }
                .tag(theme.id)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .help("Terminal color profile")
    }
}
