import AppKit
import SwiftUI

/// Ensures the window keeps standard macOS title bar controls (traffic lights). Runs once per window.
struct WindowChromeConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.configureIfNeeded(window: view.window)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.configureIfNeeded(window: nsView.window)
    }

    final class Coordinator {
        private weak var configuredWindow: NSWindow?

        func configureIfNeeded(window: NSWindow?) {
            guard let window, configuredWindow !== window else { return }
            configuredWindow = window

            window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
            window.hasShadow = true
            TerminalAppearance.configureWindowForTransparency(window)
        }
    }
}

extension View {
    func standardWindowChrome() -> some View {
        background(WindowChromeConfigurator())
    }
}
