import Testing
import Foundation
import SwiftData
@testable import Yourly

@MainActor
struct EditorModelTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    private func liveNotes(_ context: ModelContext) throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt == nil }))
    }

    @Test func finishDiscardsEmptyDraft() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.title = "   "   // whitespace only
        model.body = ""
        model.finish()
        #expect(try liveNotes(context).isEmpty)
    }

    /// Leaving the editor tidies a title of nothing but spaces into no title. It does not tidy a real
    /// one: those characters are the writer's (RULES.md §5, and `storedTitle`). This test asserted the
    /// opposite until 2026-08-20, which is how the trimming that ate the space bar got in.
    @Test func finishPersistsRealNoteAndKeepsItsTitleExactly() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.title = "  Alaska  "
        model.body = "real content"
        model.finish()
        let notes = try liveNotes(context)
        #expect(notes.count == 1)
        #expect(notes.first?.title == "  Alaska  ")
        #expect(notes.first?.body == "real content")
    }

    // MARK: The space bar
    //
    // Typing "Alaska Road Trip" used to lose its spaces on a real device. Every space is trailing
    // whitespace until the next letter arrives; the 400 ms autosave landed in that gap, the store
    // trimmed the title on its way to disk, the model published the shorter value back, and the text
    // field's caret jumped back over the space that had just been typed. Pause between words — which
    // is exactly when a person thinks — and the space bar looked broken.

    @Test func anAutosaveNeverTakesBackTheSpaceJustTyped() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.body = "content"
        model.title = "Alaska "
        model.flush()                       // what the debounced autosave runs
        #expect(model.title == "Alaska ")   // was "Alaska" before 2026-08-20
        #expect(note.title == "Alaska ")
    }

    @Test func aTitleTypedThroughAPauseIsTheTitleTyped() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.body = "content"
        for keystroke in ["Alaska", "Alaska ", "Alaska Road", "Alaska Road ", "Alaska Road Trip"] {
            model.title = keystroke
            model.flush()   // an autosave between every keystroke: the worst case, not the usual one
        }
        #expect(model.title == "Alaska Road Trip")
    }

    @Test func consecutiveAndLeadingSpacesSurviveTyping() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.body = "content"
        model.title = "My  Summer Plan"
        model.flush()
        #expect(model.title == "My  Summer Plan")
        model.title = " Alaska"
        model.flush()
        #expect(model.title == " Alaska")
    }

    @Test func backspacingBackToASpaceLeavesTheSpace() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.body = "content"
        for keystroke in ["Alaska Road", "Alaska Roa", "Alaska Ro", "Alaska R", "Alaska "] {
            model.title = keystroke
            model.flush()
        }
        #expect(model.title == "Alaska ")
    }

    @Test func aTitleWrittenWithASpaceSurvivesSaveAndReopen() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.title = "Alaska "
        model.body = "content"
        model.finish()

        let reopened = try #require(try liveNotes(context).first)
        #expect(reopened.title == "Alaska ")
        #expect(EditorModel(note: reopened, context: context).title == "Alaska ")
    }

    /// Leaving the title for the body is the one moment the value may be tidied — and even then, only
    /// a title that is nothing but whitespace becomes no title at all.
    @Test func leavingTheTitleFieldTidiesOnlyAnEmptyTitle() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.body = "content"

        model.title = "Alaska "
        model.endTitleEditing()
        #expect(note.title == "Alaska ")

        model.title = "   "
        model.endTitleEditing()
        #expect(note.title == nil)
    }

    @Test func titleThenBodyThenTitleAgainKeepsEveryCharacter() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.title = "Alaska "
        model.endTitleEditing()
        model.body = "Day 1"
        model.flush()
        model.title = "Alaska Road Trip"
        model.flush()
        #expect(model.title == "Alaska Road Trip")
        #expect(model.body == "Day 1")
    }

    @Test func editingDoesNotChangeCreatedAt() throws {
        let context = try makeContext()
        let original = Date.now.addingTimeInterval(-100_000)  // an old note
        let note = Note(title: "old", body: "before", createdAt: original, updatedAt: original)
        context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.body = "after"
        model.flush()
        #expect(note.createdAt == original)          // timeline position preserved
        #expect(note.updatedAt > original)           // edit recorded on updatedAt only
    }

    @Test func flushKeepsBodyVerbatim() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.body = "line one\n\n  spaced  line"
        model.flush()
        #expect(note.body == "line one\n\n  spaced  line")   // no rewriting of user spacing
    }
}

