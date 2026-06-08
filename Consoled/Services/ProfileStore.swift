import Foundation
import os

@MainActor
final class ProfileStore {
    static let shared = ProfileStore()

    /// Consoled data only (`~/Library/Application Support/Consoled/profiles.json`).
    /// Never reads or writes `~/.ssh/config`.

    private static let appSupportFolderName = "Consoled"
    private static let legacyAppSupportFolderName = "Termite"
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
        migrateLegacyStoreIfNeeded()

        guard fileManager.fileExists(atPath: storageURL.path()) else {
            return ProfileStoreData()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            return try decoder.decode(ProfileStoreData.self, from: data)
        } catch {
            Self.logger.error("Failed to load profiles.json: \(error.localizedDescription, privacy: .public)")
            backupCorruptStore()
            return ProfileStoreData()
        }
    }

    private func decodeStore(at url: URL) -> ProfileStoreData? {
        guard fileManager.fileExists(atPath: url.path()),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(ProfileStoreData.self, from: data)
    }

    private func isEffectivelyEmpty(_ data: ProfileStoreData) -> Bool {
        data.manualProfiles.isEmpty
            && data.portForwardOverrides.isEmpty
            && data.hostConnectionOverrides.isEmpty
            && data.terminalProfileOverrides.isEmpty
            && data.hiddenImportedHostAliases.isEmpty
            && data.sshConfigBookmark == nil
            && !data.sshConfigImportEnabled
    }

    func save(_ data: ProfileStoreData) {
        do {
            let encoded = try encoder.encode(data)
            try encoded.write(to: storageURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to save profiles.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// One-time migration from the pre-rename Termite Application Support folder.
    private func migrateLegacyStoreIfNeeded() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let legacyURL = appSupport
            .appending(path: Self.legacyAppSupportFolderName, directoryHint: .isDirectory)
            .appending(path: "profiles.json")

        guard let legacyData = decodeStore(at: legacyURL),
              !isEffectivelyEmpty(legacyData) else {
            return
        }

        let shouldCopy: Bool
        if fileManager.fileExists(atPath: storageURL.path()) {
            shouldCopy = (decodeStore(at: storageURL).map(isEffectivelyEmpty) ?? true)
        } else {
            shouldCopy = true
        }

        guard shouldCopy else { return }

        try? fileManager.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: storageURL.path()) {
            try? fileManager.removeItem(at: storageURL)
        }
        try? fileManager.copyItem(at: legacyURL, to: storageURL)
        Self.logger.info("Migrated profiles from legacy Termite Application Support folder")
    }

    private func backupCorruptStore() {
        let corruptURL = storageURL.deletingPathExtension().appendingPathExtension("corrupt.json")
        try? fileManager.removeItem(at: corruptURL)
        try? fileManager.copyItem(at: storageURL, to: corruptURL)
        Self.logger.warning("Backed up corrupt profiles.json to \(corruptURL.path(), privacy: .public)")
    }
}
