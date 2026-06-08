import Foundation

@Observable
@MainActor
final class TerminalSettings {
    private static let profileKey = "terminalProfileID"

    private let themeRegistry: TerminalThemeRegistry

    var defaultThemeID: String {
        didSet {
            guard defaultThemeID != oldValue else { return }
            save()
            onChange?()
        }
    }

    var onChange: (() -> Void)?

    var defaultTheme: TerminalTheme {
        themeRegistry.theme(id: defaultThemeID) ?? themeRegistry.defaultTheme()
    }

    init(themeRegistry: TerminalThemeRegistry) {
        self.themeRegistry = themeRegistry
        if let id = UserDefaults.standard.string(forKey: Self.profileKey),
           themeRegistry.theme(id: id) != nil {
            defaultThemeID = id
        } else {
            defaultThemeID = BuiltInTerminalThemes.defaultID
        }
    }

    private func save() {
        UserDefaults.standard.set(defaultThemeID, forKey: Self.profileKey)
    }
}
