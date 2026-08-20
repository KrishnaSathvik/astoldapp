import Foundation

/// What a reader is allowed to see — the presentation half of the draft lifecycle (RULES.md §4).
///
/// Persistence and presentation are deliberately not the same question. An editor is *allowed* to
/// own an effectively empty draft, and that permission is what stops a temporary scene transition
/// from destroying a note the user is still writing. But an empty draft is not something anyone
/// asked to read, so it must never reach a screen: Home rendered one as a zero-height row and the
/// separator that row carried survived as a stray line under `Today` for the moment between leaving
/// an untouched New Note and `finish()`'s deletion propagating (2026-08-20).
///
/// So: the store keeps what it must, and every list of notes a person looks at goes through here
/// first. One rule, one definition of empty — `Note.isEmptyDraft`, the same one the editor discards
/// by — so the timeline and the editor can never disagree about what counts as a note.
extension Note {
    /// True when this note is something the reader should see: live, and carrying actual content.
    var isUserVisible: Bool { deletedAt == nil && !isEmptyDraft }
}

/// Filters a fetched list down to the notes a reader should see, preserving order.
///
/// Use this at every point that turns notes into rows or marks — Home, Search, the calendar's day
/// list and its dots. Filtering here rather than hiding separators is deliberate: the separator is
/// legitimate, the invisible row underneath it was not.
func userVisibleNotes(_ notes: [Note]) -> [Note] {
    notes.filter(\.isUserVisible)
}
