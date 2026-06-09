import Foundation

@Observable
@MainActor
final class AppSettings {
    private static let restoreWorkspaceKey = "restoreWorkspaceOnLaunch"
    private static let terminalOpacityKey = "terminalBackgroundOpacity"
    private static let notesOpacityKey = "notesBackgroundOpacity"

    static let minTerminalOpacity = 0.3
    static let minNotesOpacity = 0.3

    var restoreWorkspaceOnLaunch: Bool {
        didSet {
            guard restoreWorkspaceOnLaunch != oldValue else { return }
            UserDefaults.standard.set(restoreWorkspaceOnLaunch, forKey: Self.restoreWorkspaceKey)
        }
    }

    var terminalOpacity: Double {
        didSet {
            guard terminalOpacity != oldValue else { return }
            UserDefaults.standard.set(terminalOpacity, forKey: Self.terminalOpacityKey)
        }
    }

    var notesOpacity: Double {
        didSet {
            guard notesOpacity != oldValue else { return }
            UserDefaults.standard.set(notesOpacity, forKey: Self.notesOpacityKey)
        }
    }

    init() {
        restoreWorkspaceOnLaunch = UserDefaults.standard.bool(forKey: Self.restoreWorkspaceKey)
        terminalOpacity = Self.storedDouble(Self.terminalOpacityKey, default: Double(TerminalTheme.defaultBackgroundOpacity))
        notesOpacity = Self.storedDouble(Self.notesOpacityKey, default: 0.85)
    }

    private static func storedDouble(_ key: String, default fallback: Double) -> Double {
        guard let value = UserDefaults.standard.object(forKey: key) as? Double else { return fallback }
        return value
    }
}
