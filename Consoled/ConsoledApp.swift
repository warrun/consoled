import AppKit
import SwiftUI

@main
struct ConsoledApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var manager: SessionManager
    @State private var terminalSettings: TerminalSettings
    @State private var appSettings = AppSettings()
    @State private var shortcutSettings = ShortcutSettings()
    @StateObject private var updaterModel = UpdaterViewModel()

    init() {
        TerminalPrewarm.warm()
        let registry = TerminalThemeRegistry()
        let sessionManager = SessionManager(themeRegistry: registry)
        sessionManager.themeRegistry.onPersist = { sessionManager.saveAllPreferences() }
        sessionManager.themeRegistry.onChange = { sessionManager.refreshSessionThemesFromRegistry() }
        _manager = State(initialValue: sessionManager)
        _terminalSettings = State(initialValue: TerminalSettings(themeRegistry: registry))
        AppServices.sessionManager = sessionManager
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
            CommandGroup(replacing: .appInfo) {
                Button("About Consoled") {
                    ConsoledApp.showAboutPanel()
                }
            }

            CommandGroup(after: .appInfo) {
                CheckForUpdatesCommand(model: updaterModel)
            }

            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    NotificationCenter.default.post(name: .consoledConnectSelectedHost, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("New Local Terminal") {
                    NotificationCenter.default.post(name: .consoledOpenLocalTerminal, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("New Note") {
                    NotificationCenter.default.post(name: .consoledOpenNotes, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save Note") {
                    NotificationCenter.default.post(name: .consoledSaveNote, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command])
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

    /// Standard macOS About panel. The app name, version, and copyright (incl. the
    /// year, kept current by scripts/release.sh) come from Info.plist; the credits add
    /// the app description, the GPL-3.0 notice, a licence link, and the contact email.
    private static func showAboutPanel() {
        let font = NSFont.systemFont(ofSize: 11)
        let bold = NSFont.systemFont(ofSize: 11, weight: .semibold)

        let credits = NSMutableAttributedString()
        credits.append(NSAttributedString(
            string: "A lightweight SSH session and terminal window manager for macOS.\n\n",
            attributes: [.font: bold, .foregroundColor: NSColor.labelColor]
        ))
        credits.append(NSAttributedString(
            string: "Consoled comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it under the terms of the ",
            attributes: [.font: font, .foregroundColor: NSColor.labelColor]
        ))
        credits.append(NSAttributedString(
            string: "GNU General Public License, version 3",
            attributes: [.font: font, .link: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html") as Any]
        ))
        credits.append(NSAttributedString(
            string: ".\n\nContact: ",
            attributes: [.font: font, .foregroundColor: NSColor.labelColor]
        ))
        credits.append(NSAttributedString(
            string: "development@war.run",
            attributes: [.font: font, .link: URL(string: "mailto:development@war.run") as Any]
        ))

        // Center the whole credits block (the panel left-aligns it by default).
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))

        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
