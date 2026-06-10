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
    /// Per-host terminal font size; `nil` means follow the global default.
    var fontSize: CGFloat?

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
        themeID: String? = nil,
        fontSize: CGFloat? = nil
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
        self.fontSize = fontSize
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
