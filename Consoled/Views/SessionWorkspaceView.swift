import AppKit
import SwiftUI

struct SessionWorkspaceView: View {
    @Bindable var manager: SessionManager
    @Bindable var terminalSettings: TerminalSettings
    @Bindable var workspaceSettings: SessionWorkspaceSettings
    @Bindable var uiPreferences: SessionUIPreferences

    var body: some View {
        ZStack {
            WindowVisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if manager.sessions.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "No Sessions",
                            systemImage: "terminal",
                            description: Text("Select a host and click Connect, double-click a host in the sidebar, or open a local terminal.")
                        )
                        Button {
                            manager.connectLocal()
                        } label: {
                            Label("Open Local Terminal", systemImage: "apple.terminal")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if workspaceSettings.layoutMode == .tabs {
                        SessionTabBar(manager: manager)
                    }

                    ZStack(alignment: .topLeading) {
                        terminalHost

                        if workspaceSettings.layoutMode == .tiled {
                            SessionTiledChrome(manager: manager, workspaceSettings: workspaceSettings)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .navigationTitle(manager.selectedSession?.title ?? "Consoled")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    manager.connectLocal()
                } label: {
                    Label("Local Terminal", systemImage: "apple.terminal")
                }
                .help("Open a local terminal session")

                if !manager.sessions.isEmpty {
                    Picker("Layout", selection: $workspaceSettings.layoutMode) {
                        Label("Tabs", systemImage: "square.on.square")
                            .tag(SessionLayoutMode.tabs)
                        Label("Tiled", systemImage: "rectangle.split.2x2")
                            .tag(SessionLayoutMode.tiled)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .help("Switch between tabs and tiled layout")
                }

                Button {
                    uiPreferences.isSettingsPanelVisible.toggle()
                } label: {
                    Label("Settings", systemImage: "sidebar.right")
                }
                .help("Toggle settings panel")
            }
        }
        .onAppear {
            manager.defaultTerminalTheme = terminalSettings.defaultTheme
        }
        .onChange(of: terminalSettings.defaultThemeID) { _, themeID in
            manager.applyDefaultTheme(id: themeID)
        }
    }

    private var terminalHost: some View {
        TerminalHostRepresentable(
            sessions: manager.sessions,
            selectedSessionID: manager.selectedSessionID,
            layoutMode: workspaceSettings.layoutMode,
            tileIsPortrait: { workspaceSettings.tileIsPortrait(for: $0) },
            launch: { manager.launch(for: $0) },
            onSelectSession: { sessionID in
                guard let session = manager.sessions.first(where: { $0.id == sessionID }) else { return }
                manager.selectSession(session)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SessionTabBar: View {
    @Bindable var manager: SessionManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(manager.sessions) { session in
                    SessionTabButton(
                        title: session.title,
                        accent: session.terminalTheme.accent,
                        isSelected: manager.selectedSessionID == session.id,
                        onSelect: { manager.selectSession(session) },
                        onClose: { manager.closeSession(session) }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Color.black.opacity(0.72)
            }
        }
    }
}

private struct SessionTabButton: View {
    let title: String
    let accent: NSColor
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(nsColor: accent))
                .frame(width: 8, height: 8)

            Text(title)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Close session")
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
