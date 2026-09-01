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
    /// How many visible notes each day of `month` holds. Days with none are absent, so
    /// `Set(result.keys)` is the set of days that earn a mark on the grid.
    func noteDayCounts(in month: Date) throws -> [Date: Int]
}
