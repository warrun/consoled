import AppKit
import SwiftUI

struct SessionTiledChrome: View {
    @Bindable var manager: SessionManager

    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.width < geometry.size.height
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
                        accent: session.terminalProfile.accent,
                        isSelected: isSelected,
                        onSelect: { manager.selectSession(session) },
                        onClose: { manager.closeSession(session) }
                    )
                    .frame(width: rects.header.width, height: rects.header.height)
                    .background(TileHeaderBackground())
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius)
                            .inset(by: SessionTileLayout.selectionBorderWidth / 2)
                            .stroke(
                                isSelected ? Color(nsColor: session.terminalProfile.accent) : Color.clear,
                                lineWidth: SessionTileLayout.selectionBorderWidth
                            )
                    }
                    .offset(x: rects.header.minX, y: rects.header.minY)
                }
            }
        }
        .allowsHitTesting(true)
    }
}

/// Dark, readable tile tab bar over the frosted workspace.
private struct TileHeaderBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            Color.black.opacity(0.72)
        }
    }
}

private struct TileHeader: View {
    let title: String
    let accent: NSColor
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(nsColor: accent))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

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
