import Foundation
import Observation

@MainActor
@Observable
final class SessionManager {
    private(set) var hostCatalog: [SSHHostProfile] = []
    private(set) var sessions: [TerminalSession] = []
    private(set) var selectedHostID: UUID?
    private(set) var selectedSessionID: UUID?
    private(set) var importError: String?
    var showConfigAccessSheet = false
    var showConfigConsentSheet = false
    var defaultTerminalTheme: TerminalTheme

    let themeRegistry: TerminalThemeRegistry

    private var pendingImportPath: String?

    var hosts: [SSHHostProfile] { hostCatalog }

    var hasSavedHosts: Bool {
        !hostCatalog.isEmpty
    }

    var hostCount: Int {
        hostCatalog.count
    }

    var importAttemptPath: String {
        pendingImportPath ?? SSHConfigImporter.defaultConfigPath
    }

    var selectedHost: SSHHostProfile? {
        guard let selectedHostID else { return nil }
        return hostCatalog.first { $0.id == selectedHostID }
    }

    var selectedSession: TerminalSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    var assignedThemeIDs: Set<String> {
        Set(hostCatalog.compactMap(\.themeID))
    }

    init(themeRegistry: TerminalThemeRegistry) {
        self.themeRegistry = themeRegistry
        self.defaultTerminalTheme = themeRegistry.defaultTheme()
        let data = ProfileStore.shared.load()
        loadPersistedProfiles(from: data)
        themeRegistry.importFromProfileStore(
            custom: data.customThemes,
            builtInOverrides: data.builtInThemeOverrides
        )
        if let id = UserDefaults.standard.string(forKey: "terminalProfileID"),
           let theme = themeRegistry.theme(id: id) {
            defaultTerminalTheme = theme
        } else {
            defaultTerminalTheme = themeRegistry.defaultTheme()
        }
        ensureSelectionValidity()
    }

    func requestSSHConfigImport() {
        showConfigConsentSheet = true
    }

    func grantSSHConfigAccess(path: String, bookmark: Data? = nil) {
        pendingImportPath = resolvedImportPath(path: path, bookmark: bookmark)
        showConfigConsentSheet = false
        performSSHConfigImport()
    }

    func dismissConfigConsent() {
        showConfigConsentSheet = false
    }

    func clearAllHosts() {
        importError = nil
        hostCatalog = []
        pendingImportPath = nil
        showConfigAccessSheet = false
        ensureSelectionValidity()
        persistProfiles()
    }

    private func performSSHConfigImport() {
        guard let configPath = pendingImportPath else {
            showConfigConsentSheet = true
            return
        }

        importError = nil

        guard SSHConfigImporter.configIsReadable(at: configPath) else {
            importError = "Cannot read SSH config at \(configPath)."
            showConfigAccessSheet = true
            return
        }

        do {
            let resolved = try SSHConfigImporter.importResolvedHosts(configPath: configPath)
            hostCatalog = mergeImportedHosts(resolved)
            pendingImportPath = nil
            showConfigAccessSheet = false
            ensureSelectionValidity()
            persistProfiles()
        } catch {
            importError = error.localizedDescription
            showConfigAccessSheet = true
        }
    }

    private func resolvedImportPath(path: String, bookmark: Data?) -> String {
        guard path != SSHConfigImporter.defaultConfigPath,
              let bookmark,
              let url = SSHConfigBookmark.resolve(bookmark) else {
            return path
        }
        _ = url.startAccessingSecurityScopedResource()
        return url.path(percentEncoded: false)
    }

    func selectHost(_ host: SSHHostProfile) {
        selectedHostID = host.id
        if let session = sessions.last(where: { $0.profile.id == host.id }) {
            selectedSessionID = session.id
        } else {
            selectedSessionID = nil
        }
    }

    func session(for host: SSHHostProfile) -> TerminalSession? {
        sessions.last(where: { $0.profile.id == host.id })
    }

    func connect(to host: SSHHostProfile, themeID: String? = nil) {
        ConnectTiming.markConnect()

        let profile = hostCatalog.first(where: { $0.id == host.id }) ?? host
        selectedHostID = profile.id
        let theme = resolvedTheme(for: profile, explicitThemeID: themeID)
        let session = TerminalSession(profile: profile, terminalTheme: theme)
        sessions.append(session)
        selectedSessionID = session.id

        ConnectTiming.mark("session added to manager")
    }

    func connectSelectedHost() {
        guard let host = selectedHost else { return }
        connect(to: host)
    }

    func closeSession(_ session: TerminalSession) {
        sessions.removeAll { $0.id == session.id }
        if selectedSessionID == session.id {
            selectedSessionID = sessions.last?.id
            selectedHostID = sessions.last?.profile.id ?? selectedHostID
        }
        if sessions.isEmpty {
            selectedSessionID = nil
            ConnectTiming.reset()
        }
    }

