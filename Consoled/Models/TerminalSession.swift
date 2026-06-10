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

struct TerminalSession: Identifiable, Hashable {
    let id: UUID
    /// The SSH host this session connects to, or `nil` for local / notes sessions.
    var profile: SSHHostProfile?
    var terminalTheme: TerminalTheme
    /// Explicit per-session theme override. Used by local/notes sessions (which have no
    /// host to carry a `themeID`); `nil` means follow the default theme.
    var assignedThemeID: String?
    /// Explicit per-session font size (from ⌥⌘± or a local/notes session). `nil` means
    /// follow the host's size, or the global default.
    var assignedFontSize: CGFloat?
    /// Non-nil marks this as a notes (text editor) session rather than a terminal.
    var notesDocumentID: UUID?
    /// Display name for a notes session (the saved file name, when saved).
    var notesName: String?
    /// Overrides the process launch (used by SFTP/SCP sessions); `nil` = ssh/local.
    var launchOverride: TerminalLaunch?
    /// Explicit tab/tile title for SFTP/SCP sessions.
    var customTitle: String?

    init(
        id: UUID = UUID(),
        profile: SSHHostProfile? = nil,
        terminalTheme: TerminalTheme,
        assignedThemeID: String? = nil,
        assignedFontSize: CGFloat? = nil,
        notesDocumentID: UUID? = nil,
        notesName: String? = nil,
        launchOverride: TerminalLaunch? = nil,
        customTitle: String? = nil
    ) {
        self.id = id
        self.profile = profile
        self.terminalTheme = terminalTheme
        self.assignedThemeID = assignedThemeID
        self.assignedFontSize = assignedFontSize
        self.notesDocumentID = notesDocumentID
        self.notesName = notesName
        self.launchOverride = launchOverride
        self.customTitle = customTitle
    }

    var isNotes: Bool { notesDocumentID != nil }

    var isLocal: Bool { profile == nil && !isNotes && launchOverride == nil }

    var title: String {
        if isNotes { return notesName ?? "Untitled Note" }
        if let customTitle { return customTitle }
        return profile?.displayName ?? "Local"
    }
}
