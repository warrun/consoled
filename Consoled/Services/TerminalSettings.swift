import Foundation

@Observable
@MainActor
final class TerminalSettings {
    private static let profileKey = "terminalProfileID"

    var defaultProfile: TerminalProfile {
        didSet {
            guard defaultProfile != oldValue else { return }
            save()
            onChange?()
        }
    }

    var onChange: (() -> Void)?

    init() {
        if let id = UserDefaults.standard.string(forKey: Self.profileKey),
           let profile = TerminalProfile(id: id) {
            defaultProfile = profile
        } else {
            defaultProfile = .homebrew
        }
    }

    private func save() {
        UserDefaults.standard.set(defaultProfile.id, forKey: Self.profileKey)
    }
}
