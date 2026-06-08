import Foundation

struct TerminalSession: Identifiable, Hashable {
    let id: UUID
    var profile: SSHHostProfile
    var terminalProfile: TerminalProfile

    init(id: UUID = UUID(), profile: SSHHostProfile, terminalProfile: TerminalProfile = .homebrew) {
        self.id = id
        self.profile = profile
        self.terminalProfile = terminalProfile
    }

    var title: String {
        profile.displayName
    }
}
