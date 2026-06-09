import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Guard quit when notes have unsaved changes: Save All / Discard / Cancel.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let unsaved = AppServices.sessionManager?.unsavedNotes ?? []
        guard !unsaved.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "You have unsaved notes"
        alert.informativeText = unsaved.count == 1
            ? "Save your note before quitting?"
            : "Save your \(unsaved.count) notes before quitting?"
        alert.addButton(withTitle: "Save All")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            for document in unsaved { _ = NotesStore.saveQuietly(document) }
            return .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .consoledPersistOnExit, object: nil)
    }
}
