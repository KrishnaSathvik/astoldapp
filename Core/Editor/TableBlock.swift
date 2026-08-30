import Foundation

// A table inside a note.
//
// `body` is one String and stays one String (RULES.md §5) — a table is not a new model, a second
// field, or a migration. It is a run of ordinary lines that happen to be shaped like a table:
//
//   | Day | Date | Park         |
//   | --- | ---  | ---          |
//   | 1   | Sat  | —            |
//
// Those characters are the note. They can be typed, edited, searched, copied, and pasted like any
// other words, and nothing here rewrites them. This type only *reads* them, so the note can show the
// rows as the grid the author meant (RULES.md §7, amended 2026-08-21: tables are an import-and-display
// structure, never a spreadsheet).

/// One table found in a note's source.
struct TableBlock: Equatable, Identifiable {
    /// Where it sits in the note — enough to tell two tables apart while one of them is on screen.
    var id: ClosedRange<Int> { lineRange }

    /// The rows, header first, with every row padded to the table's width.
    var rows: [[String]]
    /// Whether the source carried a delimiter row under the first line. A table without one still
    /// reads its first row as the header, which is what a reader does with a table.
    var hasHeaderRule: Bool
    /// The lines of `body` this table occupies, as a line-index range — what a tap has to hit and what
    /// an edit has to replace.
    var lineRange: ClosedRange<Int>

    var width: Int { rows.map(\.count).max() ?? 0 }
    var header: [String] { rows.first ?? [] }
    /// Every row under the header. The header is a label for the rest, not one of them.
    var records: [[String]] { Array(rows.dropFirst()) }

    // MARK: Writing

    /// One canonical row. Cells keep their words exactly; a literal pipe inside a cell would end the
    /// cell early, so it travels as its escaped spelling — the only character this ever touches.
    static func row(_ cells: [String]) -> String {
        "| " + cells.map { $0.replacingOccurrences(of: "|", with: "\\|") }.joined(separator: " | ") + " |"
    }

    static func delimiter(width: Int) -> String {
        "|" + String(repeating: " --- |", count: max(1, width))
    }

    // MARK: Reading

    /// Every table in `source`, in the order they appear.
    ///
    /// Deliberately strict. A line with a pipe in it is usually a line with a pipe in it, and a note
    /// that renders `a | b` as a grid because someone typed a vertical bar would be worse than one
    /// that renders nothing. A block qualifies only when at least two consecutive lines are pipe rows
    /// of the same width, or when a delimiter row follows the first.
    ///
    /// And a pipe inside a code fence is code. A fence states outright that its characters are literal
    /// — that is the whole of what it says — so nothing in it is a row, a header rule, or a table
    /// (`CodeBlock`, RULES.md §7). Reading one anyway is not a cosmetic mistake: a table drawn over
    /// someone's `| --- |` hides lines of their code on the page and drops them from what a copy
    /// carries out, which is the note losing characters it was asked to keep (RULES.md §5).
    static func tables(in source: String) -> [TableBlock] {
        let lines = source.components(separatedBy: "\n")
        // Answered as cheaply as every other fence question: a note with no fence pays one substring
        // search and runs exactly the scan it ran before code blocks existed.
        let literal = source.contains(CodeBlock.fence) ? CodeBlock.literalLineIndices(in: source) : []
        var found: [TableBlock] = []
        var index = 0

        while index < lines.count {
            guard !literal.contains(index), let first = cells(of: lines[index]) else {
                index += 1
                continue
            }

            var rows = [first]
            var hasRule = false
            var end = index

            var next = index + 1
            if next < lines.count, !literal.contains(next), isHeaderRule(lines[next]) {
                hasRule = true
                end = next
                next += 1
            }
            while next < lines.count, !literal.contains(next),
                  let row = cells(of: lines[next]), !isDelimiter(lines[next]) {
                rows.append(row)
                end = next
                next += 1
            }

            if hasRule || rows.count > 1 {
                let width = rows.map(\.count).max() ?? 0
                let padded = rows.map { $0 + Array(repeating: "", count: width - $0.count) }
                found.append(TableBlock(rows: padded, hasHeaderRule: hasRule, lineRange: index...end))
            }
            index = max(end + 1, index + 1)
        }
        return found
    }

    /// The table containing `line`, if any.
    static func table(in source: String, atLine line: Int) -> TableBlock? {
        tables(in: source).first { $0.lineRange.contains(line) }
    }

    // MARK: Editing one cell

