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

    @Test func finishPersistsRealNoteAndNormalizesTitle() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)
        model.title = "  Alaska  "
        model.body = "real content"
        model.finish()
        let notes = try liveNotes(context)
        #expect(notes.count == 1)
        #expect(notes.first?.title == "Alaska")
        #expect(notes.first?.body == "real content")
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

    @Test func backgroundingAnUntouchedDraftWritesNothing() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.flush()                       // what scenePhase != .active does
        try context.save()                  // anything else that saves must not resurrect it

        #expect(try liveNotes(context).isEmpty)
    }

    @Test func backgroundingAMarkerOnlyDraftWritesNothing() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.body = "- "                   // structure with no words is still empty
        model.flush()
        try context.save()

        #expect(try liveNotes(context).isEmpty)
    }

    @Test func typingAfterADiscardedDraftStillPersists() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.flush()                       // backgrounded while empty → discarded
        model.body = "back and writing"     // …then the user returns and types
        model.flush()

        let notes = try liveNotes(context)
        #expect(notes.count == 1)
        #expect(notes.first?.body == "back and writing")
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
