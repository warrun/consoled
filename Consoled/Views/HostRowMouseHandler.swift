import AppKit
import SwiftUI

struct HostRowMouseHandler: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> HostRowMouseView {
        let view = HostRowMouseView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: HostRowMouseView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }
}

final class HostRowMouseView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSingleClick), object: nil)
            onDoubleClick?()
            return
        }

        if event.clickCount == 1 {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSingleClick), object: nil)
            perform(#selector(performSingleClick), with: nil, afterDelay: 0.2)
        }
    }

    @objc private func performSingleClick() {
        onSingleClick?()
    }
}
