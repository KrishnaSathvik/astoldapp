import SwiftUI

/// Search result: title (or first meaningful line) + body excerpt + date.
/// Dates appear in search even though normal Home rows omit them (docs/03-design-system.md §4.5).
struct SearchResultRow: View {
    let note: Note

    private var titleLine: String {
        normalizedTitle(note.title)
            ?? note.body.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init)
            ?? note.body
    }

    private var dateText: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        return df.string(from: note.createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s1) {
            Text(titleLine)
                .font(.ds.noteTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .lineLimit(1)
            if normalizedTitle(note.title) != nil {
                Text(note.body)
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textSecondary)
                    .lineLimit(2)
            }
            Text(dateText)
                .font(.ds.caption)
                .foregroundStyle(Color.ds.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titleLine). \(dateText)")
    }
}
