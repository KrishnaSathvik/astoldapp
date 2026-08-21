import Testing
import Foundation
@testable import Yourly

/// Reading a table back out of `body`. The bar for calling a run of lines a table is deliberately
/// high: a note that drew a grid because someone typed a vertical bar would be worse than one that
/// drew nothing.
struct TableBlockDetectionTests {

    @Test func aCanonicalTableIsFound() {
        let source = "| Day | Park |\n| --- | --- |\n| 1 | Denali |\n| 2 | Katmai |"
        let table = TableBlock.tables(in: source).first
        #expect(table?.width == 2)
        #expect(table?.header == ["Day", "Park"])
        #expect(table?.records == [["1", "Denali"], ["2", "Katmai"]])
        #expect(table?.hasHeaderRule == true)
        #expect(table?.lineRange == 0...3)
    }

    @Test func twoPipeRowsAreATableWithoutARule() {
        let table = TableBlock.tables(in: "| a | b |\n| c | d |").first
        #expect(table?.records == [["c", "d"]])
        #expect(table?.hasHeaderRule == false)
    }

    @Test func proseThatMerelyContainsAPipeIsNotATable() {
        #expect(TableBlock.tables(in: "chicken | rice\nmilk | eggs").isEmpty)
        #expect(TableBlock.tables(in: "The cost | is high").isEmpty)
    }

    @Test func aLonePipeRowIsNotATable() {
        #expect(TableBlock.tables(in: "| just one row |").isEmpty)
    }

    @Test func aTableIsFoundAmongTheProseAroundIt() {
        let source = "# Trip\nBefore.\n| Day | Park |\n| --- | --- |\n| 1 | Denali |\nAfter."
        let table = TableBlock.tables(in: source).first
        #expect(table?.lineRange == 2...4)
        #expect(TableBlock.table(in: source, atLine: 3) != nil)
        #expect(TableBlock.table(in: source, atLine: 5) == nil)
    }

    @Test func twoTablesAreTwoTables() {
        let source = "| a | b |\n| --- | --- |\n| 1 | 2 |\n\n| c | d |\n| --- | --- |\n| 3 | 4 |"
        #expect(TableBlock.tables(in: source).count == 2)
    }

    @Test func rowsOfUnevenLengthArePaddedRatherThanDropped() {
        let table = TableBlock.tables(in: "| a | b | c |\n| --- | --- | --- |\n| 1 |").first
        #expect(table?.width == 3)
        #expect(table?.records == [["1", "", ""]])
    }
}

struct TableBlockCellTests {

    @Test func cellsKeepTheirWordsAndLoseOnlyTheirPadding() {
        #expect(TableBlock.cells(of: "|  Kenai Fjords  |  5 hrs driving |")
                == ["Kenai Fjords", "5 hrs driving"])
    }

    @Test func anEmptyCellStaysACell() {
        #expect(TableBlock.cells(of: "| a |  | c |") == ["a", "", "c"])
    }

    @Test func aPipeInsideACellTravelsEscapedAndComesBackWhole() {
        let row = TableBlock.row(["either | or", "b"])
        #expect(TableBlock.cells(of: row) == ["either | or", "b"])
    }

    @Test func multilingualCellsAreUntouched() {
        let row = TableBlock.row(["హైదరాబాద్", "मुंबई", "—"])
        #expect(TableBlock.cells(of: row) == ["హైదరాబాద్", "मुंबई", "—"])
    }

    @Test func aRowTheWriterNeverClosedKeepsItsLastCell() {
        #expect(TableBlock.cells(of: "| a | b") == ["a", "b"])
    }

    @Test func delimiterRowsAreRecognizedInTheirUsualSpellings() {
        #expect(TableBlock.isDelimiter("| --- | --- |"))
        #expect(TableBlock.isDelimiter("| :-: | ---: |"))
        #expect(!TableBlock.isDelimiter("| a | b |"))
        #expect(!TableBlock.isDelimiter("|  |  |"))
    }

    @Test func aWrittenRowReadsBackIdentically() {
        let cells = ["Day", "Kenai Fjords Full Day", "", "5 hrs"]
        #expect(TableBlock.cells(of: TableBlock.row(cells)) == cells)
    }
}
