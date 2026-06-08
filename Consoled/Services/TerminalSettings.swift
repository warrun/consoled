import Foundation

@Observable
@MainActor
final class TerminalSettings {
    private static let profileKey = "terminalProfileID"
    private static let fontSizeKey = "defaultTerminalFontSize"

    private let themeRegistry: TerminalThemeRegistry

    var defaultThemeID: String {
        didSet {
            guard defaultThemeID != oldValue else { return }
            save()
            onChange?()
        }
    }

    var defaultFontSize: CGFloat {
        didSet {
            let clamped = min(max(defaultFontSize, TerminalTheme.minFontSize), TerminalTheme.maxFontSize)
            if clamped != defaultFontSize {
                defaultFontSize = clamped
                return
            }
            guard defaultFontSize != oldValue else { return }
            UserDefaults.standard.set(Double(defaultFontSize), forKey: Self.fontSizeKey)
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

        let storedFont = UserDefaults.standard.object(forKey: Self.fontSizeKey) as? Double
        let resolvedFont = storedFont.map { CGFloat($0) } ?? TerminalTheme.defaultFontSize
        defaultFontSize = min(max(resolvedFont, TerminalTheme.minFontSize), TerminalTheme.maxFontSize)
    }

    private func save() {
        UserDefaults.standard.set(defaultThemeID, forKey: Self.profileKey)
    }
}
