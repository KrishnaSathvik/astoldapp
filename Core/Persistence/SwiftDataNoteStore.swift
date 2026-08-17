import Foundation
import SwiftData

@MainActor
final class SwiftDataNoteStore: NoteStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    @discardableResult
    func createDraft() throws -> Note {
        let note = Note()
        context.insert(note)
        return note
    }

    func save(_ note: Note) throws {
        note.title = normalizedTitle(note.title)
        note.updatedAt = .now
        if context.hasChanges { try context.save() }
    }

    func delete(_ note: Note) throws {
        note.deletedAt = .now
        if context.hasChanges { try context.save() }
    }

    func undoDelete(_ note: Note) throws {
        note.deletedAt = nil
        if context.hasChanges { try context.save() }
    }

    /// Hard-delete any soft-deleted notes left from a prior session/undo window. See RULES.md §5.
    func purgeDeleted() throws {
        let deleted = try context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt != nil })
        )
        for note in deleted { context.delete(note) }
        if context.hasChanges { try context.save() }
    }

    func discardIfEmpty(_ note: Note) throws {
        guard note.isEmptyDraft else { return }
        context.delete(note)
        if context.hasChanges { try context.save() }
    }

    func recent(limit: Int, before: Date?) throws -> [Note] {
        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse),
                     SortDescriptor(\.id, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let all = try context.fetch(descriptor)
        if let before { return all.filter { $0.createdAt < before } }
        return all
    }

    func notes(on day: Date) throws -> [Note] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate {
                $0.deletedAt == nil && $0.createdAt >= start && $0.createdAt < end
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse),
                     SortDescriptor(\.id, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func noteDays(in month: Date) throws -> Set<Date> {
        let start = MonthMath.startOfMonth(for: month, calendar: calendar)
        let end = MonthMath.addMonths(1, to: start, calendar: calendar)
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate {
                $0.deletedAt == nil && $0.createdAt >= start && $0.createdAt < end
            }
        )
        let notes = try context.fetch(descriptor)
        return Set(notes.map { calendar.startOfDay(for: $0.createdAt) })
    }

    private var calendar: Calendar { .current }
}
