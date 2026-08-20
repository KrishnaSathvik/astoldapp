import Testing
import Foundation
import SwiftData
@testable import Yourly

/// A draft an editor still owns may exist in persistence; it must never be something a reader sees.
///
/// Regression cover for a transient ghost row on Home (2026-08-20): tapping New note inserts the
/// draft immediately, so between opening an untouched note and `finish()`'s deletion propagating,
/// Home held a row with nothing in it — and the separator that row carried showed up as a stray line
/// under `Today`, above the note that was actually there.
///
/// The window is a few frames wide, so this is where it is pinned down rather than in a UI test: the
/// state is set up exactly as `HomeView.newNote()` sets it up — an empty draft inserted and live —
/// and everything that turns notes into rows is asked what it would render.
@MainActor
struct NoteVisibilityTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    /// One real note, plus the empty draft the compose button has just inserted.
    private func homeWithAnOpenDraft() throws -> (ModelContext, Note, Note) {
        let context = try makeContext()
        let existing = Note(title: "Alaska trip idea", body: "rent a car and drive to Seward")
        context.insert(existing)
        try context.save()
        let draft = Note()            // exactly what HomeView.newNote() inserts
        context.insert(draft)
        try context.save()
        return (context, existing, draft)
    }

    // MARK: The rule itself

    @Test func emptyDraftIsNotUserVisible() {
        #expect(Note().isUserVisible == false)
        #expect(Note(title: "   ", body: "\n ").isUserVisible == false)
        #expect(Note(body: "- ").isUserVisible == false)          // a marker is not content
    }

    @Test func realNotesAreUserVisible() {
        #expect(Note(body: "something").isUserVisible)
        #expect(Note(title: "A title", body: "").isUserVisible)   // a title alone is a note
    }

    @Test func softDeletedNoteIsNotUserVisible() {
        #expect(Note(body: "real", deletedAt: .now).isUserVisible == false)
    }

    /// The editor and the timeline must never disagree about what counts as a note.
    @Test func visibilityUsesTheEditorsOwnEmptinessRule() {
        for note in [Note(), Note(title: " ", body: " "), Note(body: "# "), Note(body: "words")] {
            #expect(note.isUserVisible == (note.deletedAt == nil && !note.isEmptyDraft))
        }
    }

    // MARK: What Home would render

    @Test func homeRendersNoRowForAnOpenEmptyDraft() throws {
        let (_, existing, _) = try homeWithAnOpenDraft()
        let visible = userVisibleNotes([Note(), existing])
        #expect(visible.map(\.id) == [existing.id])
    }

    /// The stray line itself: the timeline draws a separator *between* rows, so a second, invisible
    /// row in the group is what put one under `Today`. One visible note means zero separators.
    @Test func anOpenEmptyDraftAddsNoSeparatorToItsDayGroup() throws {
        let (_, existing, draft) = try homeWithAnOpenDraft()
        let groups = groupedByDay(userVisibleNotes([draft, existing]))
        #expect(groups.count == 1)
        #expect(groups.first?.notes.count == 1)                   // → count - 1 == 0 separators
        #expect(groups.first?.notes.first?.id == existing.id)
    }

    /// And the existing note does not shift: it is the first row before the draft exists and after.
    @Test func theExistingNoteKeepsItsPlaceWhileADraftIsOpen() throws {
        let (context, existing, draft) = try homeWithAnOpenDraft()
        let store = SwiftDataNoteStore(context: context)
        #expect(try store.recent(limit: 40, before: nil).map(\.id) == [existing.id])
        try store.discardIfEmpty(draft)
        #expect(try store.recent(limit: 40, before: nil).map(\.id) == [existing.id])
    }

    // MARK: Search and the calendar reach the same drafts

    @Test func searchNeverMatchesAnOpenEmptyDraft() throws {
        let (_, existing, draft) = try homeWithAnOpenDraft()
        draft.body = "  "
        let results = searchNotes(userVisibleNotes([draft, existing]), query: "a")
        #expect(results.map(\.id) == [existing.id])
    }

    @Test func aDayWithOnlyAnOpenEmptyDraftGetsNoDot() throws {
        let context = try makeContext()
        let draft = Note()
        context.insert(draft)
        try context.save()
        let store = SwiftDataNoteStore(context: context)
        #expect(try store.noteDays(in: draft.createdAt).isEmpty)
        #expect(try store.notes(on: draft.createdAt).isEmpty)
    }

    // MARK: Persistence is still allowed to hold it

    /// Hiding the row must not turn into hiding the *note*: the draft is still there for the editor
    /// that owns it, and `finish()` is still what removes it (RULES.md §4).
    @Test func theDraftStillExistsForTheEditorAndIsRemovedOnFinish() throws {
        let (context, _, draft) = try homeWithAnOpenDraft()
        let live = try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt == nil }))
        #expect(live.count == 2)                                  // persistence keeps both

        let model = EditorModel(note: draft, context: context)
        model.finish()
        let after = try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt == nil }))
        #expect(after.count == 1)
        #expect(after.first?.body == "rent a car and drive to Seward")
    }
}
