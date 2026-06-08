import Foundation

/// A direction the selected session can be moved in the tab bar or tiled grid.
enum SessionMoveDirection: Hashable {
    case left
    case right
    case up
    case down
}

/// A bindable keyboard action: moving the selected session, or nudging its font size.
enum ShortcutAction: String, CaseIterable, Hashable {
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case fontIncrease
    case fontDecrease

    var moveDirection: SessionMoveDirection? {
        switch self {
        case .moveLeft: return .left
        case .moveRight: return .right
        case .moveUp: return .up
        case .moveDown: return .down
        case .fontIncrease, .fontDecrease: return nil
        }
    }

    var isFont: Bool { self == .fontIncrease || self == .fontDecrease }

    var label: String {
        switch self {
        case .moveLeft: return "Move Left"
        case .moveRight: return "Move Right"
        case .moveUp: return "Move Up"
        case .moveDown: return "Move Down"
        case .fontIncrease: return "Font Size +"
        case .fontDecrease: return "Font Size −"
        }
    }
}
