import Testing
import Foundation
import UIKit
@testable import Yourly

/// Which blocks give up their card, and when.
///
/// The rule this pins, amended 2026-08-23: **only the block the caret is inside shows its source.**
/// Before it, a single boolean — "does the body have the keyboard" — decided the whole note at once, so
/// tapping anywhere to type one sentence turned every table and every code block in a long note back
/// into raw syntax simultaneously.
struct EditedBlockScopeTests {

    // MARK: The line arithmetic the scope is built on

    @Test func aCaretFindsItsOwnLine() {
        let text = "one\ntwo\nthree" as NSString
        #expect(StructuredText.lineIndex(of: 0, in: text) == 0)
        #expect(StructuredText.lineIndex(of: 3, in: text) == 0)     // on line 0's trailing newline
        #expect(StructuredText.lineIndex(of: 4, in: text) == 1)     // first character of line 1
        #expect(StructuredText.lineIndex(of: 12, in: text) == 2)
    }

    @Test func aCaretsLineMatchesTheParsersAnswer() {
        // The cheap newline count must agree with `MarkupDocument`, or a block would de-render at a
        // different moment than the caret rules think it does.
        let source = "# Head\n- one\n\n| a | b |\n| --- | --- |\ntail"
        let text = source as NSString
        let doc = MarkupDocument(source)
        for offset in 0...text.length {
            #expect(StructuredText.lineIndex(of: offset, in: text)
                    == doc.lineIndex(containingSource: offset), "disagreed at offset \(offset)")
        }
    }

    @Test func aSelectionSpansEveryLineItTouches() {
        let text = "one\ntwo\nthree" as NSString
        #expect(StructuredText.lineIndices(touchedBy: NSRange(location: 0, length: 0), in: text) == 0...0)
        #expect(StructuredText.lineIndices(touchedBy: NSRange(location: 0, length: 9), in: text) == 0...2)
        // A selection ending exactly at a line's start has taken the newline and nothing else.
        #expect(StructuredText.lineIndices(touchedBy: NSRange(location: 0, length: 4), in: text) == 0...0)
    }

    @Test func aRunOfLinesReportsItsCharacterRange() {
        let text = "one\ntwo\nthree" as NSString
        #expect(StructuredText.characterRange(ofLines: 0...0, in: text) == NSRange(location: 0, length: 3))
        #expect(StructuredText.characterRange(ofLines: 1...1, in: text) == NSRange(location: 4, length: 3))
        #expect(StructuredText.characterRange(ofLines: 0...2, in: text) == NSRange(location: 0, length: 13))
        #expect(StructuredText.characterRange(ofLines: 1...2, in: text) == NSRange(location: 4, length: 9))
        #expect(StructuredText.characterRange(ofLines: 5...5, in: text) == nil)
    }

    @Test func aRunOfLinesAgreesWithTheParser() {
        let source = "# Head\n```\nx = 1\n```\ntail"
        let text = source as NSString
        let doc = MarkupDocument(source)
        for index in doc.lines.indices {
            #expect(StructuredText.characterRange(ofLines: index...index, in: text)
                    == doc.lines[index].sourceRange, "disagreed at line \(index)")
        }
    }

    // MARK: The scope itself

    /// The note used throughout: prose, a table, prose, a code block, prose.
    private let source = """
    Art prints

    | Size | File |
    | --- | --- |
    | 20×30 | a.tif |

    Totals below

    ```python
    total = 12
    ```

    One more thing
    """

    private func lines(_ index: Int) -> ClosedRange<Int> { index...index }

    @Test func theNoteHasTheBlocksTheseTestsAssumes() {
        #expect(TableBlock.tables(in: source).first?.lineRange == 2...4)
        #expect(CodeBlock.blocks(in: source).first?.lineRange == 8...10)
    }

    @Test func typingInProseLeavesEveryBlockRendered() {
        // The caret is on "One more thing", which is neither block. This is the case that was broken:
        // both blocks used to de-render because the keyboard was up at all.
        let caret = lines(12)
        #expect(!caret.overlaps(TableBlock.tables(in: source)[0].lineRange))
        #expect(!caret.overlaps(CodeBlock.blocks(in: source)[0].lineRange))
    }

    @Test func onlyTheTableTheCaretIsInGivesUpItsCard() {
        let caret = lines(3)                       // inside the table
        #expect(caret.overlaps(TableBlock.tables(in: source)[0].lineRange))
        #expect(!caret.overlaps(CodeBlock.blocks(in: source)[0].lineRange))
    }

    @Test func onlyTheCodeBlockTheCaretIsInGivesUpItsCard() {
        let caret = lines(9)                       // inside the fence
        #expect(caret.overlaps(CodeBlock.blocks(in: source)[0].lineRange))
        #expect(!caret.overlaps(TableBlock.tables(in: source)[0].lineRange))
    }

    @Test func aCaretOnAFenceLineCountsAsInsideTheBlock() {
        // The fences are the block's own lines; a caret on one is editing that block.
        for line in [8, 10] {
            #expect(lines(line).overlaps(CodeBlock.blocks(in: source)[0].lineRange))
        }
    }

    @Test func aSelectionAcrossTheWholeNoteTakesEveryBlockToSource() {
        let all = StructuredText.lineIndices(
            touchedBy: NSRange(location: 0, length: (source as NSString).length),
            in: source as NSString)
        #expect(all.overlaps(TableBlock.tables(in: source)[0].lineRange))
        #expect(all.overlaps(CodeBlock.blocks(in: source)[0].lineRange))
    }

    @Test func twoBlocksOfTheSameKindAreScopedIndependently() {
        let two = "```\na\n```\nbetween\n```\nb\n```"
        let blocks = CodeBlock.blocks(in: two)
        #expect(blocks.count == 2)
        let caret = 1...1                          // inside the first block only
        #expect(caret.overlaps(blocks[0].lineRange))
        #expect(!caret.overlaps(blocks[1].lineRange))
    }
}

