import Testing
import UIKit
@testable import Yourly

/// How a table is laid out for reading. The two examples here are the ones that came off a physical
/// iPhone and were rejected: an expense table that has to read as an expense table, and a seven-column
/// itinerary that cannot be crushed into 393 points and must not try.
@MainActor
struct TableCardLayoutTests {

    /// The writing width of an iPhone 17 Pro note: screen less the page's horizontal margins.
    private let phoneWidth: CGFloat = 353

    private func table(_ source: String) -> TableBlock {
        TableBlock.tables(in: source).first!
    }

    private var expenses: TableBlock {
        table("""
        | Expense | 2 people |
        | --- | --- |
        | 9 nights lodging | $2,400-$3,600 |
        | Rental car | $1,500-$2,000 |
        | Kenai Fjords cruise | $525-$625 |
        | Estimated total | $6,425-$9,275 |
        """)
    }

    private var itinerary: TableBlock {
        table("""
        | Day | Date | Schedule | Park | Travel | Overnight | Meals |
        | --- | --- | --- | --- | --- | --- | --- |
        | 1 | Sat | Arrive & settle | — | 20 min | Anchorage | Dinner out |
        | 2 | Sun | Kenai Fjords cruise | Kenai Fjords | 5 hrs | Seward | Packed lunch |
        | 3 | Mon | Recovery day | — | 2 hrs | Anchorage | Groceries |
        """)
    }

    // MARK: Full

    @Test func aTwoColumnTableIsReadInFullOnAPhone() {
        let layout = TableCardLayout.layout(for: expenses, availableWidth: phoneWidth)
        #expect(layout?.isPreview == false)
        #expect(layout?.rows.count == 4)
        #expect(layout?.footer == nil)
        #expect(layout?.header == ["Expense", "2 people"])
    }

    /// The column of labels is wider than the column of amounts, because the words in it are. Equal
    /// halves would give "2 people" the same room as "Kenai Fjords cruise", which is not what the table
    /// says — and would leave the amounts column with room it has nothing to put in.
    @Test func columnsTakeTheWidthTheirWordsNeedRatherThanAnEqualShare() {
        let costs = table("| Item | Cost |\n| --- | --- |\n| Boat tour | $229 |\n| Denali bus | $170 |")
        let widths = TableCardLayout.layout(for: costs, availableWidth: phoneWidth)!.columnWidths
        #expect(widths.count == 2)
        let share = widths[0] / (widths[0] + widths[1])
        #expect(share > 0.6 && share < 0.8, "Item/Cost split was \(share), expected roughly 70/30")
    }

    /// The shares follow the words, so a table of long amounts is *not* forced to 70/30 — the labels
    /// still lead, but the amounts keep the room their digits need.
    @Test func aColumnOfLongAmountsKeepsTheRoomItNeeds() {
        let widths = TableCardLayout.layout(for: expenses, availableWidth: phoneWidth)!.columnWidths
        #expect(widths[0] > widths[1])
        let share = widths[0] / (widths[0] + widths[1])
        #expect(share > 0.5 && share < 0.7)
    }

    /// A narrow heading has no claim on an equal share of a phone screen. `Day` holds one digit.
    @Test func aNarrowColumnDoesNotTakeAnEqualShare() {
        let plan = table("""
        | Day | Date | Park | Overnight |
        | --- | --- | --- | --- |
        | 1 | Sat | — | Anchorage |
        | 2 | Sun | Kenai Fjords | Anchorage |
        """)
        let widths = TableCardLayout.layout(for: plan, availableWidth: phoneWidth)!.columnWidths
        #expect(widths.count == 4)
        #expect(widths[0] < phoneWidth / 4)
        #expect(widths[2] > widths[0])
    }

