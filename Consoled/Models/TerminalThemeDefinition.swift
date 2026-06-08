import Foundation

struct TerminalThemeDefinition: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var accent: CodableColor
    var isBuiltIn: Bool
}

enum BuiltInTerminalThemes {
    // IDs are kept stable (legacy "homebrew*" identifiers) so existing host
    // assignments and saved defaults keep resolving across the rename.
    static let all: [TerminalThemeDefinition] = [
        definition(id: "homebrewWhite", name: "White", accent: CodableColor(red: 1, green: 1, blue: 1)),
        definition(id: "homebrew", name: "Green", accent: CodableColor(red: 0, green: 1, blue: 0)),
        definition(id: "homebrewBlue", name: "Blue", accent: CodableColor(red: 0, green: 0, blue: 1)),
        definition(id: "homebrewRed", name: "Red", accent: CodableColor(red: 1, green: 0, blue: 0)),
        definition(id: "homebrewPurple", name: "Purple", accent: CodableColor(red: 1, green: 0, blue: 1)),
        definition(id: "homebrewOrange", name: "Orange", accent: CodableColor(red: 1, green: 0.5, blue: 0)),
        definition(id: "homebrewYellow", name: "Yellow", accent: CodableColor(red: 1, green: 1, blue: 0)),
    ]

    static let defaultID = "homebrewWhite"

    private static func definition(id: String, name: String, accent: CodableColor) -> TerminalThemeDefinition {
        TerminalThemeDefinition(id: id, displayName: name, accent: accent, isBuiltIn: true)
    }
}
