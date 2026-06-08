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

    func applyCornerShape(_ shape: TerminalContainerView.PanelCornerShape) {
        let radius = TerminalProfile.panelCornerRadius
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
}

final class TerminalContainerView: NSView {
    let terminalView = ConsoledTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    private let frostBackdrop = NSVisualEffectView()
    private let panelPlate = TerminalPanelPlate()
    var onFocus: (() -> Void)?
    private var started = false
    private var pendingExecutable: String?
    private var pendingArgs: [String] = []
    private var onProcessStarted: (() -> Void)?
    private var onFirstOutput: (() -> Void)?
    private var onExit: ((Int32?) -> Void)?
    private let exitHandler = TerminalExitHandler()
    private(set) var profile: TerminalProfile = .homebrew

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

        let padding = TerminalProfile.textPadding
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
        applyAppearance(.homebrew)
    }

    func updateFrostedBackdrop(profile: TerminalProfile) {
        frostBackdrop.material = .hudWindow
        frostBackdrop.state = .active
        panelPlate.fillColor = profile.background
        applyPanelChrome()
    }

    enum PanelCornerShape {
        case all
        case bottomOnly
    }

    private var panelCornerShape: PanelCornerShape = .all

    func setPanelCornerShape(_ shape: PanelCornerShape) {
        panelCornerShape = shape
        applyPanelChrome()
    }

    private func applyPanelChrome() {
        let radius = TerminalProfile.panelCornerRadius
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

    func applyAppearance(_ profile: TerminalProfile) {
        self.profile = profile
        TerminalAppearance.applyContainer(profile, to: self)
        TerminalAppearance.apply(profile, to: terminalView)
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
        onProcessStarted: @escaping () -> Void,
        onFirstOutput: @escaping () -> Void,
        onExit: @escaping (Int32?) -> Void
    ) {
        pendingExecutable = executable
        pendingArgs = args
        self.onProcessStarted = onProcessStarted
        self.onFirstOutput = onFirstOutput
        self.onExit = onExit

        terminalView.resetOutputTracking()
        terminalView.onFirstOutput = onFirstOutput

        exitHandler.onExit = { [weak self] exitCode in
            guard let self else { return }
            if let exitCode, exitCode != 0 {
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
            execName: "ssh"
        )
        ConnectTiming.mark("startProcess(ssh)")
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