/// The presenters, driven the way the editor drives them.
@MainActor
struct CardPresenterScopeTests {

    private func textView(_ source: String) -> UITextView {
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 360, height: 800)
        tv.textContainer.size = CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
        tv.text = source
        return tv
    }

    private let source = "Before\n| a | b |\n| --- | --- |\n| 1 | 2 |\nAfter\n```\nx = 1\n```\nEnd"

    @Test func nothingBeingEditedRendersEveryBlock() {
        let tv = textView(source)
        #expect(TableCardPresenter().plan(for: tv, sourceLines: nil).count == 1)
        #expect(CodeCardPresenter().plan(for: tv, sourceLines: nil).count == 1)
    }

    @Test func aCaretInProseStillRendersEveryBlock() {
        let tv = textView(source)
        // Line 4 is "After" — between the two blocks, inside neither.
        #expect(TableCardPresenter().plan(for: tv, sourceLines: 4...4).count == 1)
        #expect(CodeCardPresenter().plan(for: tv, sourceLines: 4...4).count == 1)
    }

    @Test func aTableKeepsItsGridWhereverTheCaretIs() {
        // Amended 2026-08-24 (Item 4): a table no longer gives up its grid to be edited, because it is
        // now edited *as* a grid. This test previously asserted the opposite.
        let tv = textView(source)
        for caret in [nil, 0...0, 2...2, 6...6] as [ClosedRange<Int>?] {
            #expect(TableCardPresenter().plan(for: tv, sourceLines: caret).count == 1,
                    "the table stopped being a table for caret \(String(describing: caret))")
        }
        #expect(CodeCardPresenter().plan(for: tv, sourceLines: 2...2).count == 1)
    }

    @Test func aCaretInsideTheCodeDropsOnlyTheCodesCard() {
        let tv = textView(source)
        #expect(CodeCardPresenter().plan(for: tv, sourceLines: 6...6).isEmpty)
        #expect(TableCardPresenter().plan(for: tv, sourceLines: 6...6).count == 1)
    }

    @Test func aPlanIsStableAcrossRepeatedCalls() {
        // The measurement cache must not change what is planned — only how fast it is planned.
        let tv = textView(source)
        let presenter = CodeCardPresenter()
        let first = presenter.plan(for: tv, sourceLines: nil)
        let second = presenter.plan(for: tv, sourceLines: nil)
        let third = presenter.plan(for: tv, sourceLines: nil)
        #expect(first == second)
        #expect(second == third)
    }

    @Test func aCachedLayoutIsNotReusedForDifferentCode() {
        let presenter = CodeCardPresenter()
        let short = textView("```\nx\n```")
        let tall = textView("```\na\nb\nc\nd\ne\n```")
        let shortHeight = presenter.plan(for: short, sourceLines: nil).values.first ?? 0
        let tallHeight = presenter.plan(for: tall, sourceLines: nil).values.first ?? 0
        #expect(tallHeight > shortHeight)
    }

    @Test func thereIsNoPlanBeforeThereIsAWidth() {
        let tv = StructuredTextView.make()
        tv.text = source
        tv.textContainer.size = CGSize(width: 0, height: 0)
        #expect(CodeCardPresenter().plan(for: tv, sourceLines: nil).isEmpty)
        #expect(TableCardPresenter().plan(for: tv, sourceLines: nil).isEmpty)
    }
}

/// The layout shift a block causes when it changes shape, which is the thing `restyle` compensates for.
///
/// A card and its source are different heights. When a block above the caret flips, everything below it
/// moves — so the editor holds the caret's position on screen by shifting `contentOffset` by exactly the
/// distance the caret moved in content coordinates. These tests pin the quantity that correction is made
/// of, at geometry rather than through UI coordinates.
@MainActor
struct BlockFlipGeometryTests {

