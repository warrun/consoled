import SwiftUI
import UniformTypeIdentifiers

struct HostEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var hostname = ""
    @State private var username = ""
    @State private var port = "22"
    @State private var identityFile = ""
    @State private var showingKeyPicker = false

    let onSave: (SSHHostProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Host")
                .font(.title2)

            Form {
                TextField("Display name", text: $displayName)
                TextField("Hostname", text: $hostname)
                TextField("Username", text: $username)
                TextField("Port", text: $port)
                HStack {
                    TextField("Identity file (optional)", text: $identityFile)
                    Button("Choose…") { showingKeyPicker = true }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 420)
        .fileImporter(
            isPresented: $showingKeyPicker,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                identityFile = url.path(percentEncoded: false)
            }
        }
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !hostname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedHost = hostname.trimmingCharacters(in: .whitespaces)
        let trimmedUser = username.trimmingCharacters(in: .whitespaces)
        let trimmedKey = identityFile.trimmingCharacters(in: .whitespaces)
        let parsedPort = Int(port.trimmingCharacters(in: .whitespaces)) ?? 22

        let profile = SSHHostProfile(
            displayName: trimmedName,
            hostAlias: trimmedName,
            hostname: trimmedHost,
            username: trimmedUser.isEmpty ? nil : trimmedUser,
            port: parsedPort,
            identityFile: trimmedKey.isEmpty ? nil : trimmedKey
        )

        onSave(profile)
        dismiss()
    }
}
