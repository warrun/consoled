import Foundation

@Observable
@MainActor
final class AppSettings {
    private static let restoreWorkspaceKey = "restoreWorkspaceOnLaunch"

    var restoreWorkspaceOnLaunch: Bool {
        didSet {
            guard restoreWorkspaceOnLaunch != oldValue else { return }
            UserDefaults.standard.set(restoreWorkspaceOnLaunch, forKey: Self.restoreWorkspaceKey)
        }
    }

    init() {
        restoreWorkspaceOnLaunch = UserDefaults.standard.bool(forKey: Self.restoreWorkspaceKey)
    }
}