    /// Which cell of a table a position refers to. `row` indexes `rows` — 0 is the header — and the
    /// delimiter is not addressable, because it is storage rather than a row anyone typed.
    struct CellPosition: Equatable, Hashable {
        var row: Int
        var column: Int
    }

    /// The line of `body` a row's cells live on.
    ///
    /// `rows` excludes the header rule, so the two indexes diverge the moment a table has one: row 1 is
    /// two lines below the header, not one. Getting this wrong writes a cell into the rule.
    func sourceLine(forRow row: Int) -> Int? {
        guard row >= 0, row < rows.count else { return nil }
        guard hasHeaderRule else { return lineRange.lowerBound + row }
        return row == 0 ? lineRange.lowerBound : lineRange.lowerBound + 1 + row
    }

    /// The cell at `position`, or `nil` when there is no such cell.
    func cell(at position: CellPosition) -> String? {
        guard position.row >= 0, position.row < rows.count,
              position.column >= 0, position.column < width else { return nil }
        let cells = rows[position.row]
        return position.column < cells.count ? cells[position.column] : ""
    }

    /// The edit that puts `text` into one cell, leaving every other character of the note alone.
    ///
    /// The whole row is rewritten rather than the cell's own characters, because a cell's position in
    /// the line depends on the widths of the cells before it and `row(_:)` is the one place that
    /// spelling is decided — including the escaping that keeps a typed `|` from ending the cell early.
    /// Only that one line changes: the rule, the other rows, and the prose around the table are
    /// untouched, so `body` stays exactly as canonical as it was (RULES.md §5).
    ///
    /// A cell is one line. Newlines in `text` become spaces rather than breaking the row in two — this
    /// pass has no multiline cells, and silently splitting a table is worse than joining a paste.
    static func cellEdit(in source: String, table: TableBlock,
                         at position: CellPosition, text: String) -> TextEdit? {
        guard position.row >= 0, position.row < table.rows.count,
              position.column >= 0, position.column < table.width,
              let lineIndex = table.sourceLine(forRow: position.row),
              let lineRange = StructuredText.characterRange(ofLines: lineIndex...lineIndex,
                                                            in: source as NSString)
        else { return nil }

        var cells = table.rows[position.row]
        if cells.count < table.width {
            cells += Array(repeating: "", count: table.width - cells.count)
        }
        let flattened = text.components(separatedBy: .newlines).joined(separator: " ")
        guard cells[position.column] != flattened else { return nil }   // nothing to write
        cells[position.column] = flattened

        let replacement = row(cells)
        // The caret lands at the end of the cell's own words, which is where someone who just finished
        // typing them expects it — and it is a position inside a line the reader never sees, so it only
        // matters to the field that owns it.
        return TextEdit(range: lineRange,
                        string: replacement,
                        selection: NSRange(location: lineRange.location + (replacement as NSString).length,
                                           length: 0))
    }

    // MARK: Moving between cells

    /// The cell after `position`, wrapping to the first cell of the next row, or `nil` at the end of
    /// the table. Return and Tab both walk this order: A1 → B1 → C1 → A2.
    func cellAfter(_ position: CellPosition) -> CellPosition? {
        guard position.row >= 0, position.row < rows.count else { return nil }
        if position.column + 1 < width { return CellPosition(row: position.row, column: position.column + 1) }
        guard position.row + 1 < rows.count else { return nil }
        return CellPosition(row: position.row + 1, column: 0)
    }

    /// The cell before `position`, wrapping back to the last cell of the row above. Shift-Tab.
    func cellBefore(_ position: CellPosition) -> CellPosition? {
        guard position.row >= 0, position.row < rows.count else { return nil }
        if position.column > 0 { return CellPosition(row: position.row, column: position.column - 1) }
        guard position.row > 0 else { return nil }
        return CellPosition(row: position.row - 1, column: max(0, width - 1))
    }

