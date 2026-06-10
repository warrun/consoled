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

/// Resolves the user's login shell for local terminal sessions.
enum LocalShell {
    /// The user's preferred shell, from the password database, falling back to
    /// `$SHELL` and finally `/bin/zsh`. The password database is the reliable
    /// source for GUI apps, which don't inherit a `$SHELL` when launched from Finder.
    static var path: String {
        if let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell {
            let resolved = String(cString: shell)
            if !resolved.isEmpty { return resolved }
        }
        if let env = ProcessInfo.processInfo.environment["SHELL"], !env.isEmpty {
            return env
        }
        return "/bin/zsh"
    }

    static func launch() -> TerminalLaunch {
        let shellPath = path
        let shellName = (shellPath as NSString).lastPathComponent
        return TerminalLaunch(
            executable: shellPath,
            args: [],
            // Leading dash signals a login shell via the argv[0] convention.
            execName: "-\(shellName)",
            currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        )
    }
}
