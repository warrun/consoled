import Foundation

enum SSHCommandBuilder {
    static let sshPath = "/usr/bin/ssh"

    static func buildArgs(for profile: SSHHostProfile) -> [String] {
        var args: [String] = [
            "-o", "ConnectTimeout=15",
            "-o", "ServerAliveInterval=30",
        ]

        var seenForwardFlags = Set<String>()
        for forward in profile.configForwards + profile.portForwards {
            let flag = forward.sshFlag
            if seenForwardFlags.insert(flag).inserted {
                args.append(flag)
            }
        }

        if let identityFile = profile.identityFile, !identityFile.isEmpty {
            args += ["-i", expandTilde(identityFile)]
        }

        if let port = profile.port, port != 22 {
            args += ["-p", String(port)]
        }

        let hostname = profile.connectableHostname ?? profile.hostAlias
        if let username = profile.username, !username.isEmpty {
            args.append("\(username)@\(hostname)")
        } else {
            args.append(hostname)
        }

        return args
    }

    private static func expandTilde(_ path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path == "~" { return home }
        return "\(home)/\(path.dropFirst(2))"
    }
}
