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

import SwiftUI

struct ThemeListView: View {
    @Bindable var manager: SessionManager
    @Bindable var terminalSettings: TerminalSettings

    @State private var pendingDelete: TerminalThemeDefinition?

    private var registry: TerminalThemeRegistry { manager.themeRegistry }

    var body: some View {
        Form {
            Section {
                TerminalProfilePicker(
                    themes: registry.allThemes,
                    selectionID: $terminalSettings.defaultThemeID
                )
                Text("Used for new hosts and sessions that don't have a theme set manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Default Terminal Theme")
            }

            Section {
                ForEach(registry.allThemes) { theme in
                    ThemeEditorRow(
                        definition: theme.definition,
                        isDeletable: !theme.isBuiltIn,
                        onCommit: { registry.update($0) },
                        onRequestDelete: { pendingDelete = theme.definition }
                    )
                    .id(theme.id)
                }

                Button {
                    _ = registry.createCustom()
                } label: {
                    Label("Add Theme", systemImage: "plus")
                }
            } header: {
                Text("Themes")
            }
        }
        .formStyle(.grouped)
        .onChange(of: terminalSettings.defaultThemeID) { _, id in
            manager.applyDefaultTheme(id: id)
        }
        .confirmationDialog(
            "Delete Theme?",
            isPresented: deleteDialogPresented,
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { theme in
            Button("Delete Theme", role: .destructive) { performDelete(theme) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { theme in
            Text(deleteMessage(for: theme))
        }
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    private func hostsUsing(_ id: String) -> Int {
        manager.hosts.filter { $0.themeID == id }.count
    }

    private func deleteMessage(for theme: TerminalThemeDefinition) -> String {
        let count = hostsUsing(theme.id)
        guard count > 0 else {
            return "\"\(theme.displayName)\" will be permanently removed."
        }
        let hostWord = count == 1 ? "host" : "hosts"
        let target = count == 1 ? "that host" : "those hosts"
        return "\"\(theme.displayName)\" is assigned to \(count) \(hostWord). "
            + "Deleting it will revert \(target) to the default theme."
    }

    private func performDelete(_ theme: TerminalThemeDefinition) {
        // Revert hosts first so the theme is no longer in use, then reset the app
        // default if it pointed here — both preconditions registry.delete enforces.
        manager.revertHostsToDefaultTheme(themeID: theme.id)
        if terminalSettings.defaultThemeID == theme.id {
            terminalSettings.defaultThemeID = BuiltInTerminalThemes.defaultID
        }
        try? registry.delete(
            id: theme.id,
            defaultThemeID: terminalSettings.defaultThemeID,
            hostThemeIDs: manager.assignedThemeIDs
        )
        pendingDelete = nil
    }
}
