import SwiftUI
import UniformTypeIdentifiers

struct ConsoledSettingsView: View {
    @Bindable var manager: SessionManager
    @Bindable var terminalSettings: TerminalSettings
    @Bindable var appSettings: AppSettings

    @State private var showClearHostsWarning = false
    @State private var showClearHostsConfirm = false
    @State private var showingConfigPicker = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            themesTab
                .tabItem { Label("Themes", systemImage: "paintpalette") }

            sshTab
                .tabItem { Label("SSH", systemImage: "lock.shield") }

            workspaceTab
                .tabItem { Label("Workspace", systemImage: "rectangle.split.2x2") }
        }
        .frame(width: 520, height: 380)
        .alert("Clear all hosts?", isPresented: $showClearHostsWarning) {
            Button("Continue", role: .destructive) { showClearHostsConfirm = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every saved host from Consoled. Your ~/.ssh/config file is never modified.")
        }
        .confirmationDialog(
            "Clear all hosts?",
            isPresented: $showClearHostsConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All Hosts", role: .destructive) {
                manager.clearAllHosts()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All hosts will be removed from Consoled. You can add or import them again anytime.")
        }
        .sheet(isPresented: $manager.showConfigConsentSheet) {
            SSHConfigImportConsentSheet(
                defaultPath: SSHConfigImporter.defaultConfigPath,
                onImportDefault: {
                    manager.grantSSHConfigAccess(path: SSHConfigImporter.defaultConfigPath)
                },
                onPickFile: {
                    manager.dismissConfigConsent()
                    showingConfigPicker = true
                },
                onDismiss: {
                    manager.dismissConfigConsent()
                }
            )
        }
        .sheet(isPresented: $manager.showConfigAccessSheet) {
            SSHConfigImportAccessSheet(
                currentPath: manager.importAttemptPath,
                onUseDefault: {
                    manager.grantSSHConfigAccess(path: SSHConfigImporter.defaultConfigPath)
                    manager.showConfigAccessSheet = false
                },
                onPickFile: { showingConfigPicker = true }
            )
        }
        .fileImporter(
            isPresented: $showingConfigPicker,
            allowedContentTypes: [.data, .plainText, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                let bookmark = SSHConfigBookmark.create(for: url)
                manager.grantSSHConfigAccess(path: url.path(percentEncoded: false), bookmark: bookmark)
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
                manager.showConfigAccessSheet = false
            case .failure:
                break
            }
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                TerminalProfilePicker(
                    themes: manager.themeRegistry.allThemes,
                    selectionID: $terminalSettings.defaultThemeID
                )
                Text("Used for new hosts and sessions that don't have a theme set manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Default Terminal Theme")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: terminalSettings.defaultThemeID) { _, themeID in
            manager.applyDefaultTheme(id: themeID)
        }
    }

    private var themesTab: some View {
        ThemeListView(
            themeRegistry: manager.themeRegistry,
            defaultThemeID: terminalSettings.defaultThemeID,
            assignedThemeIDs: manager.assignedThemeIDs,
            onThemesChanged: {
                manager.refreshSessionThemesFromRegistry()
                manager.saveAllPreferences()
            }
        )
        .padding()
    }

    private var sshTab: some View {
        Form {
            Section {
                if manager.hostCount > 0 {
                    Text("\(manager.hostCount) host\(manager.hostCount == 1 ? "" : "s") saved in Consoled.")
                } else {
                    Text("No hosts saved in Consoled.")
                }
                Text("Import copies hosts from ~/.ssh/config into Consoled once. Consoled never reads or modifies that file after import.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Hosts")
            }

            Section {
                Button("Import from SSH Config…") {
                    manager.requestSSHConfigImport()
                }

                if manager.hostCount > 0 {
                    Button("Clear All Hosts…", role: .destructive) {
                        showClearHostsWarning = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var workspaceTab: some View {
        Form {
            Section {
                Toggle("Restore workspace on launch", isOn: $appSettings.restoreWorkspaceOnLaunch)
                Text("Reopens your last layout and sessions when Consoled starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Session Restore")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct SSHConfigImportConsentSheet: View {
    let defaultPath: String
    let onImportDefault: () -> Void
    let onPickFile: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import SSH Config")
                .font(.title2)

            Text("Consoled will read your SSH config once and save host connection details in its own storage. It will not modify your SSH config file.")
                .foregroundStyle(.secondary)

            Text(defaultPath)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            HStack {
                Button("Not Now", action: onDismiss)
                Spacer()
                Button("Choose a Different File…", action: onPickFile)
                Button("Import from Default", action: onImportDefault)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

struct SSHConfigImportAccessSheet: View {
    let currentPath: String
    let onUseDefault: () -> Void
    let onPickFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SSH Config Access")
                .font(.title2)

            Text("Consoled could not read your SSH config at:")
                .foregroundStyle(.secondary)

            Text(currentPath)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            Text("Choose your ~/.ssh/config file, or retry the default location.")
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Choose Config File…", action: onPickFile)
                Button("Retry Default", action: onUseDefault)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
