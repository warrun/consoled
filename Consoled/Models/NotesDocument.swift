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
import Observation

/// The live state of a notes session, shared (by reference) between the AppKit editor
/// view and the SwiftUI layer (close prompt, title, quit prompt).
@Observable
@MainActor
final class NotesDocument: Identifiable {
    let id: UUID
    var text: String
    /// The on-disk file name (without path), once saved.
    var name: String?
    /// The file this note has been saved to, if any.
    var fileURL: URL?
    /// Unsaved changes since the last save / since restore.
    var isDirty: Bool

    init(
        id: UUID = UUID(),
        text: String = "",
        name: String? = nil,
        fileURL: URL? = nil,
        isDirty: Bool = false
    ) {
        self.id = id
        self.text = text
        self.name = name
        self.fileURL = fileURL
        self.isDirty = isDirty
    }

    /// Whether the note should prompt-to-save on close/quit. A note with no file is
    /// inherently unsaved once it has any content (so restored, never-saved notes keep
    /// prompting); a saved note only needs saving when modified since its last write.
    var needsSaving: Bool {
        fileURL == nil ? !text.isEmpty : isDirty
    }
}
