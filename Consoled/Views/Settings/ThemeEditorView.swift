import SwiftUI
import AppKit

/// One editable theme row: a live accent-color well, an editable name field, and an
/// optional delete button (custom themes only). Each row owns local state seeded from
/// its definition; because rows are addressed by stable identity in the list, the
/// fields never desync the way a shared master/detail editor did.
struct ThemeEditorRow: View {
    let definition: TerminalThemeDefinition
    let isDeletable: Bool
    let onCommit: (TerminalThemeDefinition) -> Void
    let onRequestDelete: () -> Void

    @State private var name: String
    @State private var accent: Color

    init(
        definition: TerminalThemeDefinition,
        isDeletable: Bool,
        onCommit: @escaping (TerminalThemeDefinition) -> Void,
        onRequestDelete: @escaping () -> Void
    ) {
        self.definition = definition
        self.isDeletable = isDeletable
        self.onCommit = onCommit
        self.onRequestDelete = onRequestDelete
        _name = State(initialValue: definition.displayName)
        _accent = State(initialValue: definition.accent.swiftUIColor)
    }

    var body: some View {
        HStack(spacing: 12) {
            ColorPicker("Accent color", selection: $accent, supportsOpacity: false)
                .labelsHidden()

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            if isDeletable {
                Button(role: .destructive, action: onRequestDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Delete theme")
            }
        }
        .onChange(of: name) { _, _ in commit() }
        .onChange(of: accent) { _, _ in commit() }
    }

    private func commit() {
        var updated = definition
        updated.displayName = name
        updated.accent = CodableColor(nsColor: NSColor(accent))
        onCommit(updated)
    }
}
