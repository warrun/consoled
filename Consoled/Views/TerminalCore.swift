import AppKit
import SwiftTerm

/// Rounded semi-transparent fill behind the character grid.
final class TerminalPanelPlate: NSView {
    var fillColor: NSColor = .black {
        didSet { layer?.backgroundColor = fillColor.cgColor }
    }

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = fillColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyCornerShape(_ shape: PanelCornerShape) {
        let radius = TerminalTheme.panelCornerRadius
        let corners: CACornerMask = switch shape {
        case .all:
            [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .bottomOnly:
            [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        layer?.cornerRadius = radius
        layer?.maskedCorners = corners
        layer?.masksToBounds = true
    }
}

final class ConsoledTerminalView: LocalProcessTerminalView {
    var onFirstOutput: (() -> Void)?
    private var receivedOutput = false

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        TerminalAppearance.enforceClearLayer(on: self)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        TerminalAppearance.enforceClearLayer(on: self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        TerminalAppearance.enforceClearLayer(on: self)
        if let window {
            TerminalAppearance.configureWindowForTransparency(window)
        }
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)

        guard !receivedOutput, !slice.isEmpty else { return }
        receivedOutput = true
        ConnectTiming.mark("first terminal output")
        DispatchQueue.main.async { [weak self] in
            self?.onFirstOutput?()
        }
    }

    func resetOutputTracking() {
        receivedOutput = false
    }

    /// Paste without bracketed-paste markers. With them, the shell standout-highlights
    /// the pasted region (reverse video), which renders invisibly against our
    /// transparent terminal background. Sending raw text echoes it in the theme colour.
    /// (Trade-off: multi-line pastes are submitted as typed rather than held as one block.)
    override func paste(_ sender: Any) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        insertText(text, replacementRange: NSRange(location: 0, length: 0))
    }
}

final class TerminalContainerView: NSView, SessionPanel {
    let terminalView = ConsoledTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    var focusView: NSView { terminalView }
    private let frostBackdrop = NSVisualEffectView()
    private let panelPlate = TerminalPanelPlate()
    var onFocus: (() -> Void)?
    private var started = false
    private var pendingExecutable: String?
    private var pendingArgs: [String] = []
    private var pendingExecName: String?
    private var pendingCurrentDirectory: String?
    private var onProcessStarted: (() -> Void)?
    private var onFirstOutput: (() -> Void)?
    private var onExit: ((Int32?) -> Void)?
    private let exitHandler = TerminalExitHandler()
    private(set) var theme: TerminalTheme = TerminalTheme(definition: BuiltInTerminalThemes.all[0])

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor

        frostBackdrop.material = .hudWindow
        frostBackdrop.blendingMode = .behindWindow
        frostBackdrop.state = .active
        frostBackdrop.wantsLayer = true
        frostBackdrop.layer?.isOpaque = false
        frostBackdrop.translatesAutoresizingMaskIntoConstraints = false

        panelPlate.translatesAutoresizingMaskIntoConstraints = false

        let padding = TerminalTheme.textPadding
        terminalView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(frostBackdrop)
        addSubview(panelPlate)
        addSubview(terminalView)

        NSLayoutConstraint.activate([
            frostBackdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            frostBackdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            frostBackdrop.topAnchor.constraint(equalTo: topAnchor),
            frostBackdrop.bottomAnchor.constraint(equalTo: bottomAnchor),

            panelPlate.leadingAnchor.constraint(equalTo: leadingAnchor),
            panelPlate.trailingAnchor.constraint(equalTo: trailingAnchor),
            panelPlate.topAnchor.constraint(equalTo: topAnchor),
            panelPlate.bottomAnchor.constraint(equalTo: bottomAnchor),

            terminalView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            terminalView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            terminalView.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            terminalView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding),
        ])
        applyPanelChrome()
        applyAppearance(TerminalTheme(definition: BuiltInTerminalThemes.all[0]))
    }

    func updateFrostedBackdrop(theme: TerminalTheme) {
        frostBackdrop.material = .hudWindow
        frostBackdrop.state = .active
        panelPlate.fillColor = theme.background
        applyPanelChrome()
    }

    private var panelCornerShape: PanelCornerShape = .all

    func setPanelCornerShape(_ shape: PanelCornerShape) {
        panelCornerShape = shape
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

        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.maskedCorners = corners
        layer?.masksToBounds = true

        frostBackdrop.layer?.cornerRadius = radius
        frostBackdrop.layer?.maskedCorners = corners
        frostBackdrop.layer?.masksToBounds = true

        panelPlate.applyCornerShape(panelCornerShape)
    }

    override func layout() {
        super.layout()
        applyPanelChrome()
        TerminalAppearance.enforceClearLayer(on: self)
        TerminalAppearance.enforceClearLayer(on: terminalView)
    }

    func applyAppearance(_ theme: TerminalTheme) {
        self.theme = theme
        TerminalAppearance.applyContainer(theme, to: self)
        TerminalAppearance.apply(theme, to: terminalView)
    }

    func setSelected(_ selected: Bool) {
        _ = selected
    }

    override func mouseDown(with event: NSEvent) {
        onFocus?()
        super.mouseDown(with: event)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        terminalView.terminate()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        tryStartIfReady()
    }

    func configure(
        executable: String,
        args: [String],
        execName: String?,
        currentDirectory: String?,
        onProcessStarted: @escaping () -> Void,
        onFirstOutput: @escaping () -> Void,
        onExit: @escaping (Int32?) -> Void
    ) {
        pendingExecutable = executable
        pendingArgs = args
        pendingExecName = execName
        pendingCurrentDirectory = currentDirectory
        self.onProcessStarted = onProcessStarted
        self.onFirstOutput = onFirstOutput
        self.onExit = onExit

        terminalView.resetOutputTracking()
        terminalView.onFirstOutput = onFirstOutput

        let isSSH = execName == "ssh"
        exitHandler.onExit = { [weak self] exitCode in
            guard let self else { return }
            if isSSH, let exitCode, exitCode != 0 {
                let message = SSHExitCodeMapper.message(for: exitCode)
                self.terminalView.feed(text: "\r\n\r\n[\(message)]\r\n")
            }
            onExit(exitCode)
        }

        tryStartIfReady()
    }

    func terminateSession() {
        terminalView.terminate()
        started = false
    }

    private func tryStartIfReady() {
        guard !started, window != nil, let executable = pendingExecutable else { return }

        if bounds.width < 2 || bounds.height < 2 {
            terminalView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        }

        started = true
        terminalView.processDelegate = exitHandler
        terminalView.startProcess(
            executable: executable,
            args: pendingArgs,
            execName: pendingExecName,
            currentDirectory: pendingCurrentDirectory
        )
        ConnectTiming.mark("startProcess(\(pendingExecName ?? executable))")
        onProcessStarted?()
    }
}

final class TerminalExitHandler: LocalProcessTerminalViewDelegate {
    var onExit: ((Int32?) -> Void)?

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            self?.onExit?(exitCode)
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
