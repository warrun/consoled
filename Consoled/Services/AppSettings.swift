import Foundation

@Observable
@MainActor
final class AppSettings {
    private static let restoreWorkspaceKey = "restoreWorkspaceOnLaunch"
    private static let terminalOpacityKey = "terminalBackgroundOpacity"

    static let minTerminalOpacity = 0.3

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

    init() {
        restoreWorkspaceOnLaunch = UserDefaults.standard.bool(forKey: Self.restoreWorkspaceKey)
        terminalOpacity = Self.storedDouble(Self.terminalOpacityKey, default: Double(TerminalTheme.defaultBackgroundOpacity))
    }

    private static func storedDouble(_ key: String, default fallback: Double) -> Double {
        guard let value = UserDefaults.standard.object(forKey: key) as? Double else { return fallback }
        return value
    }
}