    /// Every cell in the amounts column is a quantity, so it lines up on its digits — which is what
    /// makes a total scannable. The column of labels stays where reading starts.
    @Test func aColumnOfAmountsIsRightAligned() {
        let layout = TableCardLayout.layout(for: expenses, availableWidth: phoneWidth)!
        #expect(layout.alignments == [.left, .right])
    }

    @Test func aColumnOfWordsIsNotRightAligned() {
        let days = table("| Day | Park |\n| --- | --- |\n| 1 | Denali |\n| 2 | Katmai |")
        #expect(TableCardLayout.layout(for: days, availableWidth: phoneWidth)!.alignments == [.left, .left])
    }

    /// Four columns of short values still read inline — the cut-off is whether the words fit, not a
    /// column count somebody picked.
    @Test func fourNarrowColumnsStillReadInline() {
        let plan = table("""
        | Day | Date | Park | Overnight |
        | --- | --- | --- | --- |
        | 1 | Sat | — | Anchorage |
        | 2 | Sun | Kenai Fjords | Anchorage |
        """)
        #expect(TableCardLayout.layout(for: plan, availableWidth: phoneWidth)?.isPreview == false)
    }

    // MARK: Preview

    @Test func aSevenColumnItineraryIsPreviewedRatherThanCrushed() {
        let layout = TableCardLayout.layout(for: itinerary, availableWidth: phoneWidth)
        #expect(layout?.isPreview == true)
        #expect(layout?.columnWidths.count == TableCardLayout.Metrics.previewColumns)
        #expect(layout?.header == ["Day", "Date", "Schedule"])
    }

    /// The preview says what it is holding back, because a preview that looks complete is a lie about
    /// the note.
    @Test func aPreviewSaysHowMuchMoreThereIs() {
        #expect(TableCardLayout.layout(for: itinerary, availableWidth: phoneWidth)?.footer
                == "3 rows · 7 columns")
    }

    @Test func aPreviewShowsAtMostThreeRows() {
        let long = table((["| A | B | C | D | E | F | G |", "| --- | --- | --- | --- | --- | --- | --- |"]
                          + (1...9).map { "| \($0) | b | c | d | e | f | g |" }).joined(separator: "\n"))
        let layout = TableCardLayout.layout(for: long, availableWidth: phoneWidth)!
        #expect(layout.isPreview)
        #expect(layout.rows.count == TableCardLayout.Metrics.previewRows)
        #expect(layout.footer == "9 rows · 7 columns")
    }

    /// A table whose cells are long enough to wrap into paragraphs has stopped being a table on this
    /// screen, whatever its column count — the grid is a tap away instead.
    @Test func columnsThatWouldWrapIntoParagraphsBecomeAPreview() {
        let wordy = table("""
        | Stop | Notes |
        | --- | --- |
        | Seward | We drive down on the Sunday morning and take the afternoon cruise out of the harbour, \
        then stay two nights so nobody has to turn around and drive back the same evening in the rain. |
        """)
        #expect(TableCardLayout.layout(for: wordy, availableWidth: phoneWidth)?.isPreview == true)
    }

    // MARK: Room on the page

    /// The card is what the note reserves room for, plus the air around it — the number the styler
    /// squeezes the source lines down to.
    @Test func theReservedHeightIsTheCardPlusItsMargins() {
        let layout = TableCardLayout.layout(for: expenses, availableWidth: phoneWidth)!
        #expect(layout.reservedHeight == layout.size.height + TableCardLayout.Metrics.blockMargin * 2)
        #expect(layout.size.height > 0)
        #expect(layout.size.width == phoneWidth)
    }

    /// Before the page has been laid out there is no width to measure against, and a table measured at
    /// zero would reserve nothing and draw on top of the paragraph above it.
    @Test func thereIsNoLayoutBeforeThereIsAWidth() {
        #expect(TableCardLayout.layout(for: expenses, availableWidth: 0) == nil)
    }

    @Test func everyTableInANoteGetsALayout() {
        let source = """
        Pasted from the trip plan.

        | Day | Park |
        | --- | --- |
        | 1 | Denali |

        Costs so far.

        | Item | Cost |
        | --- | --- |
        | Boat tour | $229 |
        """
        let layouts = TableCardLayout.layouts(in: source, availableWidth: phoneWidth)
        #expect(layouts.count == 2)
        #expect(layouts.map(\.table.lineRange) == [2...4, 8...10])
    }

    // MARK: Quantities

    @Test func aQuantityIsDigitsAndTheMarksMoneyIsWrittenWith() {
        #expect(TableCardLayout.isQuantity("$2,400-$3,600"))
        #expect(TableCardLayout.isQuantity("229"))
        #expect(TableCardLayout.isQuantity("12%"))
        #expect(!TableCardLayout.isQuantity("5 hrs"))
        #expect(!TableCardLayout.isQuantity("Anchorage"))
        #expect(!TableCardLayout.isQuantity("—"))
    }
}

