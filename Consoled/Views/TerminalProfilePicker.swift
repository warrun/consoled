import SwiftUI

struct TerminalProfilePicker: View {
    let themes: [TerminalTheme]
    @Binding var selectionID: String

    var body: some View {
        Picker("Profile", selection: $selectionID) {
            ForEach(themes) { theme in
                Label {
                    Text(theme.displayName)
                } icon: {
                    Circle()
                        .fill(Color(nsColor: theme.accent))
                        .frame(width: 8, height: 8)
                }
                .tag(theme.id)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .help("Terminal color profile")
    }
}
