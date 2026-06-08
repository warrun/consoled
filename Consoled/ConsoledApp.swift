import SwiftUI

@main
struct ConsoledApp: App {
    init() {
        TerminalPrewarm.warm()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") {
                    NotificationCenter.default.post(name: .consoledConnectSelectedHost, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command])
            }

            CommandGroup(after: .pasteboard) {
                Button("Close Session") {
                    NotificationCenter.default.post(name: .consoledCloseSelectedSession, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command])
            }
        }
    }
}
