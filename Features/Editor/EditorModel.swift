import SwiftUI
import SwiftData

/// Autosave coordinator: debounce typing, flush on leave/background, discard empty drafts.
/// See docs/05-architecture.md §11 and RULES.md §4.
@Observable @MainActor
final class EditorModel {
    let note: Note
    private let context: ModelContext
    private var saveTask: Task<Void, Never>?

    init(note: Note, context: ModelContext) {
        self.note = note
        self.context = context
    }

    var title: String {
        get { note.title ?? "" }
        set { note.title = newValue; scheduleSave() }
    }

    var body: String {
        get { note.body }
        set { note.body = newValue; scheduleSave() }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Persist current content (normalizing the title). Bumps updatedAt, never createdAt.
    func flush() {
        note.title = normalizedTitle(note.title)
        note.updatedAt = .now
        if context.hasChanges { try? context.save() }
    }

    /// Call when leaving the editor: flush, or discard the note if it is an empty draft.
    func finish() {
        saveTask?.cancel()
        if note.isEmptyDraft {
            context.delete(note)
        } else {
            note.title = normalizedTitle(note.title)
            note.updatedAt = .now
        }
        if context.hasChanges { try? context.save() }
    }
}
