import SwiftUI

struct SessionSettingsPanel: View {
    @Bindable var manager: SessionManager
    var onPickSSHConfig: () -> Void
    var onResetSSHConfig: () -> Void

    private var settingsHost: SSHHostProfile? {
        manager.selectedSession?.profile ?? manager.selectedHost
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                SettingsSection(title: "SSH Config Import") {
                    VStack(alignment: .leading, spacing: 8) {
                        if manager.sshConfigImportEnabled {
                            Text(manager.configPath)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(3)
                                .padding(.horizontal, 12)

                            HStack {
                                Button("Change…", action: onPickSSHConfig)
                                Button("Reset to Default", action: onResetSSHConfig)
                                    .disabled(manager.configPath == SSHConfigImporter.defaultConfigPath)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                        } else {
                            Text("Import hosts from your SSH config file. Consoled never modifies it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)

                            Button("Import from SSH Config…") {
                                manager.requestSSHConfigImport()
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                        }

                        if let importError = manager.importError {
                            Text(importError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                        }
                    }
                }

                if let host = settingsHost {
                    SettingsSection(title: "Terminal Theme") {
                        TerminalProfilePicker(
                            selection: Binding(
                                get: { manager.savedTerminalProfile(for: host) },
                                set: { profile in
                                    manager.setTerminalProfile(profile, forHost: host)
                                }
                            )
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }

                    SettingsSection(title: "Connection") {
                        HostConnectionEditor(host: host) { displayName, hostname, username, port in
                            manager.updateHostConnection(
                                for: host,
                                displayName: displayName,
                                hostname: hostname,
                                username: username,
                                port: port
                            )
                        }

                        if host.source == .imported {
                            Text("Changes apply on next connect.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                        }
                    }

                    SettingsSection(title: "Port Forwarding") {
                        PortForwardingSection(host: host) { forwards in
                            manager.updatePortForwards(for: host, forwards: forwards)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Host Selected",
                        systemImage: "server.rack",
                        description: Text("Select a host in the sidebar to edit its connection settings.")
                    )
                    .padding(.top, 24)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(settingsHost?.displayName ?? "Settings")
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

            content
        }
    }
}

private struct SettingsField: View {
    let label: String
    @Binding var text: String
    var placeholder: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder ?? label, text: $text)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private struct HostConnectionEditor: View {
    let host: SSHHostProfile
    let onSave: (String, String, String, Int) -> Void

    @State private var displayName: String
    @State private var hostname: String
    @State private var username: String
    @State private var port: String

    init(host: SSHHostProfile, onSave: @escaping (String, String, String, Int) -> Void) {
        self.host = host
        self.onSave = onSave
        _displayName = State(initialValue: host.displayName)
        _hostname = State(initialValue: host.connectableHostname ?? "")
        _username = State(initialValue: host.username ?? "")
        _port = State(initialValue: String(host.port ?? 22))
    }

    var body: some View {
        Group {
            SettingsField(label: "Display name", text: $displayName)
            SettingsField(
                label: "Hostname",
                text: $hostname,
                placeholder: host.source == .imported && !host.isConnectionResolved
                    ? "Resolving from SSH config…"
                    : "Hostname or IP address"
            )
            SettingsField(label: "Username", text: $username)
            SettingsField(label: "Port", text: $port)
        }
        .onSubmit { commit() }
        .onChange(of: host.id) { _, _ in syncFromHost() }
        .onChange(of: host.displayName) { _, _ in syncFromHost() }
        .onChange(of: host.hostname) { _, _ in syncFromHost() }
        .onChange(of: host.username) { _, _ in syncFromHost() }
        .onChange(of: host.port) { _, _ in syncFromHost() }
    }

    private func syncFromHost() {
        displayName = host.displayName
        if let resolved = host.connectableHostname {
            hostname = resolved
        }
        username = host.username ?? ""
        port = String(host.port ?? 22)
    }

    private func commit() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedHostname = hostname.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        guard !trimmedHostname.isEmpty else { return }
        if host.source == .imported && trimmedHostname == host.hostAlias { return }
        let portValue = Int(port.trimmingCharacters(in: .whitespaces)) ?? 22
        onSave(trimmedName, trimmedHostname, username.trimmingCharacters(in: .whitespaces), portValue)
    }
}

private struct PortForwardingSection: View {
    let host: SSHHostProfile
    let onUpdate: ([PortForward]) -> Void

    @State private var forwards: [PortForward] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !host.configForwards.isEmpty {
                ForEach(host.configForwards) { forward in
                    Text("-L \(forward.localPort):\(forward.remoteHost):\(forward.remotePort)")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 12)
                }
            }

            if forwards.isEmpty {
                Text("No additional local forwards.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.horizontal, 12)
            } else {
                ForEach($forwards) { $forward in
                    editableForwardRow($forward)
                }
            }

            Button {
                forwards.append(PortForward(localPort: 8080, remoteHost: "localhost", remotePort: 80))
                commit()
            } label: {
                Label("Add Forward", systemImage: "plus")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear { syncFromHost() }
        .onChange(of: host.id) { _, _ in syncFromHost() }
        .onDisappear { commit() }
    }

    private func syncFromHost() {
        forwards = host.portForwards
    }

    private func commit() {
        onUpdate(forwards)
    }

    private func editableForwardRow(_ forward: Binding<PortForward>) -> some View {
        HStack {
            TextField("Local", value: forward.localPort, format: .number)
                .frame(width: 60)
            Text("→")
                .font(.caption)
            TextField("Remote host", text: forward.remoteHost)
            TextField("Port", value: forward.remotePort, format: .number)
                .frame(width: 60)
            Button(role: .destructive) {
                forwards.removeAll { $0.id == forward.wrappedValue.id }
                commit()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .onSubmit { commit() }
    }
}
