import AppKit
import SwiftTerm

struct TerminalTheme: Identifiable, Hashable {
    let definition: TerminalThemeDefinition
    let fontSize: CGFloat
    let backgroundOpacity: CGFloat

    var id: String { definition.id }
    var displayName: String { definition.displayName }
    var accent: NSColor { definition.accent.nsColor }
    var isBuiltIn: Bool { definition.isBuiltIn }

    /// Inset between the rounded panel edge and the character grid.
    static let textPadding: CGFloat = 10
    static let panelCornerRadius: CGFloat = 8
    static let defaultBackgroundOpacity: CGFloat = 0.77
    static let defaultFontSize: CGFloat = 12
    static let minFontSize: CGFloat = 8
    static let maxFontSize: CGFloat = 40

    init(
        definition: TerminalThemeDefinition,
        fontSize: CGFloat = TerminalTheme.defaultFontSize,
        backgroundOpacity: CGFloat = TerminalTheme.defaultBackgroundOpacity
    ) {
        self.definition = definition
        self.fontSize = fontSize
        self.backgroundOpacity = backgroundOpacity
    }

    func withFontSize(_ size: CGFloat) -> TerminalTheme {
        TerminalTheme(definition: definition, fontSize: size, backgroundOpacity: backgroundOpacity)
    }

    func withBackgroundOpacity(_ opacity: CGFloat) -> TerminalTheme {
        TerminalTheme(definition: definition, fontSize: fontSize, backgroundOpacity: opacity)
    }

    var background: NSColor {
        NSColor.black.withAlphaComponent(backgroundOpacity)
    }

    var selection: NSColor {
        NSColor(calibratedRed: 0, green: 0, blue: 0.666, alpha: 0.5)
    }

    var font: NSFont {
        let candidates = ["Andale Mono", "Menlo", "Monaco"]
        for name in candidates {
            if let font = NSFont(name: name, size: fontSize) {
                return font
            }
        }
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    var ansiPalette: [Color] {
        Self.standardANSIPalette.map(TerminalColorConversion.terminalColor)
    }

    private static let standardANSIPalette: [NSColor] = [
        NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1),
        NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1),
        NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1),
        NSColor(calibratedRed: 1, green: 1, blue: 0, alpha: 1),
        NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1),
        NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1),
        NSColor(calibratedRed: 0, green: 1, blue: 1, alpha: 1),
        NSColor.white,
        NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1),
        NSColor(calibratedRed: 1, green: 0.3, blue: 0.3, alpha: 1),
        NSColor(calibratedRed: 0.3, green: 1, blue: 0.3, alpha: 1),
        NSColor(calibratedRed: 1, green: 1, blue: 0.3, alpha: 1),
        NSColor(calibratedRed: 0.3, green: 0.3, blue: 1, alpha: 1),
        NSColor(calibratedRed: 1, green: 0.3, blue: 1, alpha: 1),
        NSColor(calibratedRed: 0.3, green: 1, blue: 1, alpha: 1),
        NSColor.white,
    ]
}
