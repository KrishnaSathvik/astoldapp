import UIKit

/// The geometry of a table as it is *read* — column widths, row heights, and the size of the card the
/// note reserves for it.
///
/// Separate from the drawing on purpose. Where the columns land is arithmetic over measured text, and
/// arithmetic is the part that has to be tested at a width, at a Dynamic Type size, and against a table
/// nobody thought of. `TableCardView` only paints what this decides.
///
/// Two presentations, chosen by whether the table can be *read* at this width rather than by a column
/// count someone picked:
///  - **full** — every column and every row, cells wrapping. The table is the note.
///  - **preview** — the first few columns and rows, and a line saying how much more there is, with the
///    full grid one tap away in `TableReaderView`. Reached when the columns cannot each hold a legible
///    minimum, or when wrapping would turn rows into paragraphs.
///
/// What is never an option is showing the source. `| Day | Date |` is how the note *stores* a table
/// (RULES.md §5 — `body` is one String); it is not something a reader should ever have to decode.
enum TableCardLayout {

    /// The card's paddings and floors. Editorial rather than spreadsheet: air inside the cells, quiet
    /// horizontal separators, and no vertical rules at all — those are supplied by the columns.
    enum Metrics {
        /// Air between the card's edge and the first/last column.
        static let cardInsetH: CGFloat = 14
        /// The gutter between two columns. Wide enough to separate them without a drawn line.
        static let columnGap: CGFloat = 14
        static let rowInsetV: CGFloat = 10
        /// The narrowest a column may be squeezed to before the table stops being readable inline.
        static let minColumnWidth: CGFloat = 56
        static let corner: CGFloat = 12
        /// Air above and below the card, so it reads as a block on the page and not as a run of text.
        static let blockMargin: CGFloat = 10
        /// A cell taller than this many lines means the "table" has become a stack of paragraphs.
        static let maxWrappedLines = 3
        static let previewColumns = 3
        static let previewRows = 3
    }

    struct Row: Equatable {
        var cells: [String]
        var height: CGFloat
    }

    /// Everything `TableCardView` needs to draw one table, and everything the styler needs to reserve
    /// room for it.
    struct Layout: Equatable {
        var isPreview: Bool
        var columnWidths: [CGFloat]
        var alignments: [NSTextAlignment]
        var header: [String]
        var headerHeight: CGFloat
        var rows: [Row]
        /// "9 rows · 7 columns" — only a preview has one, because only a preview is holding something back.
        var footer: String?
        var footerHeight: CGFloat
        var size: CGSize

        /// The height the note reserves for this table: the card plus the air around it.
        var reservedHeight: CGFloat { size.height + Metrics.blockMargin * 2 }

        // MARK: Where the cells are
        //
        // Editing a cell in place means putting a field exactly where its words already are, so this
        // has to agree with `TableCardView.draw` character for character. It is derived from the same
        // two facts that drawing uses — columns are laid out left to right with a gap between them, and
        // rows stack under the header — rather than being measured off the screen afterwards.

        /// `header` is row 0 and `rows` are the records, which is the same numbering `TableBlock.rows`
        /// uses — so a `CellPosition` means the same thing on both sides.
        func rowHeight(_ row: Int) -> CGFloat? {
            if row == 0 { return headerHeight }
            let record = row - 1
            guard record >= 0, record < rows.count else { return nil }
            return rows[record].height
        }

        /// The top edge of a row, in the card's own coordinates.
        func rowTop(_ row: Int) -> CGFloat? {
            guard rowHeight(row) != nil else { return nil }
            guard row > 0 else { return 0 }
            return rows.prefix(row - 1).reduce(headerHeight) { $0 + $1.height }
        }

        /// The rectangle a cell's words occupy.
        func cellFrame(row: Int, column: Int) -> CGRect? {
            guard column >= 0, column < columnWidths.count,
                  let top = rowTop(row), let height = rowHeight(row) else { return nil }
            let x = columnWidths.prefix(column).reduce(Metrics.cardInsetH) { $0 + $1 + Metrics.columnGap }
            return CGRect(x: x, y: top, width: columnWidths[column], height: height)
        }

