import Foundation

enum SSHConfigImporter {
    static var defaultConfigPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".ssh/config")
            .path(percentEncoded: false)
    }

    static func configIsReadable(at path: String = defaultConfigPath) -> Bool {
        FileManager.default.isReadableFile(atPath: path)
    }

    /// Read and fully resolve every `Host` entry via `ssh -G` (import-time only).
    static func importResolvedHosts(configPath: String = defaultConfigPath) throws -> [SSHHostProfile] {
        let stubs = try importHostStubs(configPath: configPath)
        return stubs.map { stub in
            resolveHost(alias: stub.hostAlias, configPath: configPath) ?? stub
        }
    }

    /// Fast path: parse `Host` aliases only (no subprocesses).
    static func importHostStubs(configPath: String = defaultConfigPath) throws -> [SSHHostProfile] {
        guard configIsReadable(at: configPath) else {
            throw ImportError.configNotReadable(path: configPath)
        }

        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        return parseHostNames(from: content).map { alias in
            SSHHostProfile(
                displayName: alias,
                hostAlias: alias
            )
        }
    }

    static func parseHostNames(from content: String) -> [String] {
        var names: [String] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("host ") else { continue }

            let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2 else { continue }

            for candidate in parts.dropFirst() {
                guard !candidate.isEmpty else { continue }
                guard candidate != "*" else { continue }
                guard !candidate.contains("*") else { continue }
                guard !candidate.contains("?") else { continue }
                names.append(candidate)
            }
        }

        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    nonisolated static func resolveHost(alias: String, configPath: String) -> SSHHostProfile? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: SSHCommandBuilder.sshPath)
        process.arguments = ["-G", "-F", configPath, alias]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        let values = parseKeyValues(from: output)
        let hostname = values["hostname"] ?? alias
        let username = values["user"]
        let port = values["port"].flatMap(Int.init)
        let configForwards = parseLocalForwards(from: output)
        let identityFile = parseNonDefaultIdentityFile(from: output)

        return SSHHostProfile(
            displayName: alias,
            hostAlias: alias,
            configForwards: configForwards,
            hostname: hostname,
            username: username,
            port: port,
            identityFile: identityFile
        )
    }

    /// `ssh -G` always emits the implicit `~/.ssh/id_*` defaults. Only capture an
    /// identity file when it is an explicit, non-default key worth storing.
    static func parseNonDefaultIdentityFile(from sshGOutput: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let defaultKeyStems = ["id_rsa", "id_dsa", "id_ecdsa", "id_ecdsa_sk", "id_ed25519", "id_ed25519_sk", "id_xmss"]
        let defaultPaths = Set(defaultKeyStems.map { "\(home)/.ssh/\($0)" })

        for line in sshGOutput.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("identityfile ") else { continue }

            let value = String(trimmed.dropFirst("identityfile ".count)).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }

            let expanded = value.hasPrefix("~/")
                ? "\(home)/\(value.dropFirst(2))"
                : value
            if defaultPaths.contains(expanded) { continue }
            return value
        }

        return nil
    }

    static func parseKeyValues(from sshGOutput: String) -> [String: String] {
        var values: [String: String] = [:]

        for line in sshGOutput.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            values[parts[0].lowercased()] = parts[1]
        }

        return values
    }

    static func parseLocalForwards(from sshGOutput: String) -> [PortForward] {
        sshGOutput
            .components(separatedBy: .newlines)
            .compactMap { line -> PortForward? in
                let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
                guard trimmed.hasPrefix("localforward ") else { return nil }

                let remainder = trimmed.dropFirst("localforward ".count)
                let parts = remainder.split(separator: " ").map(String.init)
                guard parts.count == 2 else { return nil }

                guard let local = parseEndpoint(parts[0]),
                      let remote = parseEndpoint(parts[1]) else { return nil }

                return PortForward(localPort: local.port, remoteHost: remote.host, remotePort: remote.port)
            }
    }

    private static func parseEndpoint(_ value: String) -> (host: String, port: Int)? {
        var cleaned = value
        if cleaned.hasPrefix("[") {
            guard let closeIndex = cleaned.firstIndex(of: "]") else { return nil }
            let host = String(cleaned[cleaned.index(after: cleaned.startIndex)..<closeIndex])
            cleaned = String(cleaned[cleaned.index(after: closeIndex)...])
            if cleaned.hasPrefix(":") {
                cleaned.removeFirst()
            }
            guard let port = Int(cleaned) else { return nil }
            return (host, port)
        }

        if let colonIndex = cleaned.lastIndex(of: ":") {
            let host = String(cleaned[..<colonIndex])
            let portString = String(cleaned[cleaned.index(after: colonIndex)...])
            guard let port = Int(portString) else { return nil }
            return (host.isEmpty ? "localhost" : host, port)
        }

        return nil
    }

    enum ImportError: LocalizedError {
        case configNotReadable(path: String)

        var errorDescription: String? {
            switch self {
            case .configNotReadable(let path):
                return "Cannot read SSH config at \(path)."
            }
        }
    }
}
