import SwiftUI

struct ThemeListView: View {
    @Bindable var themeRegistry: TerminalThemeRegistry
    let defaultThemeID: String
    let assignedThemeIDs: Set<String>
    let onThemesChanged: () -> Void

    @State private var selectedThemeID: String?
    @State private var editorDefinition: TerminalThemeDefinition?

    var body: some View {
        HSplitView {
            List(selection: $selectedThemeID) {
                ForEach(themeRegistry.allThemes) { theme in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(nsColor: theme.accent))
                            .frame(width: 10, height: 10)
                        Text(theme.displayName)
                    }
                    .tag(theme.id as String?)
                }
            }
            .frame(minWidth: 180)

            Group {
                if let editorDefinition {
                    ThemeEditorView(
                        definition: editorDefinition,
                        themeRegistry: themeRegistry,
                        defaultThemeID: defaultThemeID,
                        assignedThemeIDs: assignedThemeIDs,
                        onUpdated: {
                            onThemesChanged()
                            if let selectedThemeID,
                               themeRegistry.theme(id: selectedThemeID) == nil {
                                self.selectedThemeID = themeRegistry.allThemes.first?.id
                            }
                            syncEditorSelection()
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "Select a Theme",
                        systemImage: "paintpalette",
                        description: Text("Choose a theme to edit its name and accent color.")
                    )
                }
            }
            .frame(minWidth: 240)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    let created = themeRegistry.createCustom()
                    selectedThemeID = created.id
                    editorDefinition = created
                    onThemesChanged()
                } label: {
                    Label("Add Theme", systemImage: "plus")
                }
            }
        }
        .onAppear { syncEditorSelection() }
        .onChange(of: selectedThemeID) { _, _ in syncEditorSelection() }
        .onChange(of: themeRegistry.allThemes.count) { _, _ in syncEditorSelection() }
    }

    private func syncEditorSelection() {
        guard let selectedThemeID,
              let theme = themeRegistry.theme(id: selectedThemeID) else {
            editorDefinition = nil
            return
        }
        editorDefinition = theme.definition
    }
}
