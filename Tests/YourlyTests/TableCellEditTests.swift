import Testing
import Foundation
@testable import Yourly

/// Item 4, the document half: editing one cell of a table without ever showing anyone its source.
///
/// The grid the reader sees is a projection of `body`; a cell edit has to travel back the other way and
/// land on exactly one line, leaving the header rule, the other rows, and the prose around the table
/// untouched. `body` stays canonical pipe rows (RULES.md §5) — the table is still stored as text.
struct TableCellEditTests {

    private let source = "Notes\n| Base | Nights |\n| --- | --- |\n| Anchorage | 3 |\n| Seward | 2 |\nAfter"

    private var table: TableBlock { TableBlock.tables(in: source).first! }

    private func edited(_ position: TableBlock.CellPosition, to text: String,
                        in source: String? = nil) -> String? {
        let src = source ?? self.source
        let table = TableBlock.tables(in: src).first!
        return TableBlock.cellEdit(in: src, table: table, at: position, text: text)?
            .applied(to: src).text
    }

    // MARK: Which line a row lives on

    @Test func aRowsSourceLineSkipsTheHeaderRule() {
        // `rows` excludes the rule, so the two indexes diverge — row 1 is two lines below the header.
        #expect(table.hasHeaderRule)
        #expect(table.sourceLine(forRow: 0) == 1)   // "| Base | Nights |"
        #expect(table.sourceLine(forRow: 1) == 3)   // "| Anchorage | 3 |"  — not 2, which is the rule
        #expect(table.sourceLine(forRow: 2) == 4)
        #expect(table.sourceLine(forRow: 3) == nil)
    }

    @Test func aTableWithoutARuleCountsStraightThrough() {
        let plain = "| a | b |\n| c | d |"
        let table = TableBlock.tables(in: plain).first!
        #expect(!table.hasHeaderRule)
        #expect(table.sourceLine(forRow: 0) == 0)
        #expect(table.sourceLine(forRow: 1) == 1)
    }

    // MARK: Writing a cell

    @Test func aCellEditChangesOnlyItsOwnLine() {
        let out = edited(.init(row: 1, column: 0), to: "Homer") ?? ""
        #expect(out == "Notes\n| Base | Nights |\n| --- | --- |\n| Homer | 3 |\n| Seward | 2 |\nAfter")
    }

    @Test func theHeaderIsACellLikeAnyOther() {
        let out = edited(.init(row: 0, column: 1), to: "Evenings") ?? ""
        #expect(out.contains("| Base | Evenings |"))
        #expect(out.contains("| --- | --- |"), "the rule was disturbed")
    }

    @Test func theRuleAndTheProseAreNeverTouched() {
        for position in [TableBlock.CellPosition(row: 0, column: 0),
                         .init(row: 1, column: 1), .init(row: 2, column: 0)] {
            let out = edited(position, to: "x") ?? ""
            let lines = out.components(separatedBy: "\n")
            #expect(lines.first == "Notes")
            #expect(lines.last == "After")
            #expect(lines[2] == "| --- | --- |")
            #expect(TableBlock.tables(in: out).first?.rows.count == 3)
        }
    }

    @Test func aTypedPipeCannotBreakTheRow() {
        // The one character that could end a cell early travels escaped, and reads back as itself.
        let out = edited(.init(row: 1, column: 0), to: "a | b") ?? ""
        let table = TableBlock.tables(in: out).first
        #expect(table?.rows[1] == ["a | b", "3"])
        #expect(table?.width == 2, "the row grew a column")
    }

    @Test func aCellIsOneLine() {
        // No multiline cells in this pass: a newline would split the row and quietly break the table.
        let out = edited(.init(row: 1, column: 0), to: "one\ntwo") ?? ""
        #expect(TableBlock.tables(in: out).first?.rows[1] == ["one two", "3"])
        #expect(out.components(separatedBy: "\n").count == source.components(separatedBy: "\n").count)
    }

    @Test func anEmptyCellIsAllowed() {
        let out = edited(.init(row: 1, column: 1), to: "") ?? ""
        #expect(TableBlock.tables(in: out).first?.rows[1] == ["Anchorage", ""])
    }

