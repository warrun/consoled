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
