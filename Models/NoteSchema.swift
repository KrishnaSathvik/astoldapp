import Foundation
import SwiftData

/// Versioned schema for the note store. Even a simple app eventually needs migrations, so the
/// container is built with an explicit version + migration plan from day one
/// (docs/05-architecture.md §24). When the model changes, add `NoteSchemaV2` and a `MigrationStage`.
enum NoteSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Note.self] }
}

/// The ordered list of schema versions and the migration stages between them.
enum NoteMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NoteSchemaV1.self] }
    static var stages: [MigrationStage] { [] }   // no migrations yet — V1 is current
}

enum NoteStoreContainer {
    /// Builds the app's ModelContainer with the versioned schema + migration plan.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NoteSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: NoteMigrationPlan.self, configurations: config)
    }
}
