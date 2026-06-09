import AppKit
import SwiftUI

/// Native prompts for SCP send/get, kept out of the view body.
@MainActor
enum HostTransferPrompt {
    static func send(host: SSHHostProfile, manager: SessionManager) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose a file or folder to send to \(host.displayName)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let remote = promptText(
            title: "Send to \(host.displayName)",
            message: "Remote destination path:",
            defaultValue: "~/"
        ) else { return }
        manager.openSCPSend(to: host, localPath: url.path(percentEncoded: false), remotePath: remote)
    }

    static func get(host: SSHHostProfile, manager: SessionManager) {
        guard let remote = promptText(
            title: "Get from \(host.displayName)",
            message: "Remote path to download:",
            defaultValue: "~/"
        ) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Destination"
        panel.message = "Choose a local folder to download into"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        manager.openSCPGet(to: host, remotePath: remote, localPath: url.path(percentEncoded: false))
    }

    private static func promptText(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}

struct HostSidebarView: View {
    @Bindable var manager: SessionManager
    var onOpenHostSettings: (SSHHostProfile) -> Void
    @State private var showingAddHost = false
    @State private var searchText = ""

    private var filteredHosts: [SSHHostProfile] {
        guard !searchText.isEmpty else { return manager.hosts }
        return manager.hosts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if filteredHosts.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredHosts) { host in
                        HostSelectableRow(
                            host: host,
                            isSelected: manager.selectedHostID == host.id,
                            onSelect: { manager.selectHost(host) },
                            onConnect: { manager.connect(to: host) },
                            onOpenSettings: { onOpenHostSettings(host) }
                        )
                        .contextMenu {
                            Button("Connect") {
                                manager.connect(to: host)
                            }
                            Button("Open SFTP") {
                                manager.openSFTP(to: host)
                            }
                            Button("Send File…") {
                                HostTransferPrompt.send(host: host, manager: manager)
                            }
                            Button("Get File…") {
                                HostTransferPrompt.get(host: host, manager: manager)
                            }
                            Divider()
                            Button("Settings") {
                                onOpenHostSettings(host)
                            }
                            Button("Delete", role: .destructive) {
                                manager.deleteHost(host)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Consoled")
        .searchable(text: $searchText, prompt: "Filter hosts")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    showingAddHost = true
                } label: {
                    Label("Add Host", systemImage: "plus")
                }

                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Consoled settings")
            }
        }
        .sheet(isPresented: $showingAddHost) {
            HostEditorSheet { profile in
                manager.addHost(profile)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "No Hosts",
                systemImage: "server.rack",
                description: Text(emptyStateDescription)
            )

            if !manager.hasSavedHosts {
                Button("Import from SSH Config…") {
                    manager.requestSSHConfigImport()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyStateDescription: String {
        if let importError = manager.importError {
            return importError
        }
        return "Add a host or import from your SSH config."
    }
}

private struct HostSelectableRow: View {
    let host: SSHHostProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onConnect: () -> Void
    let onOpenSettings: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            HostRow(host: host)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .overlay {
                    HostRowMouseHandler(onSingleClick: onSelect, onDoubleClick: onConnect)
                }

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Host settings")
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        }
        if isHovered {
            return Color.primary.opacity(0.06)
        }
        return Color.clear
    }
}

private struct HostRow: View {
    let host: SSHHostProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(host.displayName)
                .font(.headline)
            Text(host.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
