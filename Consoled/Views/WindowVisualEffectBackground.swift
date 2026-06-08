import AppKit
import SwiftUI

/// Blurred desktop backdrop visible through semi-transparent terminal cells.
struct WindowVisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.isOpaque = false
        return effect
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