    func closeSelectedSession() {
        guard let session = selectedSession else { return }
        closeSession(session)
    }

    func selectSession(_ session: TerminalSession) {
        selectedSessionID = session.id
        selectedHostID = session.profile.id
    }

    func savedTerminalTheme(for host: SSHHostProfile) -> TerminalTheme {
        if let id = themeID(for: host), let theme = themeRegistry.theme(id: id) {
            return theme
        }
        return defaultTerminalTheme
    }

    func savedTerminalThemeID(for host: SSHHostProfile) -> String {
        themeID(for: host) ?? defaultTerminalTheme.id
    }

    func setTerminalTheme(_ theme: TerminalTheme, forHost host: SSHHostProfile) {
        guard let index = hostCatalog.firstIndex(where: { $0.id == host.id }) else { return }
        hostCatalog[index].themeID = theme.id
        let updated = hostCatalog[index]
        for sessionIndex in sessions.indices where sessions[sessionIndex].profile.id == host.id {
            sessions[sessionIndex].profile = updated
            sessions[sessionIndex].terminalTheme = theme
        }
        persistProfiles()
    }

    /// Clear the theme assignment from every host using `themeID`, reverting them
    /// (and their live sessions) to the current default theme. Used before deleting
    /// a theme so no host is left pointing at a theme that no longer exists.
    func revertHostsToDefaultTheme(themeID: String) {
        var changed = false
        for index in hostCatalog.indices where hostCatalog[index].themeID == themeID {
            hostCatalog[index].themeID = nil
            let updated = hostCatalog[index]
            for sessionIndex in sessions.indices where sessions[sessionIndex].profile.id == updated.id {
                sessions[sessionIndex].profile = updated
                sessions[sessionIndex].terminalTheme = defaultTerminalTheme
            }
            changed = true
        }
        if changed { persistProfiles() }
    }

    func applyDefaultTheme(id: String) {
        guard let theme = themeRegistry.theme(id: id) else { return }
        defaultTerminalTheme = theme
        for index in sessions.indices {
            guard sessions[index].profile.themeID == nil else { continue }
            sessions[index].terminalTheme = theme
        }
    }

    func refreshSessionThemesFromRegistry() {
        defaultTerminalTheme = themeRegistry.theme(id: defaultTerminalTheme.id) ?? themeRegistry.defaultTheme()
        for index in sessions.indices {
            let themeID = sessions[index].profile.themeID ?? defaultTerminalTheme.id
            if let theme = themeRegistry.theme(id: themeID) {
                sessions[index].terminalTheme = theme
            }
        }
    }

    func updateHost(_ profile: SSHHostProfile) {
        guard let index = hostCatalog.firstIndex(where: { $0.id == profile.id }) else { return }

        hostCatalog[index] = profile

        for sessionIndex in sessions.indices where sessions[sessionIndex].profile.id == profile.id {
            sessions[sessionIndex].profile = profile
        }

        persistProfiles()
    }

    func updateHostConnection(
        for host: SSHHostProfile,
        displayName: String,
        hostname: String,
        username: String,
        port: Int,
        identityFile: String
    ) {
        var updated = host
        updated.displayName = displayName
        updated.hostname = hostname
        let trimmedUser = username.trimmingCharacters(in: .whitespaces)
        updated.username = trimmedUser.isEmpty ? nil : trimmedUser
        updated.port = port
        let trimmedKey = identityFile.trimmingCharacters(in: .whitespaces)
        updated.identityFile = trimmedKey.isEmpty ? nil : trimmedKey
        updateHost(updated)
    }

    func updatePortForwards(for host: SSHHostProfile, forwards: [PortForward]) {
        guard let index = hostCatalog.firstIndex(where: { $0.id == host.id }) else { return }
        // The editor presents config-imported and manually-added forwards as one
        // unified, editable list. Persist the whole list as user-owned forwards and
        // clear the config bucket so nothing is shown twice on the next sync.
        hostCatalog[index].portForwards = forwards
        hostCatalog[index].configForwards = []
        persistProfiles()

        for sessionIndex in sessions.indices where sessions[sessionIndex].profile.id == host.id {
            sessions[sessionIndex].profile.portForwards = forwards
            sessions[sessionIndex].profile.configForwards = []
        }
    }

    func addHost(_ profile: SSHHostProfile) {
        hostCatalog.append(profile)
        persistProfiles()
        selectedHostID = profile.id
    }

    func deleteHost(_ host: SSHHostProfile) {
        hostCatalog.removeAll { $0.id == host.id }
        if selectedHostID == host.id {
            selectedHostID = hostCatalog.first?.id
        }
        persistProfiles()
    }

