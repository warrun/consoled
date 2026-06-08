import Foundation

struct TerminalThemeDefinition: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var accent: CodableColor
    var isBuiltIn: Bool
}

enum BuiltInTerminalThemes {
    static let all: [TerminalThemeDefinition] = [
        definition(id: "homebrew", name: "Homebrew", accent: CodableColor(red: 0, green: 1, blue: 0)),
        definition(id: "homebrewBlue", name: "Homebrew Blue", accent: CodableColor(red: 0, green: 0, blue: 1)),
        definition(id: "homebrewRed", name: "Homebrew Red", accent: CodableColor(red: 1, green: 0, blue: 0)),
        definition(id: "homebrewPurple", name: "Homebrew Purple", accent: CodableColor(red: 1, green: 0, blue: 1)),
        definition(id: "homebrewYellow", name: "Homebrew Yellow", accent: CodableColor(red: 1, green: 1, blue: 0)),
        definition(id: "homebrewCyan", name: "Homebrew Cyan", accent: CodableColor(red: 0, green: 1, blue: 1)),
        definition(id: "homebrewOrange", name: "Homebrew Orange", accent: CodableColor(red: 1, green: 0.5, blue: 0)),
        definition(id: "homebrewWhite", name: "Homebrew White", accent: CodableColor(red: 1, green: 1, blue: 1)),
    ]

    static let defaultID = "homebrew"

    private static func definition(id: String, name: String, accent: CodableColor) -> TerminalThemeDefinition {
        TerminalThemeDefinition(id: id, displayName: name, accent: accent, isBuiltIn: true)
    }
}
