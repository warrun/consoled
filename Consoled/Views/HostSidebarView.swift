import SwiftUI

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
            ToolbarItemGroup {
                Button {
                    showingAddHost = true
                } label: {
                    Label("Add Host", systemImage: "plus")
                }

                Button {
                    manager.connectSelectedHost()
                } label: {
                    Label("Connect", systemImage: "terminal")
                }
                .disabled(manager.selectedHost == nil)
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
