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

import AppKit
import SwiftUI

struct SessionTiledChrome: View {
    @Bindable var manager: SessionManager
    var workspaceSettings: SessionWorkspaceSettings
    var onClose: (TerminalSession) -> Void
    var onSave: (TerminalSession) -> Void

    var body: some View {
        GeometryReader { geometry in
            let isPortrait = workspaceSettings.tileIsPortrait(for: geometry.size)
            let slots = SessionTileLayout.slots(count: manager.sessions.count, isPortrait: isPortrait)
            let bounds = CGSize(width: geometry.size.width, height: geometry.size.height)
            let radius = SessionTileLayout.cornerRadius

            ForEach(Array(manager.sessions.enumerated()), id: \.element.id) { index, session in
                if index < slots.count {
                    let slot = slots[index]
                    let rects = SessionTileLayout.tileRects(for: slot, in: bounds)
                    let isSelected = manager.selectedSessionID == session.id

                    TileHeader(
                        title: session.title,
                        accent: session.terminalTheme.accent,
                        isSelected: isSelected,
                        showSave: session.isNotes,
                        onSelect: { manager.selectSession(session) },
                        onClose: { onClose(session) },
                        onSave: { onSave(session) },
                        onRename: { manager.renameSession(session.id, to: $0) }
                    )
                    .frame(width: rects.header.width, height: rects.header.height)
                    .background(SessionHeaderBackground())
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                    .overlay {
                        if isSelected {
                            ZStack {
                                RoundedRectangle(cornerRadius: radius)
                                    .inset(by: SessionTileLayout.selectionBorderWidth / 2)
                                    .stroke(
                                        Color(nsColor: session.terminalTheme.accent),
                                        lineWidth: SessionTileLayout.selectionBorderWidth
                                    )
                                // Adaptive hairline casing so the border reads even when the
                                // accent ≈ the bar (e.g. a white accent on a light bar).
                                RoundedRectangle(cornerRadius: radius)
                                    .inset(by: SessionTileLayout.selectionBorderWidth)
                                    .stroke(Color.primary.opacity(0.3), lineWidth: 0.75)
                            }
                        }
                    }
                    .offset(x: rects.header.minX, y: rects.header.minY)
                }
            }
        }
        .allowsHitTesting(true)
    }
}

private struct TileHeader: View {
    let title: String
    let accent: NSColor
    let isSelected: Bool
    let showSave: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onSave: () -> Void
    let onRename: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(nsColor: accent))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
                .frame(width: 8, height: 8)

            EditableTitle(title: title, isSelected: isSelected, font: .caption, onRename: onRename)

            Spacer(minLength: 0)

            if showSave {
                Button("Save", action: onSave)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Save note")
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Close session")
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
