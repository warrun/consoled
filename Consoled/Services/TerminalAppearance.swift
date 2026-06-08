import AppKit
import SwiftTerm

enum TerminalAppearance {
    static func apply(_ theme: TerminalTheme, to terminal: ConsoledTerminalView) {
        terminal.nativeForegroundColor = theme.accent
        terminal.nativeBackgroundColor = .clear
        terminal.caretColor = theme.accent
        terminal.caretTextColor = NSColor.black
        terminal.selectedTextBackgroundColor = theme.selection
        terminal.font = theme.font
        terminal.useBrightColors = false
        terminal.installColors(theme.ansiPalette)
        terminal.getTerminal().setCursorStyle(.blinkBlock)
        enforceClearLayer(on: terminal)
        DispatchQueue.main.async {
            enforceClearLayer(on: terminal)
        }
    }

    static func applyContainer(_ theme: TerminalTheme, to container: TerminalContainerView) {
        container.updateFrostedBackdrop(theme: theme)
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
