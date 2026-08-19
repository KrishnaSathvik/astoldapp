import Foundation

/// Small persistence boundary so feature code stays testable and the backing store stays swappable.
/// See docs/05-architecture.md §7.
@MainActor
protocol NoteStore {
    @discardableResult func createDraft() throws -> Note
    func save(_ note: Note) throws
    func delete(_ note: Note) throws
    func undoDelete(_ note: Note) throws
    func purgeDeleted() throws
    func purgeEmptyDrafts() throws
    func discardIfEmpty(_ note: Note) throws
    func recent(limit: Int, before: Date?) throws -> [Note]
    func notes(on day: Date) throws -> [Note]
    func noteDays(in month: Date) throws -> Set<Date>
}
