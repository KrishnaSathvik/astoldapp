import SwiftUI
import SwiftData

/// Autosave coordinator: debounce typing, flush on leave/background, discard empty drafts.
/// See docs/05-architecture.md §11 and RULES.md §4.
@Observable @MainActor
final class EditorModel {
    let note: Note
    private let store: NoteStore
    private var saveTask: Task<Void, Never>?
    /// True once the draft has been discarded on the way out, so a late autosave cannot write it back.
    private var isDiscarded = false

    init(note: Note, context: ModelContext, store: NoteStore? = nil) {
        self.note = note
        self.store = store ?? SwiftDataNoteStore(context: context)
    }

    var title: String {
        get { note.title ?? "" }
        set { note.title = newValue; scheduleSave() }
    }

    /// The writer has left the title field. This is the one moment its value may be tidied: a title of
    /// nothing but spaces becomes no title at all (RULES.md §5), and anything else is kept exactly as
    /// typed. Doing this *during* editing is what used to swallow every space (see `storedTitle`).
    func endTitleEditing() {
        let stored = storedTitle(note.title)
        if note.title != stored {
            note.title = stored
            scheduleSave()
        }
    }

    var body: String {
        get { note.body }
        set { note.body = newValue; scheduleSave() }
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
        note.body = newBody
        flush()
        return cursor
    }

    /// Persist current content (normalizing the title). Bumps updatedAt, never createdAt.
    ///
    /// **A flush never discards.** Backgrounding, an interruption, or a permission alert is a
    /// temporary scene transition, not abandonment — the editor still owns this note, and the user
    /// may be about to type into it or have a transcript land in it. Discarding here used to delete
    /// the draft *and commit the deletion*, after which re-inserting the same model did not bring it
    /// back: the editor went on showing the content while the timeline no longer had the note at
    /// all. That is silent data loss, and it cost nothing to write an empty draft instead.
    ///
    /// So an empty draft is simply saved like any other state. `finish()` discards it when the user
    /// actually leaves the editor, and `purgeEmptyDrafts` at the next launch clears one stranded by a
    /// termination — which is exactly what RULES.md §4 asks for ("on exit").
    func flush() {
        guard !isDiscarded else { return }
        canonicalizeBody()
        try? store.save(note)
    }

    /// Drops a queued autosave without running it — for a note that is being deleted.
    func cancelPendingSave() {
        saveTask?.cancel()
        saveTask = nil
    }

    /// Call when leaving the editor: the one moment an empty draft is genuinely abandoned, and so
    /// the only place it is discarded (RULES.md §4, "on exit").
    func finish() {
        saveTask?.cancel()
        if note.isEmptyDraft {
            discard()
        } else {
            note.title = storedTitle(note.title)
            canonicalizeBody()
            try? store.save(note)
        }
    }

    /// Removes the abandoned empty draft. Reached only from `finish()`, once the editor is done with
    /// the note — nothing resurrects it afterwards, because a committed SwiftData deletion cannot be
    /// undone by re-inserting the same model instance. Safe to call repeatedly.
    private func discard() {
        guard !isDiscarded else { return }
        isDiscarded = true
        saveTask?.cancel()
        try? store.discardIfEmpty(note)
    }
}
