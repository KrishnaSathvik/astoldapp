import Testing
import Foundation
import SwiftData
@testable import Yourly

@MainActor
struct NoteStoreDeleteTests {
    private func makeStore() throws -> (SwiftDataNoteStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        let context = ModelContext(container)
        return (SwiftDataNoteStore(context: context), context)
    }

    private func allNotes(_ context: ModelContext) throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>())
    }

    @Test func undoDeleteRestoresExactly() throws {
        let (store, _) = try makeStore()
        let n = try store.createDraft()
        n.title = "Keeper"; n.body = "body text"
        try store.save(n)
        let created = n.createdAt

        try store.delete(n)
        #expect(try store.recent(limit: 40, before: nil).isEmpty)

        try store.undoDelete(n)
        let restored = try store.recent(limit: 40, before: nil)
        #expect(restored.count == 1)
        #expect(restored.first?.title == "Keeper")
        #expect(restored.first?.body == "body text")
        #expect(restored.first?.createdAt == created)
        #expect(restored.first?.deletedAt == nil)
    }

    @Test func purgeRemovesSoftDeletedKeepsLive() throws {
        let (store, context) = try makeStore()
        let live = try store.createDraft(); live.body = "live"; try store.save(live)
        let gone = try store.createDraft(); gone.body = "gone"; try store.save(gone)
        try store.delete(gone)

        try store.purgeDeleted()

        let remaining = try allNotes(context)
        #expect(remaining.count == 1)
        #expect(remaining.first?.body == "live")
    }

    @Test func purgeWithNothingDeletedIsNoop() throws {
        let (store, context) = try makeStore()
        let n = try store.createDraft(); n.body = "x"; try store.save(n)
        try store.purgeDeleted()
        #expect(try allNotes(context).count == 1)
    }
}