/// Empty drafts must not survive a session that ends without the user leaving the editor:
/// compose → background → iOS terminates the app → relaunch must show nothing (RULES.md §1, §4).
@MainActor
struct EmptyDraftDurabilityTests {
    /// A fresh container over the same on-disk-shaped store, so "what a relaunch would see" is a
    /// real fetch rather than the in-memory object graph.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    private func liveNotes(_ context: ModelContext) throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt == nil }))
    }

    /// A temporary scene transition must never invalidate a draft the editor still owns.
    ///
    /// This used to assert the opposite — that backgrounding an untouched draft wrote nothing,
    /// implemented by deleting it from the context. The deletion was *committed*, and re-inserting
    /// the same model afterwards did not bring it back, so anything the user wrote next was lost
    /// silently while the editor went on showing it. Keeping the draft is the weaker cleanup
    /// promise and the stronger correctness one; `finish()` and the launch sweep still remove it.
    @Test func backgroundingKeepsAnUntouchedDraftUsable() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.flush()                       // what scenePhase != .active does

        #expect(try liveNotes(context).count == 1)
    }

    @Test func typingAfterBackgroundingAnEmptyDraftPersists() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.flush()                       // backgrounded while still empty
        model.body = "back and writing"     // …then the user returns and types
        model.flush()

        let notes = try liveNotes(context)
        #expect(notes.count == 1)
        #expect(notes.first?.body == "back and writing")
    }

    /// A voice transcript is the same story: it lands after the interruption, into the same note.
    @Test func aTranscriptAfterBackgroundingAnEmptyDraftPersists() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.flush()                       // the microphone permission alert resigns active
        model.insertVoiceTranscript("what I said out loud", atUTF16: 0)
        model.finish()

        let notes = try liveNotes(context)
        #expect(notes.count == 1)
        #expect(notes.first?.body.contains("what I said out loud") == true)
    }

    /// Repeated scene churn must not duplicate the note or leave a second copy behind.
    @Test func repeatedBackgroundingDoesNotDuplicateTheDraft() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        for _ in 0..<5 { model.flush() }
        model.body = "written after all that churn"
        for _ in 0..<5 { model.flush() }

        #expect(try liveNotes(context).count == 1)
    }

    /// Leaving is still the moment a marker-only draft counts as abandoned: structure with no words
    /// is not content.
    @Test func leavingAMarkerOnlyDraftRemovesIt() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.body = "- "                   // structure with no words is still empty
        model.finish()

        #expect(try liveNotes(context).isEmpty)
    }

    @Test func emptyingAnExistingNoteKeepsTheUsersDeletion() throws {
        let context = try makeContext()
        let note = Note(title: "Alaska", body: "real content"); context.insert(note)
        try context.save()

        let model = EditorModel(note: note, context: context)
        model.title = ""
        model.body = ""
        model.flush()                       // already on disk: the emptying must stick

        #expect(try liveNotes(context).first?.body == "")
    }

    @Test func launchSweepRemovesStrandedEmptyDrafts() throws {
        let context = try makeContext()
        let store = SwiftDataNoteStore(context: context)
        // Exactly what a pre-fix build could have left behind.
        context.insert(Note(title: nil, body: ""))
        context.insert(Note(title: "   ", body: "  \n "))
        context.insert(Note(title: nil, body: "- [ ] "))
        context.insert(Note(title: nil, body: "- milk"))            // real content
        context.insert(Note(title: "Alaska", body: ""))             // real title
        try context.save()

        try store.purgeEmptyDrafts()

        let survivors = try liveNotes(context)
        #expect(survivors.count == 2)
        #expect(Set(survivors.map { $0.title ?? $0.body }) == ["Alaska", "- milk"])
    }

    @Test func launchSweepLeavesSoftDeletedNotesToTheirOwnPurge() throws {
        let context = try makeContext()
        let store = SwiftDataNoteStore(context: context)
        let deleted = Note(title: nil, body: "words", deletedAt: .now)
        context.insert(deleted)
        try context.save()

        try store.purgeEmptyDrafts()

        #expect(try context.fetch(FetchDescriptor<Note>()).count == 1)
    }
}