        /// The cell a touch lands in, or `nil` for the gaps, the footer, and outside the card.
        ///
        /// The column gap belongs to neither neighbour: a tap there is a tap on the table rather than
        /// on a cell, and picking the nearer column would start an edit the writer did not aim for.
        func cell(at point: CGPoint) -> TableBlock.CellPosition? {
            guard point.x >= 0, point.y >= 0, point.x <= size.width else { return nil }
            let rowCount = 1 + rows.count
            for row in 0..<rowCount {
                guard let top = rowTop(row), let height = rowHeight(row) else { continue }
                guard point.y >= top, point.y < top + height else { continue }
                for column in columnWidths.indices {
                    guard let frame = cellFrame(row: row, column: column) else { continue }
                    if point.x >= frame.minX, point.x < frame.maxX {
                        return TableBlock.CellPosition(row: row, column: column)
                    }
                }
                return nil
            }
            return nil
        }
    }

    /// One entry per table in `source`, in the order they appear.
    static func layouts(in source: String, availableWidth: CGFloat) -> [(table: TableBlock, layout: Layout)] {
        TableBlock.tables(in: source).compactMap { table in
            layout(for: table, availableWidth: availableWidth).map { (table, $0) }
        }
    }

    /// The layout for one table, or `nil` when there is no width to lay it out in yet.
    static func layout(for table: TableBlock, availableWidth: CGFloat) -> Layout? {
        guard availableWidth > Metrics.minColumnWidth * 2, table.width > 0 else { return nil }
        let body = StructuredTextStyle.bodyFont()
        let heading = StructuredTextStyle.tableHeaderFont()

        if let full = fullLayout(table, availableWidth: availableWidth, body: body, heading: heading) {
            return full
        }
        return previewLayout(table, availableWidth: availableWidth, body: body, heading: heading)
    }

    // MARK: Full

    private static func fullLayout(_ table: TableBlock, availableWidth: CGFloat,
                                   body: UIFont, heading: UIFont) -> Layout? {
        let header = table.header
        let records = table.records
        guard let widths = columnWidths(header: header, records: records, columns: table.width,
                                        availableWidth: availableWidth, body: body, heading: heading)
        else { return nil }

        let headerHeight = rowHeight(cells: header, widths: widths, font: heading)
        var rows: [Row] = []
        let ceiling = ceil(body.lineHeight) * CGFloat(Metrics.maxWrappedLines) + Metrics.rowInsetV * 2
        for cells in records {
            let height = rowHeight(cells: cells, widths: widths, font: body)
            // A row that has wrapped into a paragraph is no longer a row. That table reads as a preview
            // with the real grid a tap away, which keeps every word and loses none of the alignment.
            guard height <= ceiling else { return nil }
            rows.append(Row(cells: padded(cells, to: table.width), height: height))
        }

        return Layout(
            isPreview: false,
            columnWidths: widths,
            alignments: alignments(header: header, records: records, columns: table.width),
            header: padded(header, to: table.width),
            headerHeight: headerHeight,
            rows: rows,
            footer: nil,
            footerHeight: 0,
            size: CGSize(width: availableWidth,
                         height: headerHeight + rows.reduce(0) { $0 + $1.height })
        )
    }

    // MARK: Preview

    /// The first few columns of the first few rows, under a line that says what is being held back.
    ///
    /// Cells here are allowed to truncate — the one place in the app where that is true — because the
    /// whole table is one tap away and nothing has been lost. Truncating in the *full* presentation
    /// would destroy words, which this app does not do.
    private static func previewLayout(_ table: TableBlock, availableWidth: CGFloat,
                                      body: UIFont, heading: UIFont) -> Layout? {
        let columns = min(Metrics.previewColumns, table.width)
        let header = Array(table.header.prefix(columns))
        let records = table.records.prefix(Metrics.previewRows).map { Array($0.prefix(columns)) }
        guard let widths = columnWidths(header: header, records: records, columns: columns,
                                        availableWidth: availableWidth, body: body, heading: heading)
        else { return nil }

        let headerHeight = ceil(heading.lineHeight) + Metrics.rowInsetV * 2
        let rowHeight = ceil(body.lineHeight) + Metrics.rowInsetV * 2
        let footerHeight = ceil(StructuredTextStyle.tableFooterFont().lineHeight) + Metrics.rowInsetV * 2
        let footer = "\(count(table.records.count, "row")) · \(count(table.width, "column"))"

        return Layout(
            isPreview: true,
            columnWidths: widths,
            alignments: alignments(header: header, records: records, columns: columns),
            header: header,
            headerHeight: headerHeight,
            rows: records.map { Row(cells: $0, height: rowHeight) },
            footer: footer,
            footerHeight: footerHeight,
            size: CGSize(width: availableWidth,
                         height: headerHeight + rowHeight * CGFloat(records.count) + footerHeight)
        )
    }

