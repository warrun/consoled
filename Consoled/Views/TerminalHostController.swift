import AppKit
import SwiftUI

@MainActor
final class TerminalHostController: NSViewController {
    private let stackView = NSView()
    private var panels: [UUID: TerminalContainerView] = [:]
    private var panelConstraints: [UUID: [NSLayoutConstraint]] = [:]
    private var layoutMode: SessionLayoutMode = .tabs
    private var currentSessions: [TerminalSession] = []
    private var selectedSessionID: UUID?
    private var onSelectSession: ((UUID) -> Void)?

    override func loadView() {
        stackView.wantsLayer = true
        stackView.layer?.isOpaque = false
        stackView.layer?.backgroundColor = NSColor.clear.cgColor
        view = stackView
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if layoutMode == .tiled {
            layoutTiledPanels()
        }
    }

    func sync(
        sessions: [TerminalSession],
        selectedSessionID: UUID?,
        sshPath: String,
        layoutMode: SessionLayoutMode,
        argsForProfile: (SSHHostProfile) -> [String],
        onSelectSession: @escaping (UUID) -> Void
    ) {
        self.layoutMode = layoutMode
        self.currentSessions = sessions
        self.selectedSessionID = selectedSessionID
        self.onSelectSession = onSelectSession

        let liveIDs = Set(sessions.map(\.id))

        for id in panels.keys where !liveIDs.contains(id) {
            closeSession(id: id)
        }

        for session in sessions where panels[session.id] == nil {
            openSession(
                id: session.id,
                executable: sshPath,
                args: argsForProfile(session.profile),
                hostName: session.profile.displayName,
                profile: session.terminalProfile
            )
        }

        updatePanelThemes(sessions)
        applyLayout()
    }

    private func updatePanelThemes(_ sessions: [TerminalSession]) {
        for session in sessions {
            guard let panel = panels[session.id], panel.profile != session.terminalProfile else { continue }
            panel.applyAppearance(session.terminalProfile)
        }
    }

    private func applyLayout() {
        switch layoutMode {
        case .tabs:
            layoutTabMode()
        case .tiled:
            layoutTiledPanels()
        }
    }

    private func layoutTabMode() {
        for (id, panel) in panels {
            activateTabConstraints(for: id, panel: panel)
            panel.setPanelCornerShape(.all)
            let isSelected = id == selectedSessionID
            panel.isHidden = !isSelected
            panel.terminalView.isHidden = !isSelected
            panel.setSelected(false)
        }

        if let selectedSessionID, let panel = panels[selectedSessionID] {
            view.window?.makeFirstResponder(panel.terminalView)
        }
    }

    private func layoutTiledPanels() {
        guard !currentSessions.isEmpty else { return }

        let bounds = stackView.bounds
        let isPortrait = bounds.width < bounds.height
        let slots = SessionTileLayout.slots(count: currentSessions.count, isPortrait: isPortrait)
        let boundsSize = CGSize(width: bounds.width, height: bounds.height)

        for (index, session) in currentSessions.enumerated() {
            guard index < slots.count, let panel = panels[session.id] else { continue }

            deactivatePanelConstraints(for: session.id)
            panel.translatesAutoresizingMaskIntoConstraints = true
            panel.isHidden = false
            panel.terminalView.isHidden = false

            let rects = SessionTileLayout.tileRects(for: slots[index], in: boundsSize)
            panel.frame = SessionTileLayout.appKitTerminalFrame(from: rects, boundsHeight: bounds.height)
            panel.setPanelCornerShape(.all)

            let isSelected = session.id == selectedSessionID
            panel.setSelected(isSelected)
        }

        if let selectedSessionID, let panel = panels[selectedSessionID] {
            view.window?.makeFirstResponder(panel.terminalView)
        }
    }

    private func activateTabConstraints(for id: UUID, panel: TerminalContainerView) {
        guard panelConstraints[id] == nil else { return }

        panel.translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            panel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            panel.topAnchor.constraint(equalTo: stackView.topAnchor),
            panel.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        panelConstraints[id] = constraints
    }

    private func deactivatePanelConstraints(for id: UUID) {
        guard let constraints = panelConstraints.removeValue(forKey: id) else { return }
        NSLayoutConstraint.deactivate(constraints)
    }

    private func openSession(
        id: UUID,
        executable: String,
        args: [String],
        hostName: String,
        profile: TerminalProfile
    ) {
        let panel = TerminalContainerView(frame: view.bounds)
        panel.applyAppearance(profile)
        panel.onFocus = { [weak self] in
            self?.onSelectSession?(id)
        }
        panel.configure(
            executable: executable,
            args: args,
            onProcessStarted: {
                ConnectTiming.mark("session panel ready (\(hostName))")
            },
            onFirstOutput: {},
            onExit: { _ in }
        )

        stackView.addSubview(panel)
        panels[id] = panel
        ConnectTiming.mark("terminal panel created (\(hostName))")
    }

    private func closeSession(id: UUID) {
        guard let panel = panels.removeValue(forKey: id) else { return }
        deactivatePanelConstraints(for: id)
        panel.terminateSession()
        panel.removeFromSuperview()
    }
}

struct TerminalHostRepresentable: NSViewControllerRepresentable {
    let sessions: [TerminalSession]
    let selectedSessionID: UUID?
    let sshPath: String
    let layoutMode: SessionLayoutMode
    let argsForProfile: (SSHHostProfile) -> [String]
    let onSelectSession: (UUID) -> Void

    func makeNSViewController(context: Context) -> TerminalHostController {
        TerminalHostController()
    }

    func updateNSViewController(_ controller: TerminalHostController, context: Context) {
        controller.sync(
            sessions: sessions,
            selectedSessionID: selectedSessionID,
            sshPath: sshPath,
            layoutMode: layoutMode,
            argsForProfile: argsForProfile,
            onSelectSession: onSelectSession
        )
    }
}
