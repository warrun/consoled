import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var manager = SessionManager()
    @State private var terminalSettings = TerminalSettings()
    @State private var workspaceSettings = SessionWorkspaceSettings()
    @State private var uiPreferences = SessionUIPreferences()
    @State private var showingConfigPicker = false

    var body: some View {
        NavigationSplitView {
            HostSidebarView(
                manager: manager,
                onOpenHostSettings: openHostSettings
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            SessionWorkspaceView(
                manager: manager,
                terminalSettings: terminalSettings,
                workspaceSettings: workspaceSettings,
                uiPreferences: uiPreferences
            )
            .inspector(isPresented: settingsInspectorBinding) {
                SessionSettingsPanel(
                    manager: manager,
                    onPickSSHConfig: { showingConfigPicker = true },
                    onResetSSHConfig: { manager.resetSSHConfigToDefault() }
                )
                .inspectorColumnWidth(min: 220, ideal: 260, max: 320)
            }
        }
        .sheet(isPresented: $manager.showConfigConsentSheet) {
            SSHConfigConsentSheet(
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
            ConfigAccessSheet(
                currentPath: manager.configPath,
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
                manager.grantSSHConfigAccess(path: url.path(), bookmark: bookmark)
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
                manager.showConfigAccessSheet = false
            case .failure:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .consoledConnectSelectedHost)) { _ in
            manager.connectSelectedHost()
        }
        .onReceive(NotificationCenter.default.publisher(for: .consoledCloseSelectedSession)) { _ in
            manager.closeSelectedSession()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                manager.saveAllPreferences()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            manager.saveAllPreferences()
        }
        .standardWindowChrome()
    }

    private var settingsInspectorBinding: Binding<Bool> {
        $uiPreferences.isSettingsPanelVisible
    }

    private func openHostSettings(_ host: SSHHostProfile) {
        manager.selectHost(host)
        uiPreferences.showSettingsPanel()
    }
}

private struct SSHConfigConsentSheet: View {
    let defaultPath: String
    let onImportDefault: () -> Void
    let onPickFile: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import SSH Config")
                .font(.title2)

            Text("Consoled can read your SSH config to list saved hosts. It will not modify the file.")
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

private struct ConfigAccessSheet: View {
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

extension Notification.Name {
    static let consoledConnectSelectedHost = Notification.Name("consoledConnectSelectedHost")
    static let consoledCloseSelectedSession = Notification.Name("consoledCloseSelectedSession")
}
