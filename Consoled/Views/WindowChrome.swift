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
