import Foundation
import Observation

@MainActor
@Observable
final class SessionManager {
    private(set) var hosts: [SSHHostProfile] = []
    private(set) var sessions: [TerminalSession] = []
    private(set) var selectedHostID: UUID?
    private(set) var selectedSessionID: UUID?
    private(set) var importError: String?
    private(set) var configPath: String
    private(set) var sshConfigImportEnabled: Bool
    var showConfigAccessSheet = false
    var showConfigConsentSheet = false
    var defaultTerminalProfile: TerminalProfile = .homebrew

    private var manualProfiles: [SSHHostProfile] = []
    private var portForwardOverrides: [String: [PortForward]] = [:]
    private var hostConnectionOverrides: [String: HostConnectionOverride] = [:]
    private var terminalProfileOverrides: [String: String] = [:]
    private var sshConfigBookmark: Data?
    private var hiddenImportedHostAliases = Set<String>()
    private var resolvedAliases = Set<String>()

    var selectedHost: SSHHostProfile? {
        guard let selectedHostID else { return nil }
        return hosts.first { $0.id == selectedHostID }
    }

    var selectedSession: TerminalSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    init(configPath: String = SSHConfigImporter.defaultConfigPath) {
        self.configPath = configPath
        self.sshConfigImportEnabled = false
        loadPersistedProfiles()
        reloadHosts()
    }

    func requestSSHConfigImport() {
        if sshConfigImportEnabled {
            importSSHConfig()
        } else {
            showConfigConsentSheet = true
        }
    }

    func grantSSHConfigAccess(path: String, bookmark: Data? = nil) {
        sshConfigImportEnabled = true
        configPath = path
        if path == SSHConfigImporter.defaultConfigPath {
            sshConfigBookmark = nil
        } else {
            sshConfigBookmark = bookmark
        }
        resolvedAliases.removeAll()
        persistProfiles()
        showConfigConsentSheet = false
        importSSHConfig()
    }

    func resetSSHConfigToDefault() {
        grantSSHConfigAccess(path: SSHConfigImporter.defaultConfigPath, bookmark: nil)
    }

    func dismissConfigConsent() {
        showConfigConsentSheet = false
    }

    func importSSHConfig() {
        guard sshConfigImportEnabled else {
            showConfigConsentSheet = true
            return
        }

        importError = nil
        resolveSSHConfigPathIfNeeded()

        guard SSHConfigImporter.configIsReadable(at: configPath) else {
            importError = "Cannot read SSH config at \(configPath)."
            showConfigAccessSheet = true
            hosts = manualProfiles
            ensureSelectionValidity()
            return
        }

        do {
            let stubs = try SSHConfigImporter.importHostStubs(configPath: configPath)
            hosts = mergeStubs(stubs) + manualProfiles
            ensureSelectionValidity()
            for stub in stubs {
                enrichHost(alias: stub.hostAlias)
            }
        } catch {
            importError = error.localizedDescription
            hosts = manualProfiles
            ensureSelectionValidity()
            return
        }

        if sessions.isEmpty, let selectedHost {
            enrichHost(alias: selectedHost.hostAlias)
        }
    }

    func refreshHosts() {
        importSSHConfig()
    }

    private func reloadHosts() {
        if sshConfigImportEnabled {
            importSSHConfig()
        } else {
            hosts = manualProfiles
            ensureSelectionValidity()
        }
    }

    func selectHost(_ host: SSHHostProfile) {
        selectedHostID = host.id
        if let session = sessions.last(where: { $0.profile.id == host.id }) {
            selectedSessionID = session.id
        } else {
            selectedSessionID = nil
        }
        enrichHost(alias: host.hostAlias)
    }

    func session(for host: SSHHostProfile) -> TerminalSession? {
        sessions.last(where: { $0.profile.id == host.id })
    }

    func connect(to host: SSHHostProfile) {
        ConnectTiming.markConnect()

        let profile = hosts.first(where: { $0.id == host.id }) ?? host
        selectedHostID = profile.id
        let session = TerminalSession(profile: profile, terminalProfile: savedTerminalProfile(for: profile))
        sessions.append(session)
        selectedSessionID = session.id

        ConnectTiming.mark("session added to manager")
        enrichHost(alias: profile.hostAlias)
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

    func savedTerminalProfile(for host: SSHHostProfile) -> TerminalProfile {
        if let id = terminalProfileOverrides[host.hostAlias],
           let profile = TerminalProfile(id: id) {
            return profile
        }
        return defaultTerminalProfile
    }

    func setTerminalProfile(_ profile: TerminalProfile, forHost host: SSHHostProfile) {
        terminalProfileOverrides[host.hostAlias] = profile.id
        for index in sessions.indices where sessions[index].profile.hostAlias == host.hostAlias {
            sessions[index].terminalProfile = profile
        }
        persistProfiles()
    }

    func setTerminalProfile(_ profile: TerminalProfile, for sessionID: UUID) {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return }
        setTerminalProfile(profile, forHost: session.profile)
    }

