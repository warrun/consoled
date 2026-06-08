import Foundation

enum SSHCommandBuilder {
    static let sshPath = "/usr/bin/ssh"

    static func buildArgs(
        for profile: SSHHostProfile,
        configPath: String?,
        connectionOverride: HostConnectionOverride? = nil
    ) -> [String] {
        var args: [String] = [
            "-o", "ConnectTimeout=15",
            "-o", "ServerAliveInterval=30",
        ]

        if let configPath {
            args += ["-F", configPath]
        }

        if profile.source == .manual {
            for forward in profile.portForwards {
                args.append(forward.sshFlag)
            }
        } else {
            for forward in profile.portForwards where !profile.configForwards.contains(forward) {
                args.append(forward.sshFlag)
            }
        }

        switch profile.source {
        case .manual:
            if let port = profile.port, port != 22 {
                args += ["-p", String(port)]
            }
            if let hostname = profile.hostname {
                if let username = profile.username, !username.isEmpty {
                    args.append("\(username)@\(hostname)")
                } else {
                    args.append(hostname)
                }
            } else {
                args.append(profile.hostAlias)
            }
        case .imported:
            if let override = connectionOverride {
                if let hostname = override.hostname, !hostname.isEmpty {
                    args += ["-o", "HostName=\(hostname)"]
                }
                if let username = override.username, !username.isEmpty {
                    args += ["-o", "User=\(username)"]
                }
                if let port = override.port, port != 22 {
                    args += ["-p", String(port)]
                }
            }
            args.append(profile.hostAlias)
        }

        return args
    }
}
