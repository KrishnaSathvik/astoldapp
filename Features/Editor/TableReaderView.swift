import SwiftUI

/// A pasted table, read as a table.
///
/// The note keeps the words — canonical pipe rows in `body`, editable like any other line. This screen
/// is the other half of that bargain: somewhere those rows can be *scanned*, which is the only reason
/// anyone reaches for a table. It reads; it never writes. There is no cell editing, no row or column
/// control, no sorting, and no way to create a table from here (RULES.md §7, amended 2026-08-21).
struct TableReaderView: View {
    let table: TableBlock
    var onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Wide enough for a date or a short phrase, narrow enough that four columns are visible at once.
    /// Scaled with Dynamic Type, because a column that fits at the default size clips at the largest.
    private var columnWidth: CGFloat {
        typeSize >= .accessibility1 ? 190 : 132
    }

    var body: some View {
        NavigationStack {
            // One horizontal scroll wraps both the heading row and the rows under it, so they move
            // together and the headings stay above their own column. The vertical scroll sits *inside*
            // it, which is what keeps the heading row on screen while the rows travel under it — no
            // synchronized scroll views, and nothing to fall out of step.
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    row(table.header, isHeader: true)
                    Divider()
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(table.records.enumerated()), id: \.offset) { index, cells in
                                row(cells, isHeader: false)
                                    .background(index.isMultiple(of: 2)
                                                ? Color.clear : Color.ds.textPrimary.opacity(0.025))
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.screenH)
            }
            .background(Color.ds.canvas)
            .navigationTitle("Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onClose() }
                        .foregroundStyle(Color.ds.accent)
                }
            }
            .accessibilityLabel("Table, \(table.records.count) rows, \(table.width) columns")
        }
    }

    private func row(_ cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<table.width, id: \.self) { column in
                let value = column < cells.count ? cells[column] : ""
                Text(value)
                    .font(isHeader ? .ds.noteTitle : .ds.editorBody)
                    .foregroundStyle(isHeader ? Color.ds.textPrimary : Color.ds.textSecondary)
                    // Cells wrap. A table that truncates has lost the words, which is the one thing
                    // this app does not do.
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.vertical, DSSpacing.s3)
                    .padding(.trailing, DSSpacing.s3)
                    .accessibilityLabel(label(for: value, column: column, isHeader: isHeader))
            }
        }
    }

    /// VoiceOver reads a cell with the column it belongs to — "Park, Kenai Fjords" — because a cell
    /// without its heading is a word with the relationship stripped out of it, which is the whole
    /// content of a table.
    private func label(for value: String, column: Int, isHeader: Bool) -> String {
        let spoken = value.isEmpty ? "empty" : value
        guard !isHeader, column < table.header.count, !table.header[column].isEmpty else { return spoken }
        return "\(table.header[column]), \(spoken)"
    }
}
