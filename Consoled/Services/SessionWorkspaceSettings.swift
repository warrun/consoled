import Foundation

@Observable
@MainActor
final class SessionWorkspaceSettings {
    private static let layoutModeKey = "sessionLayoutMode"

    var layoutMode: SessionLayoutMode {
        didSet {
            guard layoutMode != oldValue else { return }
            UserDefaults.standard.set(layoutMode.rawValue, forKey: Self.layoutModeKey)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.layoutModeKey),
           let mode = SessionLayoutMode(rawValue: raw) {
            layoutMode = mode
        } else {
            layoutMode = .tabs
        }
    }
}
