import Foundation

/// A direction the selected session can be moved in the tab bar or tiled grid.
enum SessionMoveDirection: Hashable {
    case left
    case right
    case up
    case down
}

/// A bindable keyboard action: focusing a neighbour session, swapping the selected
/// session's position, or nudging its font size.
enum ShortcutAction: String, CaseIterable, Hashable {
    case focusLeft
    case focusRight
    case focusUp
    case focusDown
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case fontIncrease
    case fontDecrease
    case scpSend
    case scpGet
    case openSFTP

    /// Direction for a swap (move-position) action.
    var moveDirection: SessionMoveDirection? {
        switch self {
        case .moveLeft: return .left
        case .moveRight: return .right
        case .moveUp: return .up
        case .moveDown: return .down
        default: return nil
        }
    }

    /// Direction for a focus (change-selection) action.
    var focusDirection: SessionMoveDirection? {
        switch self {
        case .focusLeft: return .left
        case .focusRight: return .right
        case .focusUp: return .up
        case .focusDown: return .down
        default: return nil
        }
    }

    var isFont: Bool { self == .fontIncrease || self == .fontDecrease }

    /// Actions that only make sense with at least two sessions.
    var needsMultipleSessions: Bool { moveDirection != nil || focusDirection != nil }

    /// Actions that require a remote SSH session to be focused.
    var requiresRemoteSession: Bool {
        switch self {
        case .scpSend, .scpGet, .openSFTP: return true
        default: return false
        }
    }

    var label: String {
        switch self {
        case .focusLeft: return "Focus Left"
        case .focusRight: return "Focus Right"
        case .focusUp: return "Focus Up"
        case .focusDown: return "Focus Down"
        case .moveLeft: return "Swap Left"
        case .moveRight: return "Swap Right"
        case .moveUp: return "Swap Up"
        case .moveDown: return "Swap Down"
        case .fontIncrease: return "Font Size +"
        case .fontDecrease: return "Font Size −"
        case .scpSend: return "Send File (SCP)"
        case .scpGet: return "Get File (SCP)"
        case .openSFTP: return "Open SFTP"
        }
    }
}
