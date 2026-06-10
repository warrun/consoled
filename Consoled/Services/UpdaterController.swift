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

import Combine
import SwiftUI
import Sparkle

/// Wraps Sparkle's updater. Starts only once a real EdDSA public key is configured
/// (see RELEASING.md → run `generate_keys` and replace SUPublicEDKey). Until then the
/// updater stays inert so the app runs cleanly with no update errors.
@MainActor
final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private let controller: SPUStandardUpdaterController?

    init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        guard !key.isEmpty, !key.hasPrefix("PLACEHOLDER") else {
            controller = nil
            return
        }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

/// The "Check for Updates…" menu item. Disabled while a check is in progress or before
/// Sparkle is configured.
struct CheckForUpdatesCommand: View {
    @ObservedObject var model: UpdaterViewModel

    var body: some View {
        Button("Check for Updates…") {
            model.checkForUpdates()
        }
        .disabled(!model.canCheckForUpdates)
    }
}
