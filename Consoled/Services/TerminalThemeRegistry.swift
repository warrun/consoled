import Foundation
import Observation

enum TerminalThemeRegistryError: LocalizedError {
    case cannotDeleteBuiltIn
    case cannotDeleteDefaultTheme
    case themeInUseByHosts

    var errorDescription: String? {
        switch self {
        case .cannotDeleteBuiltIn:
            "Built-in themes cannot be deleted."
        case .cannotDeleteDefaultTheme:
            "Change the default theme before deleting this one."
        case .themeInUseByHosts:
            "This theme is assigned to one or more hosts. Change those hosts to another theme first."
        }
    }
}

@MainActor
@Observable
final class TerminalThemeRegistry {
    private(set) var customThemes: [TerminalThemeDefinition] = []
    private(set) var builtInThemeOverrides: [String: TerminalThemeDefinition] = [:]

    /// Called after in-memory theme mutations; must persist via SessionManager.
    var onPersist: (() -> Void)?
    /// Called after theme changes to refresh live terminal sessions.
    var onChange: (() -> Void)?

    var allThemes: [TerminalTheme] {
        BuiltInTerminalThemes.all.map { builtIn in
            let definition = builtInThemeOverrides[builtIn.id] ?? builtIn
            return TerminalTheme(definition: definition)
        } + customThemes.map(TerminalTheme.init)
    }

    func theme(id: String) -> TerminalTheme? {
        allThemes.first { $0.id == id }
    }

    func defaultTheme() -> TerminalTheme {
        theme(id: BuiltInTerminalThemes.defaultID) ?? TerminalTheme(definition: BuiltInTerminalThemes.all[0])
    }

    func createCustom(name: String = "New Theme", accent: CodableColor = CodableColor(red: 0, green: 1, blue: 0)) -> TerminalThemeDefinition {
        let definition = TerminalThemeDefinition(
            id: UUID().uuidString,
            displayName: name,
            accent: accent,
            isBuiltIn: false
        )
        customThemes.append(definition)
        notifyChanged()
        return definition
    }

    func update(_ definition: TerminalThemeDefinition) {
        if definition.isBuiltIn {
            builtInThemeOverrides[definition.id] = definition
        } else if let index = customThemes.firstIndex(where: { $0.id == definition.id }) {
            customThemes[index] = definition
        }
        notifyChanged()
    }

    func delete(id: String, defaultThemeID: String, hostThemeIDs: Set<String>) throws {
        guard !BuiltInTerminalThemes.all.contains(where: { $0.id == id }) else {
            throw TerminalThemeRegistryError.cannotDeleteBuiltIn
        }
        guard id != defaultThemeID else {
            throw TerminalThemeRegistryError.cannotDeleteDefaultTheme
        }
        guard !hostThemeIDs.contains(id) else {
            throw TerminalThemeRegistryError.themeInUseByHosts
        }
        customThemes.removeAll { $0.id == id }
        notifyChanged()
    }

    func canDelete(id: String, defaultThemeID: String, hostThemeIDs: Set<String>) -> Bool {
        guard !BuiltInTerminalThemes.all.contains(where: { $0.id == id }) else { return false }
        guard id != defaultThemeID else { return false }
        guard !hostThemeIDs.contains(id) else { return false }
        return customThemes.contains { $0.id == id }
    }

    func exportForProfileStore() -> (custom: [TerminalThemeDefinition], builtInOverrides: [String: TerminalThemeDefinition]) {
        (customThemes, builtInThemeOverrides)
    }

    func importFromProfileStore(custom: [TerminalThemeDefinition], builtInOverrides: [String: TerminalThemeDefinition]) {
        customThemes = custom
        builtInThemeOverrides = builtInOverrides
    }

    private func notifyChanged() {
        onChange?()
        onPersist?()
    }
}
