import Foundation
import os

struct WorkspaceSessionEntry: Codable, Hashable {
    var hostAlias: String
    var themeID: String
    /// Optional so snapshots written before local sessions existed still decode.
    var isLocal: Bool?
}

struct WorkspaceSnapshot: Codable {
    var layoutMode: SessionLayoutMode
    var tileLayoutIsPortrait: Bool?
    var sessions: [WorkspaceSessionEntry]
    var selectedHostAlias: String?
}

@MainActor
enum SessionRestoreStore {
    private static let logger = Logger(subsystem: "vigilance.digital.Consoled", category: "SessionRestoreStore")

    private static var snapshotURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appending(path: "Consoled", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "workspace-snapshot.json")
    }

    static func save(_ snapshot: WorkspaceSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: snapshotURL, options: .atomic)
        } catch {
            logger.error("Failed to save workspace snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func load() -> WorkspaceSnapshot? {
        guard FileManager.default.fileExists(atPath: snapshotURL.path(percentEncoded: false)) else { return nil }
        do {
            let data = try Data(contentsOf: snapshotURL)
            return try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        } catch {
            logger.error("Failed to load workspace snapshot: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: snapshotURL)
    }
}