/// The other half of the bargain: the source those cards stand in for is *hidden*, not re-spaced.
@MainActor
struct TableSourceHidingTests {

    private func storage(_ source: String) -> NSTextStorage {
        NSTextStorage(string: source)
    }

    private let source = """
    Before.

    | Item | Cost |
    | --- | --- |
    | Boat tour | $229 |

    After.
    """

    private var tableLines: NSRange {
        let ns = source as NSString
        let start = ns.range(of: "| Item").location
        let end = ns.range(of: "| Boat tour | $229 |")
        return NSRange(location: start, length: end.location + end.length - start)
    }

    /// Reading: not one glyph of `| Item | Cost |` reaches the screen.
    @Test func aTableBeingReadHasEveryGlyphOfItsSourceHidden() {
        let store = storage(source)
        StructuredTextStyler.apply(to: store, textColor: .label, availableWidth: 353,
                                   tableCards: [2...4: 200])

        var hidden = 0
        store.enumerateAttribute(.astHiddenMarker, in: tableLines) { value, range, _ in
            if value != nil { hidden += range.length }
        }
        #expect(hidden == tableLines.length - 2)   // the two newlines inside the block carry no glyphs
    }

    /// And the lines it hides are squeezed to the height the card asked for, so the card has somewhere
    /// to sit and the paragraphs around it are not written over.
    @Test func theHiddenLinesAreSqueezedToTheCardsHeight() {
        let store = storage(source)
        StructuredTextStyler.apply(to: store, textColor: .label, availableWidth: 353,
                                   tableCards: [2...4: 200])
        var total: CGFloat = 0
        store.enumerateAttribute(.paragraphStyle, in: tableLines) { value, range, _ in
            guard let style = value as? NSParagraphStyle, range.length > 0 else { return }
            total = max(total, style.maximumLineHeight)
        }
        #expect(total > 190 && total <= 200)
    }

    /// Editing: nothing is hidden. The writer is entitled to see the characters they are editing, and
    /// a caret inside text that is not drawn is the bug this replaced.
    @Test func aTableBeingEditedShowsItsSourceUntouched() {
        let store = storage(source)
        StructuredTextStyler.apply(to: store, textColor: .label, availableWidth: 353)

        var hidden = 0
        store.enumerateAttribute(.astHiddenMarker, in: tableLines) { value, range, _ in
            if value != nil { hidden += range.length }
        }
        #expect(hidden == 0)
    }

    /// One container behind the whole block rather than one per line — per-line runs stacked rounded
    /// rectangles into a banded staircase that read as highlighted text.
    @Test func theSourceContainerIsOneRunAcrossTheWholeBlock() {
        let store = storage(source)
        StructuredTextStyler.apply(to: store, textColor: .label, availableWidth: 353)

        var runs = 0
        store.enumerateAttribute(.astTableBlock, in: NSRange(location: 0, length: store.length)) { value, _, _ in
            if value != nil { runs += 1 }
        }
        #expect(runs == 1)
    }
}
