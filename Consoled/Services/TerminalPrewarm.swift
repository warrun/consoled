import AppKit
import SwiftTerm

enum TerminalPrewarm {
    private static var prewarmView: ConsoledTerminalView?

    static func warm() {
        guard prewarmView == nil else { return }
        let view = ConsoledTerminalView(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        let themeID = UserDefaults.standard.string(forKey: "terminalProfileID") ?? BuiltInTerminalThemes.defaultID
        let definition = BuiltInTerminalThemes.all.first { $0.id == themeID } ?? BuiltInTerminalThemes.all[0]
        let theme = TerminalTheme(definition: definition)
        TerminalAppearance.apply(theme, to: view)
        prewarmView = view
    }
}