    func saveAllPreferences() {
        persistProfiles()
    }

    func saveWorkspaceSnapshot(
        layoutMode: SessionLayoutMode,
        tileLayoutIsPortrait: Bool?
    ) {
        guard !sessions.isEmpty else {
            SessionRestoreStore.clear()
            return
        }

        let snapshot = WorkspaceSnapshot(
            layoutMode: layoutMode,
            tileLayoutIsPortrait: layoutMode == .tiled ? tileLayoutIsPortrait : nil,
            sessions: sessions.map {
                WorkspaceSessionEntry(hostAlias: $0.profile.hostAlias, themeID: $0.terminalTheme.id)
            },
            selectedHostAlias: selectedSession?.profile.hostAlias
        )
        SessionRestoreStore.save(snapshot)
    }

    func clearWorkspaceSnapshot() {
        SessionRestoreStore.clear()
    }

    func restoreWorkspaceIfNeeded(
        enabled: Bool,
        workspaceSettings: SessionWorkspaceSettings
    ) {
        guard enabled, sessions.isEmpty else { return }
        guard let snapshot = SessionRestoreStore.load() else { return }

        workspaceSettings.layoutMode = snapshot.layoutMode
        if snapshot.layoutMode == .tiled, let portrait = snapshot.tileLayoutIsPortrait {
            workspaceSettings.restoredTileIsPortrait = portrait
        }

        for entry in snapshot.sessions {
            guard let host = hostCatalog.first(where: { $0.hostAlias == entry.hostAlias }) else { continue }
            connect(to: host, themeID: entry.themeID)
        }

        if let alias = snapshot.selectedHostAlias,
           let session = sessions.last(where: { $0.profile.hostAlias == alias }) {
            selectSession(session)
        }
    }

    func sshArgs(for profile: SSHHostProfile) -> [String] {
        SSHCommandBuilder.buildArgs(for: profile)
    }

    private func themeID(for host: SSHHostProfile) -> String? {
        hostCatalog.first(where: { $0.id == host.id })?.themeID ?? host.themeID
    }

    private func resolvedTheme(for host: SSHHostProfile, explicitThemeID: String?) -> TerminalTheme {
        if let explicitThemeID, let theme = themeRegistry.theme(id: explicitThemeID) {
            return theme
        }
        return savedTerminalTheme(for: host)
    }

    /// Merge a fresh import into the catalog. Match by `hostAlias`:
    /// refresh config-derived fields, preserve user-owned fields, add new aliases.
    private func mergeImportedHosts(_ resolved: [SSHHostProfile]) -> [SSHHostProfile] {
        var byAlias = Dictionary(grouping: hostCatalog, by: \.hostAlias)
            .compactMapValues { $0.first }

        for incoming in resolved {
            if var existing = byAlias[incoming.hostAlias] {
                existing.hostname = incoming.hostname
                existing.username = incoming.username
                existing.port = incoming.port
                // Don't re-add a config forward the user has already folded into
                // their own list — match by value, since IDs differ across imports.
                let existingKeys = Set(existing.portForwards.map(Self.forwardValueKey))
                existing.configForwards = incoming.configForwards.filter {
                    !existingKeys.contains(Self.forwardValueKey($0))
                }
                existing.identityFile = incoming.identityFile
                byAlias[incoming.hostAlias] = existing
            } else {
                byAlias[incoming.hostAlias] = incoming
            }
        }

        let resolvedAliases = Set(resolved.map(\.hostAlias))
        var merged = resolved.compactMap { byAlias[$0.hostAlias] }
        for existing in hostCatalog where !resolvedAliases.contains(existing.hostAlias) {
            merged.append(byAlias[existing.hostAlias] ?? existing)
        }
        return merged
    }

    private static func forwardValueKey(_ forward: PortForward) -> String {
        "\(forward.localPort):\(forward.remoteHost):\(forward.remotePort)"
    }

    private func loadPersistedProfiles(from data: ProfileStoreData) {
        hostCatalog = data.hostCatalog
    }

    private func persistProfiles() {
        let themeData = themeRegistry.exportForProfileStore()
        ProfileStore.shared.save(
            ProfileStoreData(
                hostCatalog: hostCatalog,
                customThemes: themeData.custom,
                builtInThemeOverrides: themeData.builtInOverrides
            )
        )
    }

    private func ensureSelectionValidity() {
        if let selectedHostID, !hostCatalog.contains(where: { $0.id == selectedHostID }) {
            self.selectedHostID = hostCatalog.first?.id
        } else if selectedHostID == nil {
            selectedHostID = hostCatalog.first?.id
        }

        if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
            self.selectedSessionID = sessions.last?.id
        }
    }
}
