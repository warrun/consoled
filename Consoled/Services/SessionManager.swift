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
    /// Runtime caches synced from settings at launch / on change (mirrors `defaultTerminalTheme`).
    private(set) var defaultFontSize: CGFloat = TerminalTheme.defaultFontSize
    private var terminalOpacity: CGFloat = TerminalTheme.defaultBackgroundOpacity
    /// Live state for notes sessions, keyed by session id (shared with the editor view).
    private(set) var notesDocuments: [UUID: NotesDocument] = [:]

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

    /// The host of the selected session if it's a live remote SSH terminal (not local,
    /// notes, or an SFTP/SCP transfer panel). Used to gate remote-only shortcuts.
    var selectedRemoteHost: SSHHostProfile? {
        guard let session = selectedSession,
              let profile = session.profile,
              session.launchOverride == nil else { return nil }
        return profile
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
        if let session = sessions.last(where: { $0.profile?.id == host.id }) {
            selectedSessionID = session.id
        } else {
            selectedSessionID = nil
        }
    }

    func session(for host: SSHHostProfile) -> TerminalSession? {
        sessions.last(where: { $0.profile?.id == host.id })
    }

    func connect(to host: SSHHostProfile, themeID: String? = nil, fontSize: CGFloat? = nil) {
        ConnectTiming.markConnect()

        let profile = hostCatalog.first(where: { $0.id == host.id }) ?? host
        selectedHostID = profile.id
        let baseTheme = resolvedTheme(for: profile, explicitThemeID: themeID)
        let effectiveFont = fontSize ?? profile.fontSize ?? defaultFontSize
        let session = TerminalSession(
            profile: profile,
            terminalTheme: resolvedSessionTheme(base: baseTheme, fontSize: effectiveFont),
            assignedFontSize: fontSize
        )
        sessions.append(session)
        selectedSessionID = session.id

        ConnectTiming.mark("session added to manager")
    }

    func connectSelectedHost() {
        guard let host = selectedHost else { return }
        connect(to: host)
    }

    func connectLocal(themeID: String? = nil, fontSize: CGFloat? = nil) {
        ConnectTiming.markConnect()
        let baseTheme: TerminalTheme
        if let themeID, let resolved = themeRegistry.theme(id: themeID) {
            baseTheme = resolved
        } else {
            baseTheme = defaultTerminalTheme
        }
        let effectiveFont = fontSize ?? defaultFontSize
        let session = TerminalSession(
            profile: nil,
            terminalTheme: resolvedSessionTheme(base: baseTheme, fontSize: effectiveFont),
            assignedThemeID: themeID,
            assignedFontSize: fontSize
        )
        sessions.append(session)
        selectedSessionID = session.id
        ConnectTiming.mark("local session added to manager")
    }

    func openNotes() {
        let document = NotesDocument()
        let theme = resolvedSessionTheme(base: defaultTerminalTheme, fontSize: defaultFontSize)
        let session = TerminalSession(
            profile: nil,
            terminalTheme: theme,
            notesDocumentID: document.id,
            notesName: nil
        )
        notesDocuments[session.id] = document
        sessions.append(session)
        selectedSessionID = session.id
    }

    func notesDocument(for sessionID: UUID) -> NotesDocument? {
        notesDocuments[sessionID]
    }

    /// Open a saved note file. If it's already open, just select it.
    func openNote(fileURL: URL) {
        if let existing = sessions.first(where: { $0.isNotes && notesDocuments[$0.id]?.fileURL == fileURL }) {
            selectSession(existing)
            return
        }
        let text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let name = fileURL.deletingPathExtension().lastPathComponent
        let document = NotesDocument(text: text, name: name, fileURL: fileURL, isDirty: false)
        let theme = resolvedSessionTheme(base: defaultTerminalTheme, fontSize: defaultFontSize)
        let session = TerminalSession(
            profile: nil,
            terminalTheme: theme,
            notesDocumentID: document.id,
            notesName: name
        )
        notesDocuments[session.id] = document
        sessions.append(session)
        selectedSessionID = session.id
    }

    // MARK: - SFTP / SCP (run in a terminal panel via launch override)

    func openSFTP(to host: SSHHostProfile) {
        let launch = TerminalLaunch(
            executable: SSHCommandBuilder.sftpPath,
            args: SSHCommandBuilder.sftpArgs(for: host),
            execName: "sftp",
            currentDirectory: nil
        )
        openTransfer(to: host, launch: launch, title: "SFTP · \(host.displayName)")
    }

    func openSCPSend(to host: SSHHostProfile, localPath: String, remotePath: String) {
        let launch = TerminalLaunch(
            executable: SSHCommandBuilder.scpPath,
            args: SSHCommandBuilder.scpSendArgs(for: host, localPath: localPath, remotePath: remotePath),
            execName: "scp",
            currentDirectory: nil
        )
        openTransfer(to: host, launch: launch, title: "Copy → \(host.displayName)")
    }

    func openSCPGet(to host: SSHHostProfile, remotePath: String, localPath: String) {
        let launch = TerminalLaunch(
            executable: SSHCommandBuilder.scpPath,
            args: SSHCommandBuilder.scpGetArgs(for: host, remotePath: remotePath, localPath: localPath),
            execName: "scp",
            currentDirectory: nil
        )
        openTransfer(to: host, launch: launch, title: "Copy ← \(host.displayName)")
    }

    private func openTransfer(to host: SSHHostProfile, launch: TerminalLaunch, title: String) {
        let profile = hostCatalog.first(where: { $0.id == host.id }) ?? host
        selectedHostID = profile.id
        let baseTheme = savedTerminalTheme(for: profile)
        let effectiveFont = profile.fontSize ?? defaultFontSize
        let session = TerminalSession(
            profile: profile,
            terminalTheme: resolvedSessionTheme(base: baseTheme, fontSize: effectiveFont),
            launchOverride: launch,
            customTitle: title
        )
        sessions.append(session)
        selectedSessionID = session.id
    }

    var unsavedNotes: [NotesDocument] {
        notesDocuments.values.filter(\.needsSaving)
    }

    /// Reflect a note's saved file name onto its session so the tab/tile title updates.
    func markNotesSaved(sessionID: UUID) {
        guard let document = notesDocuments[sessionID],
              let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].notesName = document.name
    }

    func launch(for session: TerminalSession) -> TerminalLaunch {
        if let override = session.launchOverride {
            return override
        }
        if let profile = session.profile {
            return TerminalLaunch(
                executable: SSHCommandBuilder.sshPath,
                args: SSHCommandBuilder.buildArgs(for: profile),
                execName: "ssh",
                currentDirectory: nil
            )
        }
        return LocalShell.launch()
    }

    func closeSession(_ session: TerminalSession) {
        sessions.removeAll { $0.id == session.id }
        notesDocuments[session.id] = nil
        if selectedSessionID == session.id {
            selectedSessionID = sessions.last?.id
            selectedHostID = sessions.last?.profile?.id ?? selectedHostID
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
        if let hostID = session.profile?.id {
            selectedHostID = hostID
        }
    }

    /// Move focus (selection) to the neighbouring session in a direction, without
    /// reordering. Tabs: left/right select the previous/next tab; tiles: select the
    /// directional neighbour.
    func focusSession(
        _ direction: SessionMoveDirection,
        layoutMode: SessionLayoutMode,
        isPortrait: Bool
    ) {
        guard sessions.count >= 2,
              let id = selectedSessionID,
              let from = sessions.firstIndex(where: { $0.id == id }) else { return }

        let to: Int?
        switch layoutMode {
        case .tabs:
            switch direction {
            case .left: to = from - 1
            case .right: to = from + 1
            case .up, .down: to = nil
            }
        case .tiled:
            to = SessionTileLayout.neighborIndex(
                of: from,
                count: sessions.count,
                isPortrait: isPortrait,
                direction: direction
            )
        }

        guard let target = to, sessions.indices.contains(target), target != from else { return }
        selectSession(sessions[target])
    }

    /// Move the selected session within the workspace. In tabs, left/right shift it one
    /// position (clamped); in tiles, the arrows swap it with its directional neighbour.
    /// Selection rides with the session, so focus follows the moved tile/tab.
    func moveSelectedSession(
        _ direction: SessionMoveDirection,
        layoutMode: SessionLayoutMode,
        isPortrait: Bool
    ) {
        guard sessions.count >= 2,
              let id = selectedSessionID,
              let from = sessions.firstIndex(where: { $0.id == id }) else { return }

        let to: Int?
        switch layoutMode {
        case .tabs:
            switch direction {
            case .left: to = from - 1
            case .right: to = from + 1
            case .up, .down: to = nil
            }
        case .tiled:
            to = SessionTileLayout.neighborIndex(
                of: from,
                count: sessions.count,
                isPortrait: isPortrait,
                direction: direction
            )
        }

        guard let target = to, sessions.indices.contains(target), target != from else { return }
        sessions.swapAt(from, target)
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
        for sessionIndex in sessions.indices where sessions[sessionIndex].profile?.id == host.id {
            sessions[sessionIndex].profile = updated
            sessions[sessionIndex].terminalTheme = resolvedSessionTheme(
                base: theme,
                fontSize: effectiveFontSize(for: sessions[sessionIndex])
            )
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
            for sessionIndex in sessions.indices where sessions[sessionIndex].profile?.id == updated.id {
                sessions[sessionIndex].profile = updated
                sessions[sessionIndex].terminalTheme = resolvedSessionTheme(
                    base: defaultTerminalTheme,
                    fontSize: effectiveFontSize(for: sessions[sessionIndex])
                )
            }
            changed = true
        }
        if changed { persistProfiles() }
    }

    /// Set a theme for one specific session. Used for local sessions, which have no
    /// host to persist a `themeID` on; the choice rides on the session itself and is
    /// captured in the workspace snapshot.
    func setSessionTheme(_ theme: TerminalTheme, forSession id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].assignedThemeID = theme.id
        sessions[index].terminalTheme = resolvedSessionTheme(
            base: theme,
            fontSize: effectiveFontSize(for: sessions[index])
        )
    }

    func applyDefaultTheme(id: String) {
        guard let theme = themeRegistry.theme(id: id) else { return }
        defaultTerminalTheme = theme
        for index in sessions.indices {
            // Leave sessions that have an explicit theme (host- or session-assigned).
            guard sessions[index].profile?.themeID == nil,
                  sessions[index].assignedThemeID == nil else { continue }
            sessions[index].terminalTheme = resolvedSessionTheme(
                base: theme,
                fontSize: effectiveFontSize(for: sessions[index])
            )
        }
    }

    func refreshSessionThemesFromRegistry() {
        defaultTerminalTheme = themeRegistry.theme(id: defaultTerminalTheme.id) ?? themeRegistry.defaultTheme()
        for index in sessions.indices {
            let themeID = sessions[index].profile?.themeID
                ?? sessions[index].assignedThemeID
                ?? defaultTerminalTheme.id
            if let theme = themeRegistry.theme(id: themeID) {
                sessions[index].terminalTheme = resolvedSessionTheme(
                    base: theme,
                    fontSize: effectiveFontSize(for: sessions[index])
                )
            }
        }
    }

    // MARK: - Font size & opacity

    func effectiveFontSize(for session: TerminalSession) -> CGFloat {
        session.assignedFontSize ?? session.profile?.fontSize ?? defaultFontSize
    }

    /// Sync the global default font size and re-resolve sessions that follow it
    /// (no per-session and no per-host override). Mirrors `applyDefaultTheme`.
    func applyDefaultFontSize(_ size: CGFloat) {
        defaultFontSize = clampFont(size)
        for index in sessions.indices {
            guard sessions[index].assignedFontSize == nil,
                  sessions[index].profile?.fontSize == nil else { continue }
            sessions[index].terminalTheme = sessions[index].terminalTheme.withFontSize(defaultFontSize)
        }
    }

    /// Set (or clear, with `nil`) a host's font size. Clears any per-session overrides
    /// on that host's live sessions so the host setting takes effect immediately.
    func setHostFontSize(_ size: CGFloat?, forHost host: SSHHostProfile) {
        guard let index = hostCatalog.firstIndex(where: { $0.id == host.id }) else { return }
        let clamped = size.map(clampFont)
        hostCatalog[index].fontSize = clamped
        let updated = hostCatalog[index]
        let effective = clamped ?? defaultFontSize
        for sessionIndex in sessions.indices where sessions[sessionIndex].profile?.id == host.id {
            sessions[sessionIndex].profile = updated
            sessions[sessionIndex].assignedFontSize = nil
            sessions[sessionIndex].terminalTheme = sessions[sessionIndex].terminalTheme.withFontSize(effective)
        }
        persistProfiles()
    }

    func setSessionFontSize(_ size: CGFloat, forSession id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let clamped = clampFont(size)
        sessions[index].assignedFontSize = clamped
        sessions[index].terminalTheme = sessions[index].terminalTheme.withFontSize(clamped)
    }

    func adjustSelectedSessionFontSize(by delta: CGFloat) {
        guard let id = selectedSessionID,
              let session = sessions.first(where: { $0.id == id }) else { return }
        setSessionFontSize(effectiveFontSize(for: session) + delta, forSession: id)
    }

    /// Sync the global terminal background opacity onto every live session.
    func applyTerminalOpacity(_ opacity: CGFloat) {
        terminalOpacity = opacity
        for index in sessions.indices {
            sessions[index].terminalTheme = sessions[index].terminalTheme.withBackgroundOpacity(opacity)
        }
    }

    private func resolvedSessionTheme(base: TerminalTheme, fontSize: CGFloat) -> TerminalTheme {
        base.withFontSize(clampFont(fontSize)).withBackgroundOpacity(terminalOpacity)
    }

    private func clampFont(_ size: CGFloat) -> CGFloat {
        min(max(size, TerminalTheme.minFontSize), TerminalTheme.maxFontSize)
    }

    func updateHost(_ profile: SSHHostProfile) {
        guard let index = hostCatalog.firstIndex(where: { $0.id == profile.id }) else { return }

        hostCatalog[index] = profile

        for sessionIndex in sessions.indices where sessions[sessionIndex].profile?.id == profile.id {
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

        for sessionIndex in sessions.indices where sessions[sessionIndex].profile?.id == host.id {
            sessions[sessionIndex].profile?.portForwards = forwards
            sessions[sessionIndex].profile?.configForwards = []
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
            sessions: sessions.compactMap { session -> WorkspaceSessionEntry? in
                // Don't persist one-shot/interactive transfer sessions (SFTP/SCP).
                guard session.launchOverride == nil else { return nil }
                if session.isNotes {
                    let document = notesDocuments[session.id]
                    return WorkspaceSessionEntry(
                        hostAlias: "",
                        themeID: session.terminalTheme.id,
                        isLocal: false,
                        fontSize: session.assignedFontSize,
                        isNotes: true,
                        notesText: document?.text ?? "",
                        notesName: document?.name,
                        notesPath: document?.fileURL?.path(percentEncoded: false)
                    )
                }
                return WorkspaceSessionEntry(
                    hostAlias: session.profile?.hostAlias ?? "",
                    themeID: session.terminalTheme.id,
                    isLocal: session.profile == nil,
                    fontSize: session.assignedFontSize
                )
            },
            selectedHostAlias: selectedSession?.profile?.hostAlias
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
            if entry.isNotes == true {
                restoreNotes(
                    text: entry.notesText ?? "",
                    name: entry.notesName,
                    path: entry.notesPath,
                    themeID: entry.themeID,
                    fontSize: entry.fontSize
                )
            } else if entry.isLocal == true {
                connectLocal(themeID: entry.themeID, fontSize: entry.fontSize)
            } else if let host = hostCatalog.first(where: { $0.hostAlias == entry.hostAlias }) {
                connect(to: host, themeID: entry.themeID, fontSize: entry.fontSize)
            }
        }

        if let alias = snapshot.selectedHostAlias,
           let session = sessions.last(where: { $0.profile?.hostAlias == alias }) {
            selectSession(session)
        }
    }

    private func restoreNotes(text: String, name: String?, path: String?, themeID: String?, fontSize: CGFloat?) {
        let url = path.map { URL(fileURLWithPath: $0) }
        let document = NotesDocument(text: text, name: name, fileURL: url, isDirty: false)
        let baseTheme = themeID.flatMap { themeRegistry.theme(id: $0) } ?? defaultTerminalTheme
        let effectiveFont = fontSize ?? defaultFontSize
        let session = TerminalSession(
            profile: nil,
            terminalTheme: resolvedSessionTheme(base: baseTheme, fontSize: effectiveFont),
            assignedThemeID: themeID,
            assignedFontSize: fontSize,
            notesDocumentID: document.id,
            notesName: name
        )
        notesDocuments[session.id] = document
        sessions.append(session)
        selectedSessionID = session.id
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
