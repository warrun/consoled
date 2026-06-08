import AppKit
import SwiftTerm

enum TerminalAppearance {
    static func apply(_ profile: TerminalProfile, to terminal: ConsoledTerminalView) {
        terminal.nativeForegroundColor = profile.accent
        terminal.nativeBackgroundColor = .clear
        terminal.caretColor = profile.accent
        terminal.caretTextColor = NSColor.black
        terminal.selectedTextBackgroundColor = profile.selection
        terminal.font = profile.font
        terminal.useBrightColors = false
        terminal.installColors(profile.ansiPalette)
        terminal.getTerminal().setCursorStyle(.blinkBlock)
        enforceClearLayer(on: terminal)
        DispatchQueue.main.async {
            enforceClearLayer(on: terminal)
        }
    }

    static func applyContainer(_ profile: TerminalProfile, to container: TerminalContainerView) {
        container.updateFrostedBackdrop(profile: profile)
        enforceClearLayer(on: container)
        enforceClearLayer(on: container.terminalView)
    }

    static func enforceClearLayer(on view: NSView) {
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    static func configureWindowForTransparency(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
    }
}
