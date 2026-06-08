import Foundation

enum ProfileSource: String, Codable, Hashable {
    case imported
    case manual
}

struct PortForward: Identifiable, Codable, Hashable {
    var id: UUID
    var localPort: Int
    var remoteHost: String
    var remotePort: Int

    init(id: UUID = UUID(), localPort: Int, remoteHost: String, remotePort: Int) {
        self.id = id
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    var sshFlag: String {
        "-L\(localPort):\(remoteHost):\(remotePort)"
    }
}

struct SSHHostProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var displayName: String
    var hostAlias: String
    var source: ProfileSource
    var portForwards: [PortForward]
    var configForwards: [PortForward]
    var hostname: String?
    var username: String?
    var port: Int?

    init(
        id: UUID = UUID(),
        displayName: String,
        hostAlias: String,
        source: ProfileSource,
        portForwards: [PortForward] = [],
        configForwards: [PortForward] = [],
        hostname: String? = nil,
        username: String? = nil,
        port: Int? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.hostAlias = hostAlias
        self.source = source
        self.portForwards = portForwards
        self.configForwards = configForwards
        self.hostname = hostname
        self.username = username
        self.port = port
    }

    /// Real connect address from `ssh -G` / manual entry — never the SSH config alias.
    var connectableHostname: String? {
        guard let hostname, !hostname.isEmpty else { return nil }
        if source == .imported && hostname == hostAlias { return nil }
        return hostname
    }

    var isConnectionResolved: Bool {
        connectableHostname != nil
    }

    var resolvedHostname: String? {
        connectableHostname
    }

    var subtitle: String {
        if let username, let connectableHostname {
            return "\(username)@\(connectableHostname)\(port.map { $0 != 22 ? ":\($0)" : "" } ?? "")"
        }
        if let connectableHostname {
            return connectableHostname
        }
        return hostAlias
    }
}

struct HostConnectionOverride: Codable, Hashable {
    var displayName: String?
    var hostname: String?
    var username: String?
    var port: Int?
}

struct ProfileStoreData: Codable {
    var manualProfiles: [SSHHostProfile]
    var portForwardOverrides: [String: [PortForward]]
    var hostConnectionOverrides: [String: HostConnectionOverride]
    var sshConfigImportEnabled: Bool
    var sshConfigPath: String?
    var hiddenImportedHostAliases: [String]
    /// Saved terminal color theme per host alias (`TerminalProfile.rawValue`).
    var terminalProfileOverrides: [String: String]
    /// Security-scoped bookmark for a user-chosen SSH config file (not needed for default path).
    var sshConfigBookmark: Data?

    init(
        manualProfiles: [SSHHostProfile] = [],
        portForwardOverrides: [String: [PortForward]] = [:],
        hostConnectionOverrides: [String: HostConnectionOverride] = [:],
        sshConfigImportEnabled: Bool = false,
        sshConfigPath: String? = nil,
        hiddenImportedHostAliases: [String] = [],
        terminalProfileOverrides: [String: String] = [:],
        sshConfigBookmark: Data? = nil
    ) {
        self.manualProfiles = manualProfiles
        self.portForwardOverrides = portForwardOverrides
        self.hostConnectionOverrides = hostConnectionOverrides
        self.sshConfigImportEnabled = sshConfigImportEnabled
        self.sshConfigPath = sshConfigPath
        self.hiddenImportedHostAliases = hiddenImportedHostAliases
        self.terminalProfileOverrides = terminalProfileOverrides
        self.sshConfigBookmark = sshConfigBookmark
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manualProfiles = try container.decodeIfPresent([SSHHostProfile].self, forKey: .manualProfiles) ?? []
        portForwardOverrides = try container.decodeIfPresent([String: [PortForward]].self, forKey: .portForwardOverrides) ?? [:]
        hostConnectionOverrides = try container.decodeIfPresent([String: HostConnectionOverride].self, forKey: .hostConnectionOverrides) ?? [:]
        sshConfigImportEnabled = try container.decodeIfPresent(Bool.self, forKey: .sshConfigImportEnabled) ?? false
        sshConfigPath = try container.decodeIfPresent(String.self, forKey: .sshConfigPath)
        hiddenImportedHostAliases = try container.decodeIfPresent([String].self, forKey: .hiddenImportedHostAliases) ?? []
        terminalProfileOverrides = try container.decodeIfPresent([String: String].self, forKey: .terminalProfileOverrides) ?? [:]
        sshConfigBookmark = try container.decodeIfPresent(Data.self, forKey: .sshConfigBookmark)
    }
}
