//
//  Consoled — A lightweight SSH session and terminal window manager for macOS.
//  Copyright (C) 2026 Warrun Lewis
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

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

    /// Index of the tile to swap with when moving the tile at `index` in `direction`,
    /// or `nil` if there's no tile that way. Purely geometric, computed from the
    /// fractional slot rects so it matches whatever `slots(count:isPortrait:)` produces.
    ///
    /// Horizontal moves pick the nearest column, breaking ties by greatest vertical
    /// overlap then the topmost tile. Vertical moves pick the nearest row, breaking
    /// ties by greatest horizontal overlap then the rightmost tile. This reproduces
    /// the two spanning-tile rules (full-height column → topmost neighbour; full-width
    /// row → rightmost neighbour) without special-casing them.
    static func neighborIndex(
        of index: Int,
        count: Int,
        isPortrait: Bool,
        direction: SessionMoveDirection
    ) -> Int? {
        let layout = slots(count: count, isPortrait: isPortrait)
        guard layout.indices.contains(index) else { return nil }
        let s = layout[index]
        let eps: CGFloat = 1e-6

        func overlap(_ a0: CGFloat, _ a1: CGFloat, _ b0: CGFloat, _ b1: CGFloat) -> CGFloat {
            max(0, min(a1, b1) - max(a0, b0))
        }
        let candidates = layout.enumerated().filter { i, slot in
            guard i != index else { return false }
            switch direction {
            case .right: return slot.x >= s.x + s.width - eps
            case .left: return slot.x + slot.width <= s.x + eps
            case .down: return slot.y >= s.y + s.height - eps
            case .up: return slot.y + slot.height <= s.y + eps
            }
        }
        guard !candidates.isEmpty else { return nil }

        // Restrict to the nearest column (horizontal moves) or row (vertical moves).
        let nearest: [(offset: Int, element: Slot)]
        switch direction {
        case .right:
            let minX = candidates.map(\.element.x).min()!
            nearest = candidates.filter { abs($0.element.x - minX) <= eps }
        case .left:
            let maxRight = candidates.map { $0.element.x + $0.element.width }.max()!
            nearest = candidates.filter { abs(($0.element.x + $0.element.width) - maxRight) <= eps }
        case .down:
            let minY = candidates.map(\.element.y).min()!
            nearest = candidates.filter { abs($0.element.y - minY) <= eps }
        case .up:
            let maxBottom = candidates.map { $0.element.y + $0.element.height }.max()!
            nearest = candidates.filter { abs(($0.element.y + $0.element.height) - maxBottom) <= eps }
        }

        let best = nearest.max { lhs, rhs in
            switch direction {
            case .left, .right:
                let lo = overlap(s.y, s.y + s.height, lhs.element.y, lhs.element.y + lhs.element.height)
                let ro = overlap(s.y, s.y + s.height, rhs.element.y, rhs.element.y + rhs.element.height)
                if abs(lo - ro) > eps { return lo < ro }
                return lhs.element.y > rhs.element.y // tie → topmost (smaller y) wins
            case .up, .down:
                let lo = overlap(s.x, s.x + s.width, lhs.element.x, lhs.element.x + lhs.element.width)
                let ro = overlap(s.x, s.x + s.width, rhs.element.x, rhs.element.x + rhs.element.width)
                if abs(lo - ro) > eps { return lo < ro }
                return lhs.element.x < rhs.element.x // tie → rightmost (larger x) wins
            }
        }
        return best?.offset
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
        case 7:
            // Full-height left column (top-left session) + two columns of three.
            let third = 1.0 / 3.0
            return [
                Slot(x: 0, y: 0, width: third, height: 1),
                Slot(x: third, y: 0, width: third, height: third),
                Slot(x: third, y: third, width: third, height: third),
                Slot(x: third, y: third * 2, width: third, height: third),
                Slot(x: third * 2, y: 0, width: third, height: third),
                Slot(x: third * 2, y: third, width: third, height: third),
                Slot(x: third * 2, y: third * 2, width: third, height: third),
            ]
        case 8:
            // Two rows of four.
            let quarter = 0.25
            return (0..<8).map { index in
                let column = index % 4
                let row = index / 4
                return Slot(
                    x: CGFloat(column) * quarter,
                    y: CGFloat(row) * 0.5,
                    width: quarter,
                    height: 0.5
                )
            }
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
