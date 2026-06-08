import SwiftUI

@main
struct ConsoledApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var manager: SessionManager
    @State private var terminalSettings: TerminalSettings
    @State private var appSettings = AppSettings()
    @State private var shortcutSettings = ShortcutSettings()

    init() {
        TerminalPrewarm.warm()
        let registry = TerminalThemeRegistry()
        let sessionManager = SessionManager(themeRegistry: registry)
        sessionManager.themeRegistry.onPersist = { sessionManager.saveAllPreferences() }
        sessionManager.themeRegistry.onChange = { sessionManager.refreshSessionThemesFromRegistry() }
        _manager = State(initialValue: sessionManager)
        _terminalSettings = State(initialValue: TerminalSettings(themeRegistry: registry))
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                manager: manager,
                terminalSettings: terminalSettings,
                appSettings: appSettings,
                shortcutSettings: shortcutSettings
            )
        }
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    NotificationCenter.default.post(name: .consoledConnectSelectedHost, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("New Local Terminal") {
                    NotificationCenter.default.post(name: .consoledOpenLocalTerminal, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }

            CommandGroup(after: .pasteboard) {
                Button("Close Session") {
                    NotificationCenter.default.post(name: .consoledCloseSelectedSession, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command])
            }
        }

        Settings {
            ConsoledSettingsView(
                manager: manager,
                terminalSettings: terminalSettings,
                appSettings: appSettings,
                shortcutSettings: shortcutSettings
            )
        }
    }
}
