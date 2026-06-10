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

import Foundation

enum ConnectTiming {
    private static var connectStart: CFAbsoluteTime?

    static func markConnect() {
        connectStart = CFAbsoluteTimeGetCurrent()
        log("connect requested")
    }

    static func mark(_ event: String) {
        guard let connectStart else {
            log(event)
            return
        }
        let elapsedMS = Int((CFAbsoluteTimeGetCurrent() - connectStart) * 1000)
        log("\(event) (+\(elapsedMS)ms)")
    }

    static func reset() {
        connectStart = nil
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("[Consoled Connect] \(message)")
        #endif
    }
}
