import Foundation

struct TerminalSession: Identifiable, Hashable {
    let id: UUID
    /// The SSH host this session connects to, or `nil` for a local shell session.
    var profile: SSHHostProfile?
    var terminalTheme: TerminalTheme
    /// Explicit per-session theme override. Used by local sessions (which have no
    /// host to carry a `themeID`); `nil` means follow the default theme.
    var assignedThemeID: String?
    /// Explicit per-session font size (from ⌘⇧± or a local session). `nil` means
    /// follow the host's size, or the global default.
    var assignedFontSize: CGFloat?

    init(
        id: UUID = UUID(),
        profile: SSHHostProfile? = nil,
        terminalTheme: TerminalTheme,
        assignedThemeID: String? = nil,
        assignedFontSize: CGFloat? = nil
    ) {
        self.id = id
        self.profile = profile
        self.terminalTheme = terminalTheme
        self.assignedThemeID = assignedThemeID
        self.assignedFontSize = assignedFontSize
    }

    var isLocal: Bool { profile == nil }

    var title: String {
        profile?.displayName ?? "Local"
    }
}
