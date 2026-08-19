import SwiftUI
import SwiftData

/// Autosave coordinator: debounce typing, flush on leave/background, discard empty drafts.
/// See docs/05-architecture.md §11 and RULES.md §4.
@Observable @MainActor
final class EditorModel {
    let note: Note
    private let context: ModelContext
    private let store: NoteStore
    private var saveTask: Task<Void, Never>?
    /// True once this draft has been discarded from the context for being empty. It is not on disk,
    /// and it is put back the moment the user types again.
    private var isDiscarded = false
    /// Whether this note has ever been written to disk. A draft that never reached disk can be
    /// discarded and re-inserted freely; one that did cannot (SwiftData does not restore a saved
    /// model that was deleted), so it is left for `finish()` or the launch sweep instead.
    private var hasReachedDisk: Bool

    init(note: Note, context: ModelContext, store: NoteStore? = nil) {
        self.note = note
        self.context = context
        self.store = store ?? SwiftDataNoteStore(context: context)
        // An existing note arrives already persisted; a fresh draft does not.
        self.hasReachedDisk = !note.isEmptyDraft
    }

    var title: String {
        get { note.title ?? "" }
        set { restoreIfDiscarded(); note.title = newValue; scheduleSave() }
    }

    var body: String {
        get { note.body }
        set { restoreIfDiscarded(); note.body = newValue; scheduleSave() }
    }

    /// Normalizes tolerated marker spellings before the note is written. Parsing accepts `- [X] `
    /// because that is what a capitalizing keyboard produces; only `- [x] ` is ever stored, so no
    /// later operation has to know about the other one. The rewrite is same-length, so an open
    /// editor's caret and selection survive it untouched.
    private func canonicalizeBody() {
        let canonical = StructuredText.canonicalized(note.body)
        if canonical != note.body { note.body = canonical }
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
        restoreIfDiscarded()
        note.body = newBody
        flush()
        return cursor
    }

    /// Persist current content (normalizing the title). Bumps updatedAt, never createdAt.
    ///
    /// A new empty draft is never *written*: a session that ends right here — backgrounded and then
    /// terminated by iOS — must leave nothing behind (RULES.md §1, §4), so it is dropped from the
    /// context instead. A note that already reached disk and has since been emptied is written as
    /// empty, so the user's own deletion sticks; it cannot be deleted here without stranding the
    /// open editor on a model SwiftData will not restore, so `finish()` removes it when the user
    /// leaves, and `purgeEmptyDrafts` at the next launch removes it if they never come back.
    func flush() {
        guard !note.isEmptyDraft else {
            if hasReachedDisk { try? store.save(note) } else { discard() }
            return
        }
        canonicalizeBody()
        try? store.save(note)
        hasReachedDisk = true
    }

    /// Drops a queued autosave without running it — for a note that is being deleted.
    func cancelPendingSave() {
        saveTask?.cancel()
        saveTask = nil
    }

    /// Call when leaving the editor: flush, or discard the note if it is an empty draft.
    func finish() {
        saveTask?.cancel()
        if note.isEmptyDraft {
            discard()
        } else {
            canonicalizeBody()
            try? store.save(note)
            hasReachedDisk = true
        }
    }

    /// Drops an empty draft from the context so it never reaches disk. Safe to call repeatedly.
    private func discard() {
        guard !isDiscarded else { return }
        try? store.discardIfEmpty(note)
        isDiscarded = true
    }

    /// Puts a discarded draft back the moment the user writes into it again. Only ever reached by a
    /// draft that never touched disk, which SwiftData re-inserts cleanly.
    private func restoreIfDiscarded() {
        guard isDiscarded else { return }
        context.insert(note)
        isDiscarded = false
    }
}
