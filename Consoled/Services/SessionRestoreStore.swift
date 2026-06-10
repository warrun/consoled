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
import os

struct WorkspaceSessionEntry: Codable, Hashable {
    var hostAlias: String
    var themeID: String
    /// Optional so snapshots written before local sessions existed still decode.
    var isLocal: Bool?
    /// Per-session font override (nil = follow host/default). Optional for back-compat.
    var fontSize: CGFloat?
    /// Notes-session fields (all optional / back-compat).
    var isNotes: Bool?
    var notesText: String?
    var notesName: String?
    var notesPath: String?
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
