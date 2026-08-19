import SwiftUI
import SwiftData

/// The short reversible-delete window: soft-delete now, offer Undo for a moment, then let the
/// record age out to the launch purge (RULES.md §4 core rule 8, §5).
///
/// Owned by each screen that can delete a note — Home and Calendar — so the Undo banner appears
/// where the user actually is, rather than on a screen they have already left. The timer lives here
/// instead of being written twice.
@Observable @MainActor
final class NoteDeletion {
    /// The note awaiting Undo, or nil. Screens show `UndoBanner` while this is non-nil.
    private(set) var pending: Note?

    private let window: Duration
    private var dismissal: Task<Void, Never>?

    init(window: Duration = .seconds(4)) {
        self.window = window
    }

    func delete(_ note: Note, in context: ModelContext) {
        try? SwiftDataNoteStore(context: context).delete(note)
        pending = note
        dismissal?.cancel()
        dismissal = Task { [window] in
            try? await Task.sleep(for: window)
            guard !Task.isCancelled else { return }
            pending = nil
        }
    }

    func undo(in context: ModelContext) {
        dismissal?.cancel()
        dismissal = nil
        guard let note = pending else { return }
        try? SwiftDataNoteStore(context: context).undoDelete(note)
        pending = nil
    }
}
