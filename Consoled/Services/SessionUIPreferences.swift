import Foundation

@Observable
@MainActor
final class SessionUIPreferences {
    /// Always starts closed on launch; not persisted across app restarts.
    var isSettingsPanelVisible = false

    func showSettingsPanel() {
        isSettingsPanelVisible = true
    }
}
