import Foundation

/// Describes the process a terminal panel should launch. Generalizes over SSH
/// (the `ssh` binary with connection args) and a local login shell.
struct TerminalLaunch: Hashable {
    var executable: String
    var args: [String]
    /// argv[0] for the spawned process. `"ssh"` for SSH; a leading-dash shell
    /// name (e.g. `"-zsh"`) marks a local login shell.
    var execName: String?
    var currentDirectory: String?

    /// SSH launches are the only ones that should surface OpenSSH exit-code
    /// diagnostics when the process ends non-zero.
    var isSSH: Bool { execName == "ssh" }
}
