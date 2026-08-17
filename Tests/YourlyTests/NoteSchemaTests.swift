import Testing
import SwiftData
@testable import Yourly

@MainActor
struct NoteSchemaTests {
    @Test func versionedContainerBuildsAndPersists() throws {
        let container = try NoteStoreContainer.make(inMemory: true)
        let context = ModelContext(container)
        let store = SwiftDataNoteStore(context: context)

        let note = try store.createDraft()
        note.body = "versioned"
        try store.save(note)

        #expect(try store.recent(limit: 10, before: nil).first?.body == "versioned")
    }

    @Test func migrationPlanDeclaresV1() {
        #expect(NoteMigrationPlan.schemas.count == 1)
        #expect(NoteSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }
}
