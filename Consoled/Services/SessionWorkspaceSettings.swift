import Foundation

@Observable
@MainActor
final class SessionWorkspaceSettings {
    private static let layoutModeKey = "sessionLayoutMode"

    var layoutMode: SessionLayoutMode {
        didSet {
            guard layoutMode != oldValue else { return }
            UserDefaults.standard.set(layoutMode.rawValue, forKey: Self.layoutModeKey)
            if layoutMode == .tabs {
                restoredTileIsPortrait = nil
            }
        }
    }

    /// When set, tiled layout uses this orientation instead of live window geometry.
    var restoredTileIsPortrait: Bool?

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.layoutModeKey),
           let mode = SessionLayoutMode(rawValue: raw) {
            layoutMode = mode
        } else {
            layoutMode = .tabs
        }
    }

    func tileIsPortrait(for bounds: CGSize) -> Bool {
        restoredTileIsPortrait ?? (bounds.width < bounds.height)
    }
}