    private static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }

    // MARK: Columns

    /// Column widths from the words in them, or `nil` when the table cannot be laid out at this width.
    ///
    /// Content-aware, not equal-width: `Day` holds three characters and has no claim on a quarter of the
    /// screen, while `Kenai Fjords cruise` does. Natural widths decide the shares, and any width left
    /// over is handed back in the same proportion, so a two-column table of items and prices settles at
    /// roughly 70/30 instead of splitting down the middle.
    static func columnWidths(header: [String], records: [[String]], columns: Int,
                             availableWidth: CGFloat, body: UIFont, heading: UIFont) -> [CGFloat]? {
        guard columns > 0 else { return nil }
        let content = availableWidth - Metrics.cardInsetH * 2 - Metrics.columnGap * CGFloat(columns - 1)
        guard content >= Metrics.minColumnWidth * CGFloat(columns) else { return nil }

        var natural = [CGFloat](repeating: 0, count: columns)
        for column in 0..<columns {
            natural[column] = max(width(cell(header, column), font: heading),
                                  records.map { width(cell($0, column), font: body) }.max() ?? 0)
        }
        let total = natural.reduce(0, +)
        guard total > 0 else { return [CGFloat](repeating: content / CGFloat(columns), count: columns) }

        if total <= content {
            let slack = content - total
            return natural.map { $0 + slack * ($0 / total) }
        }

        // Too wide for its words: every column keeps its share of what there is, but none is squeezed
        // under the floor. Columns that hit the floor stop shrinking and the rest re-divide the rest.
        var widths = [CGFloat](repeating: 0, count: columns)
        var flexible = Set(0..<columns)
        var remaining = content
        while true {
            let flexTotal = flexible.reduce(0.0) { $0 + natural[$1] }
            guard flexTotal > 0 else { break }
            var floored = false
            for column in flexible {
                let share = remaining * (natural[column] / flexTotal)
                if share < Metrics.minColumnWidth {
                    widths[column] = Metrics.minColumnWidth
                    flexible.remove(column)
                    remaining -= Metrics.minColumnWidth
                    floored = true
                    break
                }
                widths[column] = share
            }
            if !floored { break }
            if flexible.isEmpty || remaining <= 0 { break }
        }
        for column in flexible where widths[column] <= 0 {
            widths[column] = Metrics.minColumnWidth
        }
        return widths
    }

    /// Which columns read right-aligned. A column of amounts lines up on its digits — that is what makes
    /// a total scannable — and everything else stays left, where reading starts.
    static func alignments(header: [String], records: [[String]], columns: Int) -> [NSTextAlignment] {
        (0..<columns).map { column in
            guard column > 0 else { return .left }
            let values = records.map { cell($0, column) }.filter { !$0.isEmpty }
            guard !values.isEmpty, values.allSatisfy(isQuantity) else { return .left }
            return .right
        }
    }

    /// "$2,400–$3,600", "12", "5 hrs" is not one — a quantity is digits and the punctuation money and
    /// ranges are written with, and nothing else.
    static func isQuantity(_ value: String) -> Bool {
        let punctuation = Set("$€£¥₹,.%+-–—/ ")
        var sawDigit = false
        for character in value {
            if character.isNumber { sawDigit = true; continue }
            guard punctuation.contains(character) else { return false }
        }
        return sawDigit
    }

    // MARK: Measuring

    private static func padded(_ cells: [String], to width: Int) -> [String] {
        cells + Array(repeating: "", count: max(0, width - cells.count))
    }

    private static func cell(_ cells: [String], _ column: Int) -> String {
        column < cells.count ? cells[column] : ""
    }

    private static func rowHeight(cells: [String], widths: [CGFloat], font: UIFont) -> CGFloat {
        var tallest = ceil(font.lineHeight)
        for (column, width) in widths.enumerated() {
            tallest = max(tallest, height(cell(cells, column), font: font, width: width))
        }
        return tallest + Metrics.rowInsetV * 2
    }

    static func width(_ string: String, font: UIFont) -> CGFloat {
        guard !string.isEmpty else { return 0 }
        return ceil((string as NSString).size(withAttributes: [.font: font]).width)
    }

    static func height(_ string: String, font: UIFont, width: CGFloat) -> CGFloat {
        guard !string.isEmpty, width > 0 else { return ceil(font.lineHeight) }
        let bounds = (string as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(bounds.height)
    }
}
