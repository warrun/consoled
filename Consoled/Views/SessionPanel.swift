import AppKit

/// Which corners a session panel rounds.
enum PanelCornerShape {
    case all
    case bottomOnly
}

/// The contract the host controller needs from a panel, so it can manage terminal
/// panels and notes panels interchangeably in the tab/tile layout.
@MainActor
protocol SessionPanel: AnyObject {
    /// The subview that should become first responder when the panel is selected.
    var focusView: NSView { get }
    /// The appearance currently applied (drives the controller's change detection).
    var theme: TerminalTheme { get }
    var onFocus: (() -> Void)? { get set }

    func applyAppearance(_ theme: TerminalTheme)
    func setPanelCornerShape(_ shape: PanelCornerShape)
    func setSelected(_ selected: Bool)
    /// Tear down any backing resource (process for terminals; no-op for notes).
    func terminateSession()
}