    func updateManualHost(_ profile: SSHHostProfile) {
        guard profile.source == .manual else { return }
        guard let manualIndex = manualProfiles.firstIndex(where: { $0.id == profile.id }) else { return }

        manualProfiles[manualIndex] = profile

        if let hostIndex = hosts.firstIndex(where: { $0.id == profile.id }) {
            hosts[hostIndex] = profile
        }

        for index in sessions.indices where sessions[index].profile.id == profile.id {
            sessions[index].profile = profile
        }

        persistProfiles()
    }

    func updateHostConnection(
        for host: SSHHostProfile,
        displayName: String,
        hostname: String,
        username: String,
        port: Int
    ) {
        if host.source == .manual {
            var updated = host
            updated.displayName = displayName
            updated.hostAlias = displayName
            updated.hostname = hostname
            let trimmedUser = username.trimmingCharacters(in: .whitespaces)
            updated.username = trimmedUser.isEmpty ? nil : trimmedUser
            updated.port = port
            updateManualHost(updated)
            return
        }

        var override = hostConnectionOverrides[host.hostAlias] ?? HostConnectionOverride()
        override.displayName = displayName
        if hostname == host.hostAlias {
            override.hostname = nil
        } else {
            override.hostname = hostname
        }
        let trimmedUser = username.trimmingCharacters(in: .whitespaces)
        override.username = trimmedUser.isEmpty ? nil : trimmedUser
        override.port = port
        hostConnectionOverrides[host.hostAlias] = override

        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = applyOverride(override, to: hosts[index])
        }

        for index in sessions.indices where sessions[index].profile.id == host.id {
            sessions[index].profile = applyOverride(override, to: sessions[index].profile)
        }