    @Test func writingTheSameTextIsNoEdit() {
        // Nothing to undo, and no keystroke registered, when a cell is left as it was.
        #expect(TableBlock.cellEdit(in: source, table: table,
                                    at: .init(row: 1, column: 0), text: "Anchorage") == nil)
    }

    @Test func anOutOfRangeCellIsRefused() {
        for position in [TableBlock.CellPosition(row: -1, column: 0), .init(row: 9, column: 0),
                         .init(row: 0, column: -1), .init(row: 0, column: 5)] {
            #expect(TableBlock.cellEdit(in: source, table: table, at: position, text: "x") == nil)
        }
    }

    @Test func aShortRowIsPaddedRatherThanCorrupted() {
        let ragged = "| a | b | c |\n| --- | --- | --- |\n| d |"
        let out = edited(.init(row: 1, column: 2), to: "z", in: ragged) ?? ""
        #expect(TableBlock.tables(in: out).first?.rows[1] == ["d", "", "z"])
    }

    @Test func unicodeSurvivesACellEdit() {
        let out = edited(.init(row: 1, column: 0), to: "తెలుగు — naïve") ?? ""
        #expect(TableBlock.tables(in: out).first?.rows[1] == ["తెలుగు — naïve", "3"])
    }

    @Test func editingACellNeverExposesTheRuleToAReader() {
        let out = edited(.init(row: 1, column: 0), to: "Homer") ?? ""
        // The surfaces a *person* reads. `plainText(_:)` is deliberately not one of them: copying a
        // table out yields its pipe source by contract (docs/02-features.md), which is what makes it
        // paste back into another app as a table.
        for rendered in [StructuredTextExport.spokenText(out), StructuredTextExport.previewText(out)] {
            #expect(!rendered.contains("---"), "the rule reached a reader: \(rendered)")
        }
        #expect(StructuredTextExport.spokenText(out).contains("Homer"))
    }

    // MARK: Moving between cells

    @Test func returnAndTabWalkTheGridInReadingOrder() {
        // A1 → B1 → C1 → A2
        let grid = "| a | b | c |\n| --- | --- | --- |\n| d | e | f |"
        let table = TableBlock.tables(in: grid).first!
        var position = TableBlock.CellPosition(row: 0, column: 0)
        var visited: [TableBlock.CellPosition] = [position]
        while let next = table.cellAfter(position) { position = next; visited.append(next) }

        #expect(visited == [.init(row: 0, column: 0), .init(row: 0, column: 1), .init(row: 0, column: 2),
                            .init(row: 1, column: 0), .init(row: 1, column: 1), .init(row: 1, column: 2)])
    }

    @Test func theLastCellHasNothingAfterIt() {
        let table = TableBlock.tables(in: "| a | b |\n| --- | --- |\n| c | d |").first!
        #expect(table.cellAfter(.init(row: 1, column: 1)) == nil)
    }

    @Test func shiftTabWalksBackTheSameWay() {
        let grid = "| a | b | c |\n| --- | --- | --- |\n| d | e | f |"
        let table = TableBlock.tables(in: grid).first!
        #expect(table.cellBefore(.init(row: 1, column: 0)) == .init(row: 0, column: 2))
        #expect(table.cellBefore(.init(row: 0, column: 1)) == .init(row: 0, column: 0))
        #expect(table.cellBefore(.init(row: 0, column: 0)) == nil)
    }

    @Test func forwardAndBackAreExactInverses() {
        let grid = "| a | b | c |\n| --- | --- | --- |\n| d | e | f |\n| g | h | i |"
        let table = TableBlock.tables(in: grid).first!
        for row in 0..<table.rows.count {
            for column in 0..<table.width {
                let here = TableBlock.CellPosition(row: row, column: column)
                if let next = table.cellAfter(here) {
                    #expect(table.cellBefore(next) == here, "\(here) → \(next) did not come back")
                }
            }
        }
    }

    @Test func theRuleIsNeverACellYouCanReach() {
        // Navigation walks `rows`, which has no rule in it — so no amount of tabbing lands on storage.
        let table = TableBlock.tables(in: source).first!
        var position = TableBlock.CellPosition(row: 0, column: 0)
        var lines: Set<Int> = []
        repeat {
            lines.insert(table.sourceLine(forRow: position.row)!)
            guard let next = table.cellAfter(position) else { break }
            position = next
        } while true
        #expect(!lines.contains(2), "tabbing reached the header rule's line")
    }

    @Test func readingBackACell() {
        #expect(table.cell(at: .init(row: 0, column: 0)) == "Base")
        #expect(table.cell(at: .init(row: 2, column: 1)) == "2")
        #expect(table.cell(at: .init(row: 9, column: 0)) == nil)
    }
}
