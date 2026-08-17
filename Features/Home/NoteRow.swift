import SwiftUI

/// Chromeless Home row: title + preview, or body-only when no title. Never renders "Untitled".
/// See docs/03-design-system.md §4.3 and RULES.md §4.
struct NoteRow: View {
    let note: Note
    private var displayTitle: String? { normalizedTitle(note.title) }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s1) {
            if let displayTitle {
                Text(displayTitle)
                    .font(.ds.noteTitle)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(1)
                Text(note.body)
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textSecondary)
                    .lineLimit(3)
            } else {
                Text(note.body)
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let displayTitle { return "\(displayTitle). \(note.body)" }
        return note.body
    }
}
