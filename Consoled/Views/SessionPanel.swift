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

/// Which corners a session panel rounds.
enum PanelCornerShape {
    case all
    case bottomOnly
}

/// The contract the host controller needs from a panel, so it can manage terminal
/// panels and notes panels interchangeably in the tab/tile layout.
@MainActor
protocol SessionPanel: AnyObject {
    /// The subview that should become first responder when the panel is selected.
    var focusView: NSView { get }
    /// The appearance currently applied (drives the controller's change detection).
    var theme: TerminalTheme { get }
    var onFocus: (() -> Void)? { get set }

    func applyAppearance(_ theme: TerminalTheme)
    func setPanelCornerShape(_ shape: PanelCornerShape)
    func setSelected(_ selected: Bool)
    /// Tear down any backing resource (process for terminals; no-op for notes).
    func terminateSession()
}
