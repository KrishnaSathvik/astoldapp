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

    /// Insert a voice transcript into the body at the given UTF-16 caret offset, then autosave. The
    /// words are preserved verbatim (only boundary whitespace may be added); conservative structure
    /// commands are applied where clearly spoken, otherwise the transcript is inserted as-is
    /// (RULES.md §2). Returns the caret position after the insertion as a UTF-16 offset.
    @discardableResult
    func insertVoiceTranscript(_ transcript: String, atUTF16 offset: Int) -> Int {
        let (newBody, cursor) = VoiceStructureParser.apply(transcript, into: note.body, atUTF16: offset)
        note.body = newBody
        flush()
        return cursor
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
