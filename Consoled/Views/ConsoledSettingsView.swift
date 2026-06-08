import SwiftUI
import UniformTypeIdentifiers

struct ConsoledSettingsView: View {
    @Bindable var manager: SessionManager
    @Bindable var terminalSettings: TerminalSettings
    @Bindable var appSettings: AppSettings
    @Bindable var shortcutSettings: ShortcutSettings

    @State private var showClearHostsWarning = false
    @State private var showClearHostsConfirm = false
    @State private var showingConfigPicker = false
    @State private var showResetShortcutsConfirm = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            themesTab
                .tabItem { Label("Themes", systemImage: "paintpalette") }

            sshTab
                .tabItem { Label("SSH", systemImage: "lock.shield") }
        }
        .frame(width: 620, height: 640)
        .alert("Reset shortcuts?", isPresented: $showResetShortcutsConfirm) {
            Button("Reset", role: .destructive) { shortcutSettings.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restore the default ⇧⌘ + arrow keys for reordering sessions.")
        }
        .alert("Clear all hosts?", isPresented: $showClearHostsWarning) {
            Button("Continue", role: .destructive) { showClearHostsConfirm = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every saved host from Consoled. Your ~/.ssh/config file is never modified.")
        }
        .confirmationDialog(
            "Clear all hosts?",
            isPresented: $showClearHostsConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All Hosts", role: .destructive) {
                manager.clearAllHosts()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All hosts will be removed from Consoled. You can add or import them again anytime.")
        }
        .sheet(isPresented: $manager.showConfigConsentSheet) {
            SSHConfigImportConsentSheet(
                defaultPath: SSHConfigImporter.defaultConfigPath,
                onImportDefault: {
                    manager.grantSSHConfigAccess(path: SSHConfigImporter.defaultConfigPath)
                },
                onPickFile: {
                    manager.dismissConfigConsent()
                    showingConfigPicker = true
                },
                onDismiss: {
                    manager.dismissConfigConsent()
                }
            )
        }
        .sheet(isPresented: $manager.showConfigAccessSheet) {
            SSHConfigImportAccessSheet(
                currentPath: manager.importAttemptPath,
                onUseDefault: {
                    manager.grantSSHConfigAccess(path: SSHConfigImporter.defaultConfigPath)
                    manager.showConfigAccessSheet = false
                },
                onPickFile: { showingConfigPicker = true }
            )
        }
        .fileImporter(
            isPresented: $showingConfigPicker,
            allowedContentTypes: [.data, .plainText, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                let bookmark = SSHConfigBookmark.create(for: url)
                manager.grantSSHConfigAccess(path: url.path(percentEncoded: false), bookmark: bookmark)
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
                manager.showConfigAccessSheet = false
            case .failure:
                break
            }
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Restore workspace on launch", isOn: $appSettings.restoreWorkspaceOnLaunch)
                Text("Reopens your last layout and sessions when Consoled starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Session Restore")
            }

            Section {
                Stepper(
                    "Default font size: \(Int(terminalSettings.defaultFontSize)) pt",
                    value: $terminalSettings.defaultFontSize,
                    in: TerminalTheme.minFontSize...TerminalTheme.maxFontSize,
                    step: 1
                )
                Text("New sessions and hosts without their own size use this. Set a per-host size in the session settings panel, or ⌘⇧+ / ⌘⇧− to resize the focused session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                opacitySlider(
                    "Terminal opacity",
                    value: $appSettings.terminalOpacity,
                    range: AppSettings.minTerminalOpacity...1.0
                )
            } header: {
                Text("Appearance")
            }

            Section {
                shortcutRow(.moveLeft)
                shortcutRow(.moveRight)
                shortcutRow(.moveUp)
                shortcutRow(.moveDown)
                shortcutRow(.fontIncrease)
                shortcutRow(.fontDecrease)

                VStack(alignment: .leading, spacing: 4) {
                    Text("**Tabs view:** Move Left/Right shift the selected tab one position; Up/Down are unused.")
                    Text("**Tiled view:** all four directions swap the selected tile with its neighbour.")
                    Text("**Font Size +/−** resize the focused tab or tile.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Button("Reset to Defaults…") {
                    showResetShortcutsConfirm = true
                }
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("Click a shortcut, then press the keys you want. At least one modifier (⌘ ⌥ ⌃ ⇧) is required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        HStack {
            Text(action.label)
            Spacer()
            ShortcutRecorderField(action: action, shortcutSettings: shortcutSettings)
                .frame(width: 150, height: 24)
        }
    }

    private func opacitySlider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(label)
            Slider(value: value, in: range)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var themesTab: some View {
        ThemeListView(
            manager: manager,
            terminalSettings: terminalSettings
        )
    }

    private var sshTab: some View {
        Form {
            Section {
                if manager.hostCount > 0 {
                    Text("\(manager.hostCount) host\(manager.hostCount == 1 ? "" : "s") saved in Consoled.")
                } else {
                    Text("No hosts saved in Consoled.")
                }
                Text("Import copies hosts from ~/.ssh/config into Consoled once. Consoled never reads or modifies that file after import.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Hosts")
            }

            Section {
                Button("Import from SSH Config…") {
                    manager.requestSSHConfigImport()
                }

                if manager.hostCount > 0 {
                    Button("Clear All Hosts…", role: .destructive) {
                        showClearHostsWarning = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct SSHConfigImportConsentSheet: View {
    let defaultPath: String
    let onImportDefault: () -> Void
    let onPickFile: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import SSH Config")
                .font(.title2)

            Text("Consoled will read your SSH config once and save host connection details in its own storage. It will not modify your SSH config file.")
                .foregroundStyle(.secondary)

            Text(defaultPath)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            HStack {
                Button("Not Now", action: onDismiss)
                Spacer()
                Button("Choose a Different File…", action: onPickFile)
                Button("Import from Default", action: onImportDefault)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

struct SSHConfigImportAccessSheet: View {
    let currentPath: String
    let onUseDefault: () -> Void
    let onPickFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SSH Config Access")
                .font(.title2)

            Text("Consoled could not read your SSH config at:")
                .foregroundStyle(.secondary)

            Text(currentPath)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            Text("Choose your ~/.ssh/config file, or retry the default location.")
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Choose Config File…", action: onPickFile)
                Button("Retry Default", action: onUseDefault)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
