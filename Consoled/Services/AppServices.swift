import Foundation

/// Lightweight bridge so the AppKit `AppDelegate` (which SwiftUI instantiates for us)
/// can reach the SessionManager — e.g. to check for unsaved notes on quit.
enum AppServices {
    @MainActor static weak var sessionManager: SessionManager?
}
