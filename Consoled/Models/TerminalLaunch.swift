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

/// Describes the process a terminal panel should launch. Generalizes over SSH
/// (the `ssh` binary with connection args) and a local login shell.
struct TerminalLaunch: Hashable {
    var executable: String
    var args: [String]
    /// argv[0] for the spawned process. `"ssh"` for SSH; a leading-dash shell
    /// name (e.g. `"-zsh"`) marks a local login shell.
    var execName: String?
    var currentDirectory: String?

    /// SSH launches are the only ones that should surface OpenSSH exit-code
    /// diagnostics when the process ends non-zero.
    var isSSH: Bool { execName == "ssh" }
}
