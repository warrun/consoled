import CoreGraphics
import Foundation

enum SessionTileLayout {
    static let headerHeight: CGFloat = 28
    /// Visual gap between the tile header bar and the terminal panel below it.
    static let headerTerminalGap: CGFloat = 6
    static let tileSpacing: CGFloat = 8
    static let outerMargin: CGFloat = 8
    static let selectionBorderWidth: CGFloat = 2
    static let cornerRadius: CGFloat = 8

    struct Slot: Equatable {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    struct TileRects {
        let header: CGRect
        let terminal: CGRect
    }

    static func slots(count: Int, isPortrait: Bool) -> [Slot] {
        let landscape = landscapeSlots(count: max(count, 1))
        guard isPortrait else { return Array(landscape.prefix(count)) }
        return Array(landscape.prefix(count).map(transpose))
    }

    static func tileRects(for slot: Slot, in bounds: CGSize) -> TileRects {
        let contentWidth = max(bounds.width - outerMargin * 2, 0)
        let contentHeight = max(bounds.height - outerMargin * 2, 0)
        let tileWidth = max(slot.width * contentWidth - tileSpacing, 0)
        let tileHeight = max(slot.height * contentHeight - tileSpacing, 0)
        let x = outerMargin + slot.x * contentWidth + tileSpacing * 0.5
        let yFromTop = outerMargin + slot.y * contentHeight + tileSpacing * 0.5
        let inset = selectionBorderWidth

        let header = CGRect(
            x: x + inset,
            y: yFromTop + inset,
            width: max(tileWidth - inset * 2, 0),
            height: max(headerHeight - inset, 0)
        )

        let terminal = CGRect(
            x: x + inset,
            y: yFromTop + headerHeight + headerTerminalGap + inset,
            width: max(tileWidth - inset * 2, 0),
            height: max(tileHeight - headerHeight - headerTerminalGap - inset * 2, 0)
        )

        return TileRects(header: header, terminal: terminal)
    }

    /// Converts top-left SwiftUI coordinates to AppKit bottom-left terminal frame.
    static func appKitTerminalFrame(from rects: TileRects, boundsHeight: CGFloat) -> CGRect {
        let y = boundsHeight - rects.terminal.maxY
        return CGRect(x: rects.terminal.minX, y: y, width: rects.terminal.width, height: rects.terminal.height)
    }

    static func transpose(_ slot: Slot) -> Slot {
        Slot(x: slot.y, y: slot.x, width: slot.height, height: slot.width)
    }

    private static func landscapeSlots(count: Int) -> [Slot] {
        switch count {
        case 1:
            return [Slot(x: 0, y: 0, width: 1, height: 1)]
        case 2:
            return [
                Slot(x: 0, y: 0, width: 0.5, height: 1),
                Slot(x: 0.5, y: 0, width: 0.5, height: 1),
            ]
        case 3:
            return [
                Slot(x: 0, y: 0, width: 0.5, height: 1),
                Slot(x: 0.5, y: 0, width: 0.5, height: 0.5),
                Slot(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
            ]
        case 4:
            return [
                Slot(x: 0, y: 0, width: 0.5, height: 0.5),
                Slot(x: 0.5, y: 0, width: 0.5, height: 0.5),
                Slot(x: 0, y: 0.5, width: 0.5, height: 0.5),
                Slot(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
            ]
        case 5:
            let third = 1.0 / 3.0
            return [
                Slot(x: 0, y: 0, width: third, height: 1),
                Slot(x: third, y: 0, width: third, height: 0.5),
                Slot(x: third, y: 0.5, width: third, height: 0.5),
                Slot(x: third * 2, y: 0, width: third, height: 0.5),
                Slot(x: third * 2, y: 0.5, width: third, height: 0.5),
            ]
        case 6:
            let third = 1.0 / 3.0
            return [
                Slot(x: 0, y: 0, width: third, height: 0.5),
                Slot(x: third, y: 0, width: third, height: 0.5),
                Slot(x: third * 2, y: 0, width: third, height: 0.5),
                Slot(x: 0, y: 0.5, width: third, height: 0.5),
                Slot(x: third, y: 0.5, width: third, height: 0.5),
                Slot(x: third * 2, y: 0.5, width: third, height: 0.5),
            ]
        default:
            return fallbackSlots(count: count)
        }
    }

    private static func fallbackSlots(count: Int) -> [Slot] {
        let columns = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let columnWidth = 1.0 / CGFloat(columns)
        let rowHeight = 1.0 / CGFloat(rows)

        return (0..<count).map { index in
            let row = index / columns
            let column = index % columns
            return Slot(
                x: CGFloat(column) * columnWidth,
                y: CGFloat(row) * rowHeight,
                width: columnWidth,
                height: rowHeight
            )
        }
    }
}
