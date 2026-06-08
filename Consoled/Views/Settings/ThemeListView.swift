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
