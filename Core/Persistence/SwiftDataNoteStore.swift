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

    /// Longest body that could still be empty: the longest structure marker ("- [ ] " / "- [x] ")
    /// plus a little slack for stray whitespace. Anything longer necessarily carries visible words.
    private static let emptyDraftBodyBudget = 12

    /// Removes notes holding no visible content — drafts stranded when the app was terminated while
    /// an editor was open. Runs at launch beside `purgeDeleted` (RULES.md §4, "empty drafts").
    ///
    /// The fetch is narrowed to short bodies so launch stays cheap at realistic note counts; the
    /// decision itself is the canonical `isEmptyDraft` rule, so a marker-only body ("- ", "# ")
    /// still counts as empty, and a note carrying only a title is kept.
    func purgeEmptyDrafts() throws {
        let budget = Self.emptyDraftBodyBudget
        let candidates = try context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate<Note> { note in
                note.deletedAt == nil && note.body.count < budget
            })
        )
        for note in candidates where note.isEmptyDraft { context.delete(note) }
        if context.hasChanges { try context.save() }
    }

    func discardIfEmpty(_ note: Note) throws {
        guard note.isEmptyDraft else { return }
        context.delete(note)
        if context.hasChanges { try context.save() }
    }

    /// One page of the timeline, newest first. `before` is a cursor, not a page number: it belongs
    /// **inside** the fetch, because a limit applied first would return the newest `limit` notes and
    /// then discard the ones the cursor asked for — leaving every page after the first empty
    /// (docs/05-architecture.md §8, RULES.md §5).
    func recent(limit: Int, before: Date?) throws -> [Note] {
        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate {
                $0.deletedAt == nil && (before == nil || $0.createdAt < before!)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse),
                     SortDescriptor(\.id, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        // Browse reads never hand back a draft an open editor still owns (`NoteVisibility`). The
        // filter runs after the limit, so a page can come back one short while such a draft exists —
        // harmless, because the cursor is a date rather than a count, and there is at most one.
        return userVisibleNotes(try context.fetch(descriptor))
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
        return userVisibleNotes(try context.fetch(descriptor))
    }

    func noteDays(in month: Date) throws -> Set<Date> {
        let start = MonthMath.startOfMonth(for: month, calendar: calendar)
        let end = MonthMath.addMonths(1, to: start, calendar: calendar)
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate {
                $0.deletedAt == nil && $0.createdAt >= start && $0.createdAt < end
            }
        )
        // A day earns its dot from a note the reader can actually open — an empty draft held by an
        // open editor must not light one up (`NoteVisibility`).
        let notes = userVisibleNotes(try context.fetch(descriptor))
        return Set(notes.map { calendar.startOfDay(for: $0.createdAt) })
    }

    private var calendar: Calendar { .current }
}
