import AppKit
import SwiftTerm

enum TerminalColorConversion {
    static func terminalColor(from nsColor: NSColor) -> Color {
        guard let color = nsColor.usingColorSpace(.deviceRGB) else {
            return Color(red: 0, green: 0, blue: 0)
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color(
            red: UInt16(red * 65535),
            green: UInt16(green * 65535),
            blue: UInt16(blue * 65535)
        )
    }
}
