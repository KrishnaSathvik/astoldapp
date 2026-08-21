import Testing
import Foundation
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

    /// The store writes the note down; it does not edit it. An autosave lands 400 ms after a
    /// keystroke — mid-word, mid-space — so a store that normalized on its way past was rewriting a
    /// title while it was still being typed. `EditorModel.endTitleEditing` and `finish()` do that
    /// tidying now, at the only moment there is nothing left to interrupt (changed 2026-08-20).
    @Test func saveKeepsTheTitleExactlyAsTheWriterLeftIt() throws {
        let store = try makeStore()
        let n = try store.createDraft(); n.body = "b"; n.title = "Alaska "
        try store.save(n)
        #expect(n.title == "Alaska ")
    }

    @Test func aWhitespaceOnlyTitleStillCountsAsNoTitle() throws {
        let store = try makeStore()
        let n = try store.createDraft(); n.body = "b"; n.title = "   "
        try store.save(n)
        // Untouched in storage, and still not a title anywhere it is read or judged.
        #expect(n.title == "   ")
        #expect(normalizedTitle(n.title) == nil)
        #expect(storedTitle(n.title) == nil)
    }
}

/// `recent(limit:before:)` is a cursor, not a page number: the cursor has to narrow the fetch
/// itself, or every page after the first comes back empty (docs/05-architecture.md §8).
@MainActor
struct NoteStorePagingTests {
    private func makeStore() throws -> (SwiftDataNoteStore, ModelContext) {
        let container = try NoteStoreContainer.make(inMemory: true)
        let context = ModelContext(container)
        return (SwiftDataNoteStore(context: context), context)
    }

    /// 25 notes, newest last-created. Bodies are "note-00" … "note-24".
    private func seed(_ context: ModelContext, count: Int = 25) throws {
        for i in 0..<count {
            context.insert(Note(body: String(format: "note-%02d", i),
                                createdAt: Date(timeIntervalSince1970: TimeInterval(i * 60))))
        }
        try context.save()
    }

    @Test func cursorReturnsTheNextPageRatherThanNothing() throws {
        let (store, context) = try makeStore()
        try seed(context)

        let first = try store.recent(limit: 10, before: nil)
        #expect(first.count == 10)
        #expect(first.first?.body == "note-24")
        #expect(first.last?.body == "note-15")

        let second = try store.recent(limit: 10, before: first.last?.createdAt)
        #expect(second.count == 10)
        #expect(second.first?.body == "note-14")
        #expect(second.last?.body == "note-05")
    }

    @Test func pagingWalksEveryNoteExactlyOnce() throws {
        let (store, context) = try makeStore()
        try seed(context)

        var seen: [String] = []
        var cursor: Date?
        while true {
            let page = try store.recent(limit: 7, before: cursor)
            if page.isEmpty { break }
            seen.append(contentsOf: page.map(\.body))
            cursor = page.last?.createdAt
        }

        #expect(seen.count == 25)
        #expect(Set(seen).count == 25)                        // nothing repeated
        #expect(seen == seen.sorted(by: >))                   // newest-first throughout
    }

    @Test func pagingSkipsSoftDeletedNotes() throws {
        let (store, context) = try makeStore()
        try seed(context, count: 5)
        let all = try store.recent(limit: 10, before: nil)
        try store.delete(all[1])                              // "note-03"

        let page = try store.recent(limit: 10, before: all[0].createdAt)
        #expect(page.map(\.body) == ["note-02", "note-01", "note-00"])
    }

    @Test func aCursorPastTheOldestNoteReturnsEmpty() throws {
        let (store, context) = try makeStore()
        try seed(context, count: 3)
        let oldest = try store.recent(limit: 10, before: nil).last!
        #expect(try store.recent(limit: 10, before: oldest.createdAt).isEmpty)
    }
}