        persistProfiles()
    }

    func connectionOverride(for host: SSHHostProfile) -> HostConnectionOverride? {
        guard host.source == .imported else { return nil }
        return hostConnectionOverrides[host.hostAlias]
    }

    func updatePortForwards(for host: SSHHostProfile, forwards: [PortForward]) {
        if host.source == .manual {
            guard let index = manualProfiles.firstIndex(where: { $0.id == host.id }) else { return }
            manualProfiles[index].portForwards = forwards
            persistProfiles()
        } else {
            portForwardOverrides[host.hostAlias] = forwards
            persistProfiles()
        }

        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index].portForwards = forwards
        }
    }

    func addManualHost(_ profile: SSHHostProfile) {
        manualProfiles.append(profile)
        persistProfiles()
        reloadHosts()
        selectedHostID = profile.id
    }

    func deleteManualHost(_ host: SSHHostProfile) {
        guard host.source == .manual else { return }
        manualProfiles.removeAll { $0.id == host.id }
        persistProfiles()
        reloadHosts()
    }

    /// Removes an imported host from Consoled only. Never modifies `~/.ssh/config`.
    func removeImportedHost(_ host: SSHHostProfile) {
        guard host.source == .imported else { return }
        hiddenImportedHostAliases.insert(host.hostAlias)
        hostConnectionOverrides.removeValue(forKey: host.hostAlias)
        portForwardOverrides.removeValue(forKey: host.hostAlias)
        hosts.removeAll { $0.id == host.id }
        if selectedHostID == host.id {
            selectedHostID = hosts.first?.id
        }
        persistProfiles()
    }

    func saveAllPreferences() {
        persistProfiles()
    }

    func setConfigPath(_ path: String) {
        grantSSHConfigAccess(path: path)
    }

    func sshArgs(for profile: SSHHostProfile) -> [String] {
        let override = profile.source == .imported ? hostConnectionOverrides[profile.hostAlias] : nil
        let effectiveConfigPath = sshConfigImportEnabled ? configPath : nil
        return SSHCommandBuilder.buildArgs(
            for: profile,
            configPath: effectiveConfigPath,
            connectionOverride: override
        )
    }

    private func mergeStubs(_ stubs: [SSHHostProfile]) -> [SSHHostProfile] {
        stubs
            .filter { !hiddenImportedHostAliases.contains($0.hostAlias) }
            .map { stub in
            var profile = stub
            profile.portForwards = portForwardOverrides[stub.hostAlias] ?? []

            if let override = hostConnectionOverrides[stub.hostAlias] {
                profile = applyOverride(override, to: profile)
            }

            if let existing = hosts.first(where: { $0.hostAlias == stub.hostAlias && $0.source == .imported }),
               existing.username != nil || !existing.configForwards.isEmpty {
                profile.id = existing.id
                if hostConnectionOverrides[stub.hostAlias] == nil {
                    if existing.hostname != stub.hostAlias {
                        profile.hostname = existing.hostname
                    }
                    profile.username = existing.username
                    profile.port = existing.port
                }
                profile.configForwards = existing.configForwards
            }

            if profile.hostname == profile.hostAlias {
                profile.hostname = nil
            }

            return profile
        }
    }

    private func applyOverride(_ override: HostConnectionOverride, to profile: SSHHostProfile) -> SSHHostProfile {
        var updated = profile
        if let displayName = override.displayName {
            updated.displayName = displayName
        }
        if let hostname = override.hostname, hostname != profile.hostAlias {
            updated.hostname = hostname
        }
        if let username = override.username {
            updated.username = username
        }
        if let port = override.port {
            updated.port = port
        }
        if updated.source == .imported, updated.hostname == updated.hostAlias {
            updated.hostname = nil
        }
        return updated
    }

    private func enrichHost(alias: String) {
        guard sshConfigImportEnabled else { return }
        guard !resolvedAliases.contains(alias) else { return }
        guard hosts.contains(where: { $0.hostAlias == alias && $0.source == .imported }) else { return }

        if let index = hosts.firstIndex(where: { $0.hostAlias == alias && $0.source == .imported }),
           hosts[index].isConnectionResolved {
            resolvedAliases.insert(alias)
            return
        }

        resolvedAliases.insert(alias)
        let path = configPath

        Task {
            let resolved = await Task.detached {
                SSHConfigImporter.resolveHost(alias: alias, configPath: path)
            }.value

            guard let resolved,
                  let index = hosts.firstIndex(where: { $0.hostAlias == alias && $0.source == .imported }) else {
                return
            }

            hosts[index].hostname = resolved.hostname
            hosts[index].username = resolved.username
            hosts[index].port = resolved.port
            hosts[index].configForwards = resolved.configForwards
            hosts[index].portForwards = portForwardOverrides[alias] ?? hosts[index].portForwards

            if let override = hostConnectionOverrides[alias] {
                hosts[index] = applyOverride(override, to: hosts[index])
            }

            let enriched = hosts[index]
            for sessionIndex in sessions.indices where sessions[sessionIndex].profile.hostAlias == alias {
                sessions[sessionIndex].profile = enriched
            }
        }
    }

    private func sanitizeConnectionOverrides() {
        for (alias, var override) in hostConnectionOverrides {
            if override.hostname == alias {
                override.hostname = nil
                hostConnectionOverrides[alias] = override
            }
        }
    }

    private func loadPersistedProfiles() {
        let data = ProfileStore.shared.load()
        manualProfiles = data.manualProfiles
        portForwardOverrides = data.portForwardOverrides
        hostConnectionOverrides = data.hostConnectionOverrides
        terminalProfileOverrides = data.terminalProfileOverrides
        sshConfigBookmark = data.sshConfigBookmark
        hiddenImportedHostAliases = Set(data.hiddenImportedHostAliases)
        sanitizeConnectionOverrides()
        sshConfigImportEnabled = data.sshConfigImportEnabled
        if let path = data.sshConfigPath {
            configPath = path
        }
    }

    private func persistProfiles() {
        ProfileStore.shared.save(
            ProfileStoreData(
                manualProfiles: manualProfiles,
                portForwardOverrides: portForwardOverrides,
                hostConnectionOverrides: hostConnectionOverrides,
                sshConfigImportEnabled: sshConfigImportEnabled,
                sshConfigPath: sshConfigImportEnabled ? configPath : nil,
                hiddenImportedHostAliases: hiddenImportedHostAliases.sorted(),
                terminalProfileOverrides: terminalProfileOverrides,
                sshConfigBookmark: sshConfigBookmark
            )
        )
    }

    private func resolveSSHConfigPathIfNeeded() {
        guard configPath != SSHConfigImporter.defaultConfigPath,
              let bookmark = sshConfigBookmark,
              let url = SSHConfigBookmark.resolve(bookmark) else {
            return
        }
        _ = url.startAccessingSecurityScopedResource()
        configPath = url.path()
    }

    private func ensureSelectionValidity() {
        if let selectedHostID, !hosts.contains(where: { $0.id == selectedHostID }) {
            self.selectedHostID = hosts.first?.id
        } else if selectedHostID == nil {
            selectedHostID = hosts.first?.id
        }

        if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
            self.selectedSessionID = sessions.last?.id
        }
    }
}
