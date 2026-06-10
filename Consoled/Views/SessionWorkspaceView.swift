//
//  Consoled — A lightweight SSH session and terminal window manager for macOS.
//  Copyright (C) 2026 Warrun Lewis
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SessionWorkspaceView: View {
    @Bindable var manager: SessionManager
    @Bindable var terminalSettings: TerminalSettings
    @Bindable var workspaceSettings: SessionWorkspaceSettings
    @Bindable var uiPreferences: SessionUIPreferences
    @Bindable var appSettings: AppSettings

    @State private var pendingClose: TerminalSession?

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
                            description: Text("Double-click a host in the sidebar (or right-click it and choose Connect) to start an SSH session. You can also open a local terminal or a note from the toolbar.")
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
                        SessionTabBar(manager: manager, onClose: requestClose, onSave: saveNote)
                    }

                    ZStack(alignment: .topLeading) {
                        terminalHost

                        if workspaceSettings.layoutMode == .tiled {
                            SessionTiledChrome(
                                manager: manager,
                                workspaceSettings: workspaceSettings,
                                onClose: requestClose,
                                onSave: saveNote
                            )
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

                Menu {
                    Button("New Note") { manager.openNotes() }
                    Button("Open Other…") { openOtherNote() }
                    let recents = recentNotes.prefix(10)
                    if !recents.isEmpty {
                        Section("Recent Notes") {
                            ForEach(recents) { note in
                                Button(note.name) { manager.openNote(fileURL: note.url) }
                            }
                        }
                    }
                } label: {
                    Label("Notes", systemImage: "note.text")
                }
                .help("New note, or reopen a saved note")

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
        .onReceive(NotificationCenter.default.publisher(for: .consoledOpenNotes)) { _ in
            manager.openNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .consoledSaveNote)) { _ in
            if let session = manager.selectedSession, session.isNotes {
                saveNote(session)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .consoledCloseSelectedSession)) { _ in
            if let session = manager.selectedSession {
                requestClose(session)
            }
        }
        .confirmationDialog(
            "Save changes to this note?",
            isPresented: closeDialogPresented,
            titleVisibility: .visible,
            presenting: pendingClose
        ) { session in
            Button("Save…") { saveThenClose(session) }
            Button("Don't Save", role: .destructive) {
                manager.closeSession(session)
                pendingClose = nil
            }
            Button("Cancel", role: .cancel) { pendingClose = nil }
        } message: { _ in
            Text("This note has unsaved changes.")
        }
    }

    private var terminalHost: some View {
        TerminalHostRepresentable(
            sessions: manager.sessions,
            selectedSessionID: manager.selectedSessionID,
            layoutMode: workspaceSettings.layoutMode,
            notesOpacity: CGFloat(appSettings.notesOpacity),
            tileIsPortrait: { workspaceSettings.tileIsPortrait(for: $0) },
            launch: { manager.launch(for: $0) },
            notesDocument: { manager.notesDocument(for: $0) },
            onSelectSession: { sessionID in
                guard let session = manager.sessions.first(where: { $0.id == sessionID }) else { return }
                manager.selectSession(session)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var closeDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingClose != nil },
            set: { if !$0 { pendingClose = nil } }
        )
    }

    /// Confirm before closing a notes session with unsaved changes; everything else closes immediately.
    private func requestClose(_ session: TerminalSession) {
        if session.isNotes, manager.notesDocument(for: session.id)?.needsSaving == true {
            pendingClose = session
        } else {
            manager.closeSession(session)
        }
    }

    private var recentNotes: [NotesStore.SavedNote] {
        NotesStore.listSavedNotes()
    }

    private func openOtherNote() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = NotesStore.defaultDirectory
        var types: [UTType] = [.plainText, .text]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        panel.allowedContentTypes = types
        if panel.runModal() == .OK, let url = panel.url {
            manager.openNote(fileURL: url)
        }
    }

    private func saveNote(_ session: TerminalSession) {
        guard let document = manager.notesDocument(for: session.id) else { return }
        if NotesStore.save(document) {
            manager.markNotesSaved(sessionID: session.id)
        }
    }

    private func saveThenClose(_ session: TerminalSession) {
        defer { pendingClose = nil }
        guard let document = manager.notesDocument(for: session.id) else {
            manager.closeSession(session)
            return
        }
        // Only close if the save actually happened (user may cancel the save panel).
        if NotesStore.save(document) {
            manager.closeSession(session)
        }
    }
}

private struct SessionTabBar: View {
    @Bindable var manager: SessionManager
    let onClose: (TerminalSession) -> Void
    let onSave: (TerminalSession) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(manager.sessions) { session in
                    SessionTabButton(
                        title: session.title,
                        accent: session.terminalTheme.accent,
                        isSelected: manager.selectedSessionID == session.id,
                        showSave: session.isNotes,
                        onSelect: { manager.selectSession(session) },
                        onClose: { onClose(session) },
                        onSave: { onSave(session) }
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
    let showSave: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(nsColor: accent))
                .frame(width: 8, height: 8)

            Text(title)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)

            Spacer(minLength: 0)

            if showSave {
                Button("Save", action: onSave)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Save note")
            }

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
