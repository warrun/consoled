import AppKit
import SwiftUI

@MainActor
final class TerminalHostController: NSViewController {
    private let stackView = NSView()
    private var panels: [UUID: NSView & SessionPanel] = [:]
    private var panelConstraints: [UUID: [NSLayoutConstraint]] = [:]
    private var layoutMode: SessionLayoutMode = .tabs
    private var currentSessions: [TerminalSession] = []
    private var selectedSessionID: UUID?
    private var onSelectSession: ((UUID) -> Void)?
    private var tileIsPortrait: ((CGSize) -> Bool)?
    private var notesDocumentProvider: ((UUID) -> NotesDocument?)?
    private var notesOpacity: CGFloat = 0.85

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
        layoutMode: SessionLayoutMode,
        notesOpacity: CGFloat,
        tileIsPortrait: @escaping (CGSize) -> Bool,
        launch: (TerminalSession) -> TerminalLaunch,
        notesDocument: @escaping (UUID) -> NotesDocument?,
        onSelectSession: @escaping (UUID) -> Void
    ) {
        self.layoutMode = layoutMode
        self.currentSessions = sessions
        self.selectedSessionID = selectedSessionID
        self.onSelectSession = onSelectSession
        self.tileIsPortrait = tileIsPortrait
        self.notesDocumentProvider = notesDocument
        self.notesOpacity = notesOpacity

        let liveIDs = Set(sessions.map(\.id))

        for id in panels.keys where !liveIDs.contains(id) {
            closeSession(id: id)
        }

        for session in sessions where panels[session.id] == nil {
            openSession(session: session, launch: launch(session))
        }

        // Push the current notes opacity to any notes panels.
        for session in sessions where session.isNotes {
            (panels[session.id] as? NotesContainerView)?.setNotesOpacity(notesOpacity)
        }

        updatePanelThemes(sessions)
        applyLayout()
    }

    private func updatePanelThemes(_ sessions: [TerminalSession]) {
        for session in sessions {
            guard let panel = panels[session.id], panel.theme != session.terminalTheme else { continue }
            panel.applyAppearance(session.terminalTheme)
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
            panel.focusView.isHidden = !isSelected
            panel.setSelected(false)
        }

        if let selectedSessionID, let panel = panels[selectedSessionID] {
            view.window?.makeFirstResponder(panel.focusView)
        }
    }

    private func layoutTiledPanels() {
        guard !currentSessions.isEmpty else { return }

        let bounds = stackView.bounds
        let boundsSize = CGSize(width: bounds.width, height: bounds.height)
        let isPortrait = tileIsPortrait?(boundsSize) ?? (bounds.width < bounds.height)
        let slots = SessionTileLayout.slots(count: currentSessions.count, isPortrait: isPortrait)

        for (index, session) in currentSessions.enumerated() {
            guard index < slots.count, let panel = panels[session.id] else { continue }

            deactivatePanelConstraints(for: session.id)
            panel.translatesAutoresizingMaskIntoConstraints = true
            panel.isHidden = false
            panel.focusView.isHidden = false

            let rects = SessionTileLayout.tileRects(for: slots[index], in: boundsSize)
            panel.frame = SessionTileLayout.appKitTerminalFrame(from: rects, boundsHeight: bounds.height)
            panel.setPanelCornerShape(.all)

            let isSelected = session.id == selectedSessionID
            panel.setSelected(isSelected)
        }

        if let selectedSessionID, let panel = panels[selectedSessionID] {
            view.window?.makeFirstResponder(panel.focusView)
        }
    }

    private func activateTabConstraints(for id: UUID, panel: NSView & SessionPanel) {
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

    private func openSession(session: TerminalSession, launch: TerminalLaunch) {
        let id = session.id
        let title = session.title

        if session.isNotes, let document = notesDocumentProvider?(id) {
            let notes = NotesContainerView(
                document: document,
                theme: session.terminalTheme,
                notesOpacity: notesOpacity
            )
            notes.onFocus = { [weak self] in self?.onSelectSession?(id) }
            stackView.addSubview(notes)
            panels[id] = notes
            return
        }

        let panel = TerminalContainerView(frame: view.bounds)
        panel.applyAppearance(session.terminalTheme)
        panel.onFocus = { [weak self] in
            self?.onSelectSession?(id)
        }
        panel.configure(
            executable: launch.executable,
            args: launch.args,
            execName: launch.execName,
            currentDirectory: launch.currentDirectory,
            onProcessStarted: {
                ConnectTiming.mark("session panel ready (\(title))")
            },
            onFirstOutput: {},
            onExit: { _ in }
        )

        stackView.addSubview(panel)
        panels[id] = panel
        ConnectTiming.mark("terminal panel created (\(title))")
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
    let layoutMode: SessionLayoutMode
    let notesOpacity: CGFloat
    let tileIsPortrait: (CGSize) -> Bool
    let launch: (TerminalSession) -> TerminalLaunch
    let notesDocument: (UUID) -> NotesDocument?
    let onSelectSession: (UUID) -> Void

    func makeNSViewController(context: Context) -> TerminalHostController {
        TerminalHostController()
    }

    func updateNSViewController(_ controller: TerminalHostController, context: Context) {
        controller.sync(
            sessions: sessions,
            selectedSessionID: selectedSessionID,
            layoutMode: layoutMode,
            notesOpacity: notesOpacity,
            tileIsPortrait: tileIsPortrait,
            launch: launch,
            notesDocument: notesDocument,
            onSelectSession: onSelectSession
        )
    }
}
