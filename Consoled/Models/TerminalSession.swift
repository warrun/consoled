import Foundation

struct TerminalSession: Identifiable, Hashable {
    let id: UUID
    var profile: SSHHostProfile
    var terminalTheme: TerminalTheme

    init(id: UUID = UUID(), profile: SSHHostProfile, terminalTheme: TerminalTheme) {
        self.id = id
        self.profile = profile
        self.terminalTheme = terminalTheme
    }

    var title: String {
        profile.displayName
    }
}
