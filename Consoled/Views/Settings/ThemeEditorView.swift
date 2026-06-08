import SwiftUI

struct ThemeEditorView: View {
    @Bindable var themeRegistry: TerminalThemeRegistry
    let defaultThemeID: String
    let assignedThemeIDs: Set<String>

    @State private var definition: TerminalThemeDefinition
    @State private var accentColor: Color
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    let onUpdated: () -> Void

    init(
        definition: TerminalThemeDefinition,
        themeRegistry: TerminalThemeRegistry,
        defaultThemeID: String,
        assignedThemeIDs: Set<String>,
        onUpdated: @escaping () -> Void
    ) {
        self.definition = definition
        self.themeRegistry = themeRegistry
        self.defaultThemeID = defaultThemeID
        self.assignedThemeIDs = assignedThemeIDs
        self.onUpdated = onUpdated
        _accentColor = State(initialValue: definition.accent.swiftUIColor)
    }

    var body: some View {
        Form {
            Section("Theme") {
                TextField("Name", text: $definition.displayName)
                    .onSubmit { commit() }

                ColorPicker("Accent color", selection: $accentColor, supportsOpacity: false)
                    .onChange(of: accentColor) { _, _ in commit() }
            }

            if !definition.isBuiltIn {
                Section {
                    Button("Delete Theme", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .disabled(!themeRegistry.canDelete(
                        id: definition.id,
                        defaultThemeID: defaultThemeID,
                        hostThemeIDs: assignedThemeIDs
                    ))
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: definition.displayName) { _, _ in commit() }
        .onDisappear { commit() }
        .alert("Delete Theme?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteTheme() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This theme will be permanently removed.")
        }
        .alert("Cannot Delete Theme", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func commit() {
        definition.accent = CodableColor(nsColor: NSColor(accentColor))
        themeRegistry.update(definition)
        onUpdated()
    }

    private func deleteTheme() {
        do {
            try themeRegistry.delete(
                id: definition.id,
                defaultThemeID: defaultThemeID,
                hostThemeIDs: assignedThemeIDs
            )
            onUpdated()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}
