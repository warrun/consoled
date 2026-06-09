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
        } else if let chosen = runSavePanel(suggestedName: document.name ?? defaultNoteName()) {
            url = chosen
        } else {
            return false // user cancelled
        }
        return write(document, to: url)
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
        let dir = defaultDirectory
        let base = sanitized(baseName)
        var candidate = dir.appending(path: "\(base).txt")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = dir.appending(path: "\(base) \(counter).txt")
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
