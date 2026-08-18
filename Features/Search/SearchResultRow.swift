import SwiftUI

/// Search result: title (or first meaningful line) + body excerpt + date.
/// Dates appear in search even though normal Home rows omit them (docs/03-design-system.md §4.5).
struct SearchResultRow: View {
    let note: Note

    /// The body as the reader sees it: hidden structure markers never surface in a result (RULES.md §4).
    private var bodyText: String { StructuredTextExport.plainText(note.body) }

    private var titleLine: String {
        normalizedTitle(note.title)
            ?? bodyText.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init)
            ?? bodyText
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
                Text(bodyText)
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
