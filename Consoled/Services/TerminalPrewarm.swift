import AppKit
import SwiftTerm

enum TerminalPrewarm {
    private static var prewarmView: ConsoledTerminalView?

    static func warm() {
        guard prewarmView == nil else { return }
        let view = ConsoledTerminalView(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        let profile: TerminalProfile = {
            if let id = UserDefaults.standard.string(forKey: "terminalProfileID"),
               let saved = TerminalProfile(id: id) {
                return saved
            }
            return .homebrew
        }()
        TerminalAppearance.apply(profile, to: view)
        prewarmView = view
    }
}
