import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var manager: SessionManager
    @Bindable var terminalSettings: TerminalSettings
    @Bindable var appSettings: AppSettings
    @Bindable var shortcutSettings: ShortcutSettings
    @State private var workspaceSettings = SessionWorkspaceSettings()
    @State private var uiPreferences = SessionUIPreferences()
    @State private var showingConfigPicker = false
    @State private var lastKnownWindowSize: CGSize = .zero
    @State private var shortcutMonitor: ShortcutMonitor?

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
                SessionSettingsPanel(manager: manager)
                .inspectorColumnWidth(min: 220, ideal: 260, max: 320)
            }
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
        .onReceive(NotificationCenter.default.publisher(for: .consoledConnectSelectedHost)) { _ in
            manager.connectSelectedHost()
        }
        .onReceive(NotificationCenter.default.publisher(for: .consoledOpenLocalTerminal)) { _ in
            manager.connectLocal()
        }
        .onReceive(NotificationCenter.default.publisher(for: .consoledCloseSelectedSession)) { _ in
            manager.closeSelectedSession()
        }
        .onAppear {
            manager.applyTerminalOpacity(CGFloat(appSettings.terminalOpacity))
            manager.applyDefaultFontSize(terminalSettings.defaultFontSize)
            manager.applyDefaultTheme(id: terminalSettings.defaultThemeID)
            manager.restoreWorkspaceIfNeeded(
                enabled: appSettings.restoreWorkspaceOnLaunch,
                workspaceSettings: workspaceSettings
            )
            startShortcutMonitor()
        }
        .onChange(of: terminalSettings.defaultFontSize) { _, size in
            manager.applyDefaultFontSize(size)
        }
        .onChange(of: appSettings.terminalOpacity) { _, opacity in
            manager.applyTerminalOpacity(CGFloat(opacity))
        }
        .onDisappear {
            shortcutMonitor?.stop()
            shortcutMonitor = nil
        }
        .background(WindowSizeReader { size in
            lastKnownWindowSize = size
        })
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                persistOnExit()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            persistOnExit()
        }
        .onReceive(NotificationCenter.default.publisher(for: .consoledPersistOnExit)) { _ in
            persistOnExit()
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

    private func startShortcutMonitor() {
        guard shortcutMonitor == nil else { return }
        let monitor = ShortcutMonitor(shortcutSettings: shortcutSettings)
        monitor.start(
            sessionCount: { manager.sessions.count },
            handler: { action in
                if let direction = action.moveDirection {
                    manager.moveSelectedSession(
                        direction,
                        layoutMode: workspaceSettings.layoutMode,
                        isPortrait: workspaceSettings.tileIsPortrait(for: lastKnownWindowSize)
                    )
                } else if action == .fontIncrease {
                    manager.adjustSelectedSessionFontSize(by: 1)
                } else if action == .fontDecrease {
                    manager.adjustSelectedSessionFontSize(by: -1)
                }
            }
        )
        shortcutMonitor = monitor
    }

    private func persistOnExit() {
        // Host/theme edits are persisted the moment they happen, so there is no
        // host config to flush here. Only the transient workspace layout is captured.
        if appSettings.restoreWorkspaceOnLaunch {
            let portrait: Bool? = workspaceSettings.layoutMode == .tiled
                ? workspaceSettings.tileIsPortrait(for: lastKnownWindowSize)
                : nil
            manager.saveWorkspaceSnapshot(
                layoutMode: workspaceSettings.layoutMode,
                tileLayoutIsPortrait: portrait
            )
        } else {
            manager.clearWorkspaceSnapshot()
        }
    }
}

private struct WindowSizeReader: NSViewRepresentable {
    let onChange: (CGSize) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onChange(window.frame.size)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            onChange(window.frame.size)
        }
    }
}

extension Notification.Name {
    static let consoledConnectSelectedHost = Notification.Name("consoledConnectSelectedHost")
    static let consoledOpenLocalTerminal = Notification.Name("consoledOpenLocalTerminal")
    static let consoledCloseSelectedSession = Notification.Name("consoledCloseSelectedSession")
    static let consoledPersistOnExit = Notification.Name("consoledPersistOnExit")
}
