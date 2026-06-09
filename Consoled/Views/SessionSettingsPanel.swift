import SwiftUI
import UniformTypeIdentifiers

struct SessionSettingsPanel: View {
    @Bindable var manager: SessionManager

    private var settingsHost: SSHHostProfile? {
        manager.selectedSession?.profile ?? manager.selectedHost
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let session = manager.selectedSession, session.isLocal || session.isNotes {
                    localSessionSettings(session)
                } else if let host = settingsHost {
                    SettingsSection(title: "Terminal Theme") {
                        TerminalProfilePicker(
                            themes: manager.themeRegistry.allThemes,
                            selectionID: Binding(
                                get: { manager.savedTerminalThemeID(for: host) },
                                set: { themeID in
                                    guard let theme = manager.themeRegistry.theme(id: themeID) else { return }
                                    manager.setTerminalTheme(theme, forHost: host)
                                }
                            )
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }

                    hostFontSection(host)

                    HostConfigDraftPanel(host: host, manager: manager)
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
        .navigationTitle(panelTitle)
    }

    private var panelTitle: String {
        if let session = manager.selectedSession, session.isLocal {
            return session.title
        }
        return settingsHost?.displayName ?? "Settings"
    }

    @ViewBuilder
    private func localSessionSettings(_ session: TerminalSession) -> some View {
        SettingsSection(title: "Terminal Theme") {
            TerminalProfilePicker(
                themes: manager.themeRegistry.allThemes,
                selectionID: Binding(
                    get: { session.terminalTheme.id },
                    set: { themeID in
                        guard let theme = manager.themeRegistry.theme(id: themeID) else { return }
                        manager.setSessionTheme(theme, forSession: session.id)
                    }
                )
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }

        SettingsSection(title: "Font Size") {
            Stepper(
                "\(Int(manager.effectiveFontSize(for: session))) pt",
                value: Binding(
                    get: { manager.effectiveFontSize(for: session) },
                    set: { manager.setSessionFontSize($0, forSession: session.id) }
                ),
                in: TerminalTheme.minFontSize...TerminalTheme.maxFontSize,
                step: 1
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func hostFontSection(_ host: SSHHostProfile) -> some View {
        SettingsSection(title: "Font Size") {
            VStack(alignment: .leading, spacing: 6) {
                Stepper(
                    "\(Int(host.fontSize ?? manager.defaultFontSize)) pt",
                    value: Binding(
                        get: { host.fontSize ?? manager.defaultFontSize },
                        set: { manager.setHostFontSize($0, forHost: host) }
                    ),
                    in: TerminalTheme.minFontSize...TerminalTheme.maxFontSize,
                    step: 1
                )

                if host.fontSize != nil {
                    Button("Use default size") {
                        manager.setHostFontSize(nil, forHost: host)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                } else {
                    Text("Following the global default.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
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

/// Connection + port forwarding edits held locally until the user clicks Save.
/// Theme changes above save immediately and are not part of this draft.
private struct HostConfigDraftPanel: View {
    let host: SSHHostProfile
    @Bindable var manager: SessionManager

    @State private var displayName = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port = "22"
    @State private var identityFile = ""
    @State private var forwards: [PortForward] = []
    @State private var showingKeyPicker = false

    var body: some View {
        SettingsSection(title: "Connection") {
            SettingsField(label: "Display name", text: $displayName)
            SettingsField(
                label: "Hostname",
                text: $hostname,
                placeholder: "Hostname or IP address"
            )
            SettingsField(label: "Username", text: $username)
            SettingsField(label: "Port", text: $port)
            identityFileField
        }

        SettingsSection(title: "Port Forwarding") {
            portForwardingContent
        }

        HStack {
            Spacer()
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear { syncFromHost() }
        .onChange(of: host.id) { _, _ in syncFromHost() }
        .fileImporter(
            isPresented: $showingKeyPicker,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                identityFile = url.path(percentEncoded: false)
            }
        }
    }

    private var identityFileField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Identity file (SSH key)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Default keys", text: $identityFile)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") { showingKeyPicker = true }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var portForwardingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if forwards.isEmpty {
                Text("No local forwards.")
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
            } label: {
                Label("Add Forward", systemImage: "plus")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private func editableForwardRow(_ forward: Binding<PortForward>) -> some View {
        HStack {
            TextField("Local", value: forward.localPort, format: .number.grouping(.never))
                .frame(width: 60)
            Text("→")
                .font(.caption)
            TextField("Remote host", text: forward.remoteHost)
            TextField("Port", value: forward.remotePort, format: .number.grouping(.never))
                .frame(width: 60)
            Button(role: .destructive) {
                forwards.removeAll { $0.id == forward.wrappedValue.id }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .padding(.horizontal, 12)
    }

    private var canSave: Bool {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !hostname.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return isDirty
    }

    private var isDirty: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedHostname = hostname.trimmingCharacters(in: .whitespaces)
        let trimmedUser = username.trimmingCharacters(in: .whitespaces)
        let trimmedKey = identityFile.trimmingCharacters(in: .whitespaces)
        let portValue = Int(port.trimmingCharacters(in: .whitespaces)) ?? 22

        if trimmedName != host.displayName { return true }
        if trimmedHostname != (host.connectableHostname ?? host.hostAlias) { return true }
        if trimmedUser != (host.username ?? "") { return true }
        if portValue != (host.port ?? 22) { return true }
        if trimmedKey != (host.identityFile ?? "") { return true }
        if forwards != (host.configForwards + host.portForwards) { return true }
        return false
    }

    private func syncFromHost() {
        displayName = host.displayName
        hostname = host.connectableHostname ?? host.hostAlias
        username = host.username ?? ""
        port = String(host.port ?? 22)
        identityFile = host.identityFile ?? ""
        forwards = host.configForwards + host.portForwards
    }

    private func save() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedHostname = hostname.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedHostname.isEmpty else { return }

        manager.updateHostConnection(
            for: host,
            displayName: trimmedName,
            hostname: trimmedHostname,
            username: username.trimmingCharacters(in: .whitespaces),
            port: Int(port.trimmingCharacters(in: .whitespaces)) ?? 22,
            identityFile: identityFile.trimmingCharacters(in: .whitespaces)
        )
        manager.updatePortForwards(for: host, forwards: forwards)
    }
}
