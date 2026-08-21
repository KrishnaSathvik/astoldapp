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
    static func tables(in source: String) -> [TableBlock] {
        let lines = source.components(separatedBy: "\n")
        var found: [TableBlock] = []
        var index = 0

        while index < lines.count {
            guard let first = cells(of: lines[index]) else { index += 1; continue }

            var rows = [first]
            var hasRule = false
            var end = index

            var next = index + 1
            if next < lines.count, isDelimiter(lines[next]) {
                hasRule = true
                end = next
                next += 1
            }
            while next < lines.count, let row = cells(of: lines[next]), !isDelimiter(lines[next]) {
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

    /// `| --- | :-: |` — the rule under the headings. It carries no words of its own.
    static func isDelimiter(_ line: String) -> Bool {
        guard let cells = cells(of: line), !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            !cell.isEmpty && cell.contains("-") && cell.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
        }
    }
}
