import Testing
import SwiftData
@testable import Yourly

@MainActor
struct NoteStoreTests {
    private func makeStore() throws -> SwiftDataNoteStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return SwiftDataNoteStore(context: ModelContext(container))
    }

    @Test func createAndFetchRecent() throws {
        let store = try makeStore()
        let n = try store.createDraft()
        n.body = "Hello"
        try store.save(n)
        let recent = try store.recent(limit: 40, before: nil)
        #expect(recent.count == 1)
        #expect(recent.first?.body == "Hello")
    }

    @Test func recentIsNewestFirst() throws {
        let store = try makeStore()
        let older = try store.createDraft()
        older.body = "older"; older.createdAt = .now.addingTimeInterval(-100)
        try store.save(older)
        let newer = try store.createDraft()
        newer.body = "newer"; newer.createdAt = .now
        try store.save(newer)
        #expect(try store.recent(limit: 40, before: nil).map(\.body) == ["newer", "older"])
    }

    @Test func softDeletedExcluded() throws {
        let store = try makeStore()
        let n = try store.createDraft(); n.body = "x"; try store.save(n)
        try store.delete(n)
        #expect(try store.recent(limit: 40, before: nil).isEmpty)
    }

    @Test func discardIfEmptyRemovesBlankDraft() throws {
        let store = try makeStore()
        let n = try store.createDraft()
        n.title = "   "; n.body = "\n "
        try store.discardIfEmpty(n)
        #expect(try store.recent(limit: 40, before: nil).isEmpty)
    }

    @Test func discardIfEmptyKeepsRealNote() throws {
        let store = try makeStore()
        let n = try store.createDraft(); n.body = "real"
        try store.discardIfEmpty(n)
        #expect(try store.recent(limit: 40, before: nil).count == 1)
    }

    @Test func saveNormalizesTitle() throws {
        let store = try makeStore()
        let n = try store.createDraft(); n.body = "b"; n.title = "   "
        try store.save(n)
        #expect(n.title == nil)
    }
}
