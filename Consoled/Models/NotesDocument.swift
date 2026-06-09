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
