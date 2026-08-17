import Foundation
import SwiftData

/// Local-first note. Timeline sorts by `createdAt`, not `updatedAt`. See docs/05-architecture.md §5.
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String?
    var body: String
    var createdAt: Date
    var updatedAt: Date
    /// Non-nil only while in the short undo/cleanup state.
    var deletedAt: Date?

    init(id: UUID = UUID(),
         title: String? = nil,
         body: String = "",
         createdAt: Date = .now,
         updatedAt: Date = .now,
         deletedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    /// A draft with no meaningful title or body — discarded on abandon (RULES.md §1, §4).
    var isEmptyDraft: Bool {
        normalizedTitle(title) == nil &&
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
