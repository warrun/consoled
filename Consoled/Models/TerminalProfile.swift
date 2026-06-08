import AppKit
import SwiftTerm

enum TerminalProfile: String, CaseIterable, Identifiable, Codable, Hashable {
    case homebrew
    case homebrewBlue
    case homebrewRed
    case homebrewPurple
    case homebrewYellow
    case homebrewCyan
    case homebrewOrange
    case homebrewWhite

    /// Inset between the rounded panel edge and the character grid.
    static let textPadding: CGFloat = 10
    static let panelCornerRadius: CGFloat = 8
    static let backgroundAlpha: CGFloat = 0.77
    static let fontSize: CGFloat = 12

    var id: String { rawValue }

    init?(id: String) {
        self.init(rawValue: id)
    }

    var displayName: String {
        switch self {
        case .homebrew: "Homebrew"
        case .homebrewBlue: "Homebrew Blue"
        case .homebrewRed: "Homebrew Red"
        case .homebrewPurple: "Homebrew Purple"
        case .homebrewYellow: "Homebrew Yellow"
        case .homebrewCyan: "Homebrew Cyan"
        case .homebrewOrange: "Homebrew Orange"
        case .homebrewWhite: "Homebrew White"
        }
    }

    var accent: NSColor {
        switch self {
        case .homebrew:
            NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1)
        case .homebrewBlue:
            NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1)
        case .homebrewRed:
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
        case .homebrewPurple:
            NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1)
        case .homebrewYellow:
            NSColor(calibratedRed: 1, green: 1, blue: 0, alpha: 1)
        case .homebrewCyan:
            NSColor(calibratedRed: 0, green: 1, blue: 1, alpha: 1)
        case .homebrewOrange:
            NSColor(calibratedRed: 1, green: 0.5, blue: 0, alpha: 1)
        case .homebrewWhite:
            NSColor.white
        }
    }

    var background: NSColor {
        NSColor.black.withAlphaComponent(Self.backgroundAlpha)
    }

    var selection: NSColor {
        NSColor(calibratedRed: 0, green: 0, blue: 0.666, alpha: 0.5)
    }

    var font: NSFont {
        let candidates = ["Andale Mono", "Menlo", "Monaco"]
        for name in candidates {
            if let font = NSFont(name: name, size: Self.fontSize) {
                return font
            }
        }
        return NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
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