    private func textView(_ source: String) -> StructuredTextView {
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 360, height: 800)
        tv.textContainer.size = CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
        tv.text = source
        return tv
    }

    /// The y of the first glyph of `line`, in content coordinates.
    private func y(ofLine line: Int, in tv: StructuredTextView) -> CGFloat {
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        let text = tv.text as NSString
        guard let range = StructuredText.characterRange(ofLines: line...line, in: text) else { return 0 }
        let glyphs = tv.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return tv.layoutManager.boundingRect(forGlyphRange: glyphs, in: tv.textContainer).minY
    }

    private func style(_ tv: StructuredTextView, tables: [ClosedRange<Int>: CGFloat] = [:],
                       code: [ClosedRange<Int>: CGFloat] = [:]) {
        StructuredTextStyler.apply(to: tv.textStorage, textColor: .label,
                                   tableCards: tables, codeCards: code)
    }

    private let withTable = "Above\n| a | b |\n| --- | --- |\n| 1 | 2 |\nBelow"
    private let withCode = "Above\n```\nx = 1\ny = 2\n```\nBelow"

    @Test func reservingCardHeightForATableMovesEverythingUnderIt() {
        // Since Item 4 a table does not flip presentation from the caret — it is always a grid. The
        // reserve mechanism this pins is still live: it is what a table that cannot be laid out as a
        // card falls back from, and it is the same machinery code blocks use. Driven directly rather
        // than through the presenter, which no longer has a "source" answer for a table to give.
        let tv = textView(withTable)
        let presenter = TableCardPresenter()

        style(tv, tables: presenter.plan(for: tv, sourceLines: nil))
        let belowAsCard = y(ofLine: 4, in: tv)

        style(tv, tables: [:])              // the fallback: the table laid out as its own lines
        let belowAsSource = y(ofLine: 4, in: tv)

        #expect(belowAsCard != belowAsSource,
                "a table changed presentation without moving the text under it — nothing to compensate")
    }

    @Test func theShiftUnderneathIsExactlyTheBlocksOwnHeightChange() {
        // This is the correction's whole justification: the distance the text below moves equals the
        // distance the caret moves, so shifting the scroll offset by the caret's delta cancels it out.
        let tv = textView(withTable)
        let presenter = TableCardPresenter()

        style(tv, tables: presenter.plan(for: tv, sourceLines: nil))
        let blockAsCard = y(ofLine: 4, in: tv) - y(ofLine: 1, in: tv)
        let belowAsCard = y(ofLine: 4, in: tv)

        style(tv, tables: presenter.plan(for: tv, sourceLines: 1...1))
        let blockAsSource = y(ofLine: 4, in: tv) - y(ofLine: 1, in: tv)
        let belowAsSource = y(ofLine: 4, in: tv)

        let shiftBelow = belowAsSource - belowAsCard
        let blockGrowth = blockAsSource - blockAsCard
        #expect(abs(shiftBelow - blockGrowth) < 0.5,
                "text below moved by \(shiftBelow) while the block changed by \(blockGrowth)")
    }

    @Test func aBlockNeverMovesTheTextAboveIt() {
        // Compensation only has to account for what happens *below* a block. If flipping one moved the
        // line above it, holding the caret would need a different rule entirely.
        let tv = textView(withTable)
        let presenter = TableCardPresenter()

        style(tv, tables: presenter.plan(for: tv, sourceLines: nil))
        let aboveAsCard = y(ofLine: 0, in: tv)

        style(tv, tables: presenter.plan(for: tv, sourceLines: 1...1))
        #expect(abs(y(ofLine: 0, in: tv) - aboveAsCard) < 0.5)
    }

    @Test func aCodeBlockFlippingShapeMovesEverythingUnderIt() {
        let tv = textView(withCode)
        let presenter = CodeCardPresenter()

        style(tv, code: presenter.plan(for: tv, sourceLines: nil))
        let belowAsCard = y(ofLine: 5, in: tv)

        style(tv, code: presenter.plan(for: tv, sourceLines: 2...2))
        #expect(y(ofLine: 5, in: tv) != belowAsCard)
    }

    @Test func aBlockTheCaretIsNotInDoesNotMoveAnything() {
        // Two code blocks; the caret is in the second. The first keeps its card, so nothing above the
        // second block shifts at all — which is the change this whole rule exists to make.
        let tv = textView("```\na\n```\nmiddle\n```\nb\n```\nend")
        let presenter = CodeCardPresenter()

        style(tv, code: presenter.plan(for: tv, sourceLines: nil))
        let middleBefore = y(ofLine: 3, in: tv)

        style(tv, code: presenter.plan(for: tv, sourceLines: 5...5))
        #expect(abs(y(ofLine: 3, in: tv) - middleBefore) < 0.5,
                "editing the second block moved the text above it")
    }
}
