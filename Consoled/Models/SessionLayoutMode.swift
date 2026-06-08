import Foundation

enum SessionLayoutMode: String, Codable, CaseIterable, Identifiable {
    case tabs
    case tiled

    var id: String { rawValue }
}
