import Foundation

enum SSHCommandBuilder {
    static let sshPath = "/usr/bin/ssh"
    static let sftpPath = "/usr/bin/sftp"
    static let scpPath = "/usr/bin/scp"

    /// Connection options shared by scp/sftp. Uses `-o` form so the same flags work
    /// across both tools (avoids ssh `-p` vs scp `-P` differences).
    private static func transferConnectionOptions(for profile: SSHHostProfile) -> [String] {
        var args: [String] = []
        if let port = profile.port, port != 22 {
            args += ["-o", "Port=\(port)"]
        }
        if let identityFile = profile.identityFile, !identityFile.isEmpty {
            args += ["-o", "IdentityFile=\(expandTilde(identityFile))"]
        }
        return args
    }

    private static func target(for profile: SSHHostProfile) -> String {
        let hostname = profile.connectableHostname ?? profile.hostAlias
        if let username = profile.username, !username.isEmpty {
            return "\(username)@\(hostname)"
        }
        return hostname
    }

    /// Interactive `sftp` session args.
    static func sftpArgs(for profile: SSHHostProfile) -> [String] {
        transferConnectionOptions(for: profile) + [target(for: profile)]
    }

    /// `scp` args to upload a local path to a remote path.
    static func scpSendArgs(for profile: SSHHostProfile, localPath: String, remotePath: String) -> [String] {
        transferConnectionOptions(for: profile) + ["-r", localPath, "\(target(for: profile)):\(remotePath)"]
    }

    /// `scp` args to download a remote path into a local directory.
    static func scpGetArgs(for profile: SSHHostProfile, remotePath: String, localPath: String) -> [String] {
        transferConnectionOptions(for: profile) + ["-r", "\(target(for: profile)):\(remotePath)", localPath]
    }

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