    /// The cells of one row, or `nil` when the line is not a pipe row at all.
    ///
    /// A row must open with a pipe. That single requirement is what keeps prose out: "chicken | rice"
    /// is a shopping note, and `| chicken | rice |` is a row someone wrote or pasted as one.
    static func cells(of line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|"), trimmed.count > 1 else { return nil }

        var cells: [String] = []
        var current = ""
        var escaped = false
        for character in trimmed.dropFirst() {
            if escaped {
                current.append(character == "|" ? "|" : character)
                escaped = false
                continue
            }
            if character == "\\" { escaped = true; continue }
            if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                continue
            }
            current.append(character)
        }
        // Text after the last pipe is a cell the row never closed; its words still count.
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { cells.append(tail) }
        return cells.isEmpty ? nil : cells
    }

    // MARK: The delimiter row is storage, not writing

    /// Whether the line at `index` is a delimiter row the editor hides.
    ///
    /// `| --- | --- |` is how the note records which row is the header. It carries no words of its own,
    /// nobody typed it to be read, and it is the one piece of a table's source that says nothing about
    /// the table's contents — so the writer never sees it, in reading **or** writing (RULES.md §7,
    /// amended 2026-08-23). It stays in `body` untouched: the parser needs it, copy preserves it, and
    /// every existing note gets the behaviour without being rewritten.
    static func isHiddenDelimiter(in source: String, atLine index: Int) -> Bool {
        guard source.contains("|") else { return false }
        let lines = source.components(separatedBy: "\n")
        guard index >= 0, index < lines.count else { return false }
        guard let table = table(in: source, atLine: index), table.hasHeaderRule else { return false }
        return index == table.lineRange.lowerBound + 1
    }

    /// Where a caret must go when it lands on a hidden delimiter row, or `nil` when it has not.
    ///
    /// A hidden line has no glyphs and no height, so a caret left there is invisible — and the next
    /// keystroke would land *inside* the row that tells the parser where the header is, turning
    /// `| --- |` into a data row and the table back into prose. The same argument that keeps a caret
    /// out of a hidden block marker (RULES.md §4) keeps it out of here.
    ///
    /// - Parameter movingForward: which way the caret was travelling, so arrowing down out of the
    ///   header lands on the first row and arrowing up out of that row lands back on the header,
    ///   rather than both directions trapping it against the same edge.
    static func caretEscape(in source: String, from offset: Int, movingForward: Bool) -> Int? {
        let ns = source as NSString
        let index = StructuredText.lineIndex(of: offset, in: ns)
        guard isHiddenDelimiter(in: source, atLine: index) else { return nil }

        if movingForward, let next = StructuredText.characterRange(ofLines: (index + 1)...(index + 1),
                                                                  in: ns) {
            return next.location
        }
        if index > 0, let previous = StructuredText.characterRange(ofLines: (index - 1)...(index - 1),
                                                                   in: ns) {
            return previous.location + previous.length
        }
        // Nowhere above it: the row below is the only place left to be.
        return StructuredText.characterRange(ofLines: (index + 1)...(index + 1), in: ns)?.location
            ?? offset
    }

    /// `| --- | :-: |` — the rule under the headings. It carries no words of its own.
    static func isDelimiter(_ line: String) -> Bool {
        rule(line, dash: { $0 == "-" })
    }

    /// The same question asked where a header rule is the only thing a line can be — the row directly
    /// under the first — and there it also accepts the dashes a phone keyboard substitutes.
    ///
    /// Deliberately *not* `isDelimiter` itself. Everywhere else — deciding where a table ends, or
    /// whether a row deeper down is data — the strict spelling is what keeps a table that genuinely
    /// uses a dash to mean "no value" from being cut in half by it.
    static func isHeaderRule(_ line: String) -> Bool {
        rule(line, dash: isRuleDash)
    }

    private static func rule(_ line: String, dash: (Character) -> Bool) -> Bool {
        guard let cells = cells(of: line), !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            !cell.isEmpty && cell.contains(where: dash)
                && cell.allSatisfy { dash($0) || $0 == ":" || $0 == " " }
        }
    }

    /// The characters a header rule can be written with.
    ///
    /// ASCII hyphens are what As Told writes, and for a pasted table they are what stays there. A
    /// rule the writer **typed** on a phone is a different matter: iOS smart punctuation rewrites
    /// `--` to an en dash and `---` to an em dash as the third character lands, so the rule that was
    /// typed is not the rule that is stored. Read strictly, that row stops being a rule and becomes a
    /// data row — the table grows a spurious `—  —` line that the writer can see, cannot delete
    /// without breaking the table, and never typed the characters of (RULES.md §4).
    ///
    /// So the substituted spellings are *recognised*, exactly as `BlockKind.normalizingPrefix`
    /// recognises the ones a keyboard substitutes into a block marker. Nothing here rewrites the
    /// note: `body` keeps whichever dash is in it, and every existing note gets this the moment it is
    /// read, with no migration (RULES.md §5).
    private static func isRuleDash(_ character: Character) -> Bool {
        character == "-"            // ASCII hyphen — what As Told itself writes
            || character == "\u{2013}"  // – en dash, substituted for "--"
            || character == "\u{2014}"  // — em dash, substituted for "---"
            || character == "\u{2015}"  // ― horizontal bar
            || character == "\u{2212}"  // − minus sign
    }
}
