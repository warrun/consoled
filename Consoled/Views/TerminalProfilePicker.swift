import SwiftUI

struct TerminalProfilePicker: View {
    @Binding var selection: TerminalProfile

    var body: some View {
        Picker("Profile", selection: $selection) {
            ForEach(TerminalProfile.allCases) { profile in
                Label {
                    Text(profile.displayName)
                } icon: {
                    Circle()
                        .fill(Color(nsColor: profile.accent))
                        .frame(width: 8, height: 8)
                }
                .tag(profile)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .help("Terminal color profile")
    }
}
