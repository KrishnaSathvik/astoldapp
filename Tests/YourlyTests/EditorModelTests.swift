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
