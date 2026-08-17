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
}
