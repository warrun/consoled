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
import UniformTypeIdentifiers
import os

/// File persistence for notes — explicit saves to ~/Documents/ConsoledNotes.
@MainActor
enum NotesStore {
    private static let logger = Logger(subsystem: "vigilance.digital.Consoled", category: "NotesStore")

    struct SavedNote: Identifiable {
        let url: URL
        let name: String
        let modified: Date
        var id: URL { url }
    }

    /// Saved notes in ConsoledNotes, newest-modified first.
    static func listSavedNotes() -> [SavedNote] {
        let allowed: Set<String> = ["txt", "md", "text"]
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: defaultDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { allowed.contains($0.pathExtension.lowercased()) }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return SavedNote(url: url, name: url.deletingPathExtension().lastPathComponent, modified: modified)
            }
            .sorted { $0.modified > $1.modified }
    }

    static var defaultDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documents.appending(path: "ConsoledNotes", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Save a note. If it has no file yet, prompt for a name/location (defaulting to
    /// ConsoledNotes). Returns true on success.
    @discardableResult
    static func save(_ document: NotesDocument) -> Bool {
        let url: URL
        if let existing = document.fileURL {
            url = existing
        } else if let chosen = runSavePanel(suggestedName: document.name ?? "Untitled Note") {
            // Never-saved notes seed the panel with the note's title (default "Untitled
            // Note", or whatever the user renamed it to) — not a timestamp. The timestamp
            // naming is reserved for the silent quit-time save of multiple notes.
            url = chosen
        } else {
            return false // user cancelled
        }
        return write(document, to: url)
    }

    /// Rename a saved note's file on disk, in its current directory, preserving the
    /// extension. On a name collision, asks the user to overwrite / auto-number / cancel.
    /// Returns true if the file now lives at the new name (and updates the document).
    @discardableResult
    static func renameSavedNote(_ document: NotesDocument, to newName: String) -> Bool {
        guard let current = document.fileURL else { return false }
        let dir = current.deletingLastPathComponent()
        let ext = current.pathExtension.isEmpty ? "txt" : current.pathExtension
        let base = sanitized(newName)
        var target = dir.appending(path: "\(base).\(ext)")

        if target == current { return false } // no effective change

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: target.path(percentEncoded: false)) {
            switch collisionChoice(for: base) {
            case .overwrite: try? fileManager.removeItem(at: target)
            case .autoNumber: target = uniqueURL(base: base, ext: ext, in: dir)
            case .cancel: return false
            }
        }

        do {
            try fileManager.moveItem(at: current, to: target)
            document.fileURL = target
            document.name = target.deletingPathExtension().lastPathComponent
            return true
        } catch {
            logger.error("Failed to rename note: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private enum Collision { case overwrite, autoNumber, cancel }

    private static func collisionChoice(for name: String) -> Collision {
        let alert = NSAlert()
        alert.messageText = "“\(name)” already exists"
        alert.informativeText = "A note with that name already exists in this folder. "
            + "Overwrite it, keep both (a number is added), or cancel the rename?"
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Keep Both")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .overwrite
        case .alertSecondButtonReturn: return .autoNumber
        default: return .cancel
        }
    }

    /// For the quit prompt's "Save All": never shows a panel — names untitled notes
    /// automatically inside ConsoledNotes so quitting isn't blocked per-note.
    @discardableResult
    static func saveQuietly(_ document: NotesDocument) -> Bool {
        let url = document.fileURL ?? uniqueURL(for: document.name ?? defaultNoteName())
        return write(document, to: url)
    }

    /// A timestamped default name for never-saved notes, e.g. "Consoled Note 2026-06-09 15.28.42".
    static func defaultNoteName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Consoled Note \(formatter.string(from: Date()))"
    }

    private static func write(_ document: NotesDocument, to url: URL) -> Bool {
        do {
            try document.text.write(to: url, atomically: true, encoding: .utf8)
            document.fileURL = url
            document.name = url.deletingPathExtension().lastPathComponent
            document.isDirty = false
            return true
        } catch {
            logger.error("Failed to save note: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func runSavePanel(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.directoryURL = defaultDirectory
        panel.nameFieldStringValue = sanitized(suggestedName) + ".txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.title = "Save Note"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func uniqueURL(for baseName: String) -> URL {
        uniqueURL(base: baseName, ext: "txt", in: defaultDirectory)
    }

    /// First free `<base>.<ext>`, `<base> 2.<ext>`, … in `dir`.
    private static func uniqueURL(base baseName: String, ext: String, in dir: URL) -> URL {
        let base = sanitized(baseName)
        var candidate = dir.appending(path: "\(base).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = dir.appending(path: "\(base) \(counter).\(ext)")
            counter += 1
        }
        return candidate
    }

    private static func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "Untitled Note" : cleaned
    }
}
