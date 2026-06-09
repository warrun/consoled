import AppKit

/// An NSTextView subclass that reports focus so the host can update selection.
final class NotesTextView: NSTextView {
    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        onFocus?()
        return super.becomeFirstResponder()
    }
}

/// A notes (scratchpad) panel: a light, frosted text editor that slots into the same
/// tab/tile layout as terminal panels.
final class NotesContainerView: NSView, SessionPanel {
    private let document: NotesDocument
    private let paperPlate = NSView()
    private let scrollView = NSScrollView()
    private let textView = NotesTextView()

    private(set) var theme: TerminalTheme
    var onFocus: (() -> Void)?

    private var notesOpacity: CGFloat = 0.85
    private var panelCornerShape: PanelCornerShape = .all

    var focusView: NSView { textView }

    override var isOpaque: Bool { false }

    init(document: NotesDocument, theme: TerminalTheme, notesOpacity: CGFloat) {
        self.document = document
        self.theme = theme
        self.notesOpacity = notesOpacity
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        buildSubviews()
        applyAppearance(theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildSubviews() {
        // Translucent white wash over the window's frosted backdrop; its alpha is the
        // notes opacity (1.0 = solid white, lower = the frosted window shows through).
        paperPlate.wantsLayer = true
        paperPlate.layer?.isOpaque = false
        paperPlate.translatesAutoresizingMaskIntoConstraints = false
        paperPlate.layer?.backgroundColor = NSColor.white.withAlphaComponent(notesOpacity).cgColor

        // Editor.
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        textView.onFocus = { [weak self] in self?.onFocus?() }
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .black
        textView.insertionPointColor = .black
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = document.text
        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        addSubview(paperPlate)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            paperPlate.leadingAnchor.constraint(equalTo: leadingAnchor),
            paperPlate.trailingAnchor.constraint(equalTo: trailingAnchor),
            paperPlate.topAnchor.constraint(equalTo: topAnchor),
            paperPlate.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: SessionPanel

    func applyAppearance(_ theme: TerminalTheme) {
        self.theme = theme
        textView.font = theme.font
    }

    func setNotesOpacity(_ opacity: CGFloat) {
        notesOpacity = opacity
        paperPlate.layer?.backgroundColor = NSColor.white.withAlphaComponent(opacity).cgColor
    }

    func setPanelCornerShape(_ shape: PanelCornerShape) {
        panelCornerShape = shape
        applyPanelChrome()
    }

    func setSelected(_ selected: Bool) {
        _ = selected
    }

    func terminateSession() {
        // No process to terminate; unsaved-text handling lives in the close/quit prompts.
    }

    override func mouseDown(with event: NSEvent) {
        onFocus?()
        super.mouseDown(with: event)
    }

    override func layout() {
        super.layout()
        applyPanelChrome()
    }

    private func applyPanelChrome() {
        let radius = TerminalTheme.panelCornerRadius
        let corners: CACornerMask = switch panelCornerShape {
        case .all:
            [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .bottomOnly:
            [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        for view in [self, paperPlate] {
            view.wantsLayer = true
            view.layer?.cornerRadius = radius
            view.layer?.maskedCorners = corners
            view.layer?.masksToBounds = true
        }
    }
}

extension NotesContainerView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        document.text = textView.string
        document.isDirty = true
    }
}
