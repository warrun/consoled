import Foundation

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
    var portForwards: [PortForward]
    var configForwards: [PortForward]
    var hostname: String?
    var username: String?
    var port: Int?
    var identityFile: String?
    var themeID: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        hostAlias: String,
        portForwards: [PortForward] = [],
        configForwards: [PortForward] = [],
        hostname: String? = nil,
        username: String? = nil,
        port: Int? = nil,
        identityFile: String? = nil,
        themeID: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.hostAlias = hostAlias
        self.portForwards = portForwards
        self.configForwards = configForwards
        self.hostname = hostname
        self.username = username
        self.port = port
        self.identityFile = identityFile
        self.themeID = themeID
    }

    var connectableHostname: String? {
        guard let hostname, !hostname.isEmpty else { return nil }
        return hostname
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

struct ProfileStoreData: Codable {
    var hostCatalog: [SSHHostProfile]
    var customThemes: [TerminalThemeDefinition]
    var builtInThemeOverrides: [String: TerminalThemeDefinition]

    init(
        hostCatalog: [SSHHostProfile] = [],
        customThemes: [TerminalThemeDefinition] = [],
        builtInThemeOverrides: [String: TerminalThemeDefinition] = [:]
    ) {
        self.hostCatalog = hostCatalog
        self.customThemes = customThemes
        self.builtInThemeOverrides = builtInThemeOverrides
    }
}
