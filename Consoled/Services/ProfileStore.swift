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

@MainActor
final class ProfileStore {
    static let shared = ProfileStore()

    /// Consoled data only (`~/Library/Application Support/Consoled/profiles.json`).
    /// Never reads or writes `~/.ssh/config`. Never deletes or rewrites the store
    /// on a read failure — a bad read must never destroy good data.

    private static let appSupportFolderName = "Consoled"
    private static let logger = Logger(subsystem: "vigilance.digital.Consoled", category: "ProfileStore")

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appending(path: Self.appSupportFolderName, directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "profiles.json")
    }

    func load() -> ProfileStoreData {
        // NOTE: `URL.path()` returns a percent-encoded string (e.g. "Application%20Support"),
        // which `FileManager` path APIs do not understand. Always use the decoded form.
        guard fileManager.fileExists(atPath: storageURL.path(percentEncoded: false)) else {
            Self.logger.info("No profiles.json found; starting empty")
            return ProfileStoreData()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let store = try decoder.decode(ProfileStoreData.self, from: data)
            Self.logger.info("Loaded profiles.json: \(store.hostCatalog.count, privacy: .public) hosts")
            return store
        } catch {
            // Non-destructive: keep the file exactly as-is so the user can recover.
            Self.logger.error("Failed to decode profiles.json: \(error.localizedDescription, privacy: .public). Leaving file untouched.")
            return ProfileStoreData()
        }
    }

    func save(_ data: ProfileStoreData) {
        do {
            let encoded = try encoder.encode(data)
            try encoded.write(to: storageURL, options: .atomic)
            Self.logger.info("Saved profiles.json: \(data.hostCatalog.count, privacy: .public) hosts")
        } catch {
            Self.logger.error("Failed to save profiles.json: \(error.localizedDescription, privacy: .public)")
        }
    }
}
