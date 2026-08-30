import Testing
import Foundation
import UIKit
@testable import Yourly

/// The delimiter row is storage, not writing.
///
/// `| --- | --- |` records which row is the header. Nobody typed it to be read, and it is the one part
/// of a table's source that says nothing about the table's contents — so it is not drawn, in reading or
/// in writing (RULES.md §7, amended 2026-08-23). It stays in `body` untouched, which is what lets the
/// parser keep working, copy keep round-tripping, and every existing note get the behaviour without
/// being rewritten.
struct TableDelimiterStorageTests {

    private let source = "| Size | File |\n| --- | --- |\n| 20×30 | art.tif |\n| 16×24 | photo.tif |"

    @Test func theDelimiterStaysInTheNote() {
        // The whole point: nothing rewrites `body`. Hiding is a presentation, not an edit.
        #expect(source.contains("| --- | --- |"))
        #expect(StructuredText.canonicalized(source) == source)
    }

    @Test func theDelimiterLineIsRecognisedAsHidden() {
        #expect(TableBlock.isHiddenDelimiter(in: source, atLine: 1))
        #expect(!TableBlock.isHiddenDelimiter(in: source, atLine: 0))
        #expect(!TableBlock.isHiddenDelimiter(in: source, atLine: 2))
    }

    @Test func aDelimiterOutsideATableIsNotHidden() {
        // A lone `| --- |` is not a table at all, so there is nothing it is the header rule *of*, and
        // hiding it would delete a line of the note from view for no reason.
        #expect(!TableBlock.isHiddenDelimiter(in: "| --- | --- |", atLine: 0))
        #expect(!TableBlock.isHiddenDelimiter(in: "just words", atLine: 0))
    }

    @Test func aTableWithNoRuleHidesNothing() {
        let noRule = "| a | b |\n| c | d |"
        #expect(TableBlock.tables(in: noRule).first?.hasHeaderRule == false)
        for line in 0...1 { #expect(!TableBlock.isHiddenDelimiter(in: noRule, atLine: line)) }
    }

    @Test func theTableStillParsesWithItsHeaderIntact() {
        let table = TableBlock.tables(in: source).first
        #expect(table?.hasHeaderRule == true)
        #expect(table?.header == ["Size", "File"])
        #expect(table?.records == [["20×30", "art.tif"], ["16×24", "photo.tif"]])
    }
}

/// The caret may not sit on a line that is not drawn.
struct TableDelimiterCaretTests {

    // Offsets: line 0 is 0...14 with its newline at 15; the delimiter line is 16...28 with its
    // newline at 29; the first data row therefore starts at 30.
    private let source = "| Size | File |\n| --- | --- |\n| 20×30 | art.tif |"

    @Test func aCaretMovingDownLandsOnTheFirstRow() {
        // Arrowing down out of the header must reach the row, not stop on something invisible.
        let escape = TableBlock.caretEscape(in: source, from: 17, movingForward: true)
        #expect(escape == 30)
    }

    @Test func aCaretMovingUpLandsBackOnTheHeader() {
        // …and arrowing up out of the first row must reach the header, rather than being pushed back
        // down to where it started. One direction for both would trap the caret against an edge.
        let escape = TableBlock.caretEscape(in: source, from: 17, movingForward: false)
        #expect(escape == 15)
    }

    @Test func aCaretAnywhereElseIsLeftAlone() {
        #expect(TableBlock.caretEscape(in: source, from: 0, movingForward: true) == nil)
        #expect(TableBlock.caretEscape(in: source, from: 31, movingForward: true) == nil)
    }

    @Test func everyOffsetOnTheDelimiterLineEscapes() {
        // Not just its start: a tap resolves to whichever character is nearest, and every one of them
        // is on a line the writer cannot see.
        for offset in 16...28 {
            #expect(TableBlock.caretEscape(in: source, from: offset, movingForward: true) != nil,
                    "offset \(offset) was left on the hidden row")
        }
    }

    @Test func anEscapeNeverLandsBackOnAHiddenRow() {
        for offset in 16...28 {
            for forward in [true, false] {
                guard let escape = TableBlock.caretEscape(in: source, from: offset,
                                                          movingForward: forward) else { continue }
                #expect(TableBlock.caretEscape(in: source, from: escape, movingForward: forward) == nil,
                        "escaping from \(offset) landed on the hidden row again")
            }
        }
    }

    @Test func aTableThatOpensTheNoteStillLetsTheCaretOut() {
        // No line above the delimiter to fall back to, so the row below is the only place to be.
        let escape = TableBlock.caretEscape(in: source, from: 17, movingForward: false)
        #expect(escape != nil)
        #expect(TableBlock.caretEscape(in: source, from: escape!, movingForward: false) == nil)
    }
}

/// Backspace at the start of the first row.
struct TableDelimiterBackspaceTests {

    private let source = "| Size | File |\n| --- | --- |\n| 20×30 | art.tif |\n| 16×24 | p.tif |"

    @Test func backspaceJoinsTheRowToTheHeaderAndTakesTheHiddenRowWithIt() {
        // Joining to the line the writer *sees*. Without this it welded the row onto the delimiter —
        // `| --- | --- || 20×30 |` — which stops being a delimiter and takes the table with it.
        let caret = NSRange(location: 30, length: 0)   // start of the first data row
        let edit = DocumentAction.backspaceEdit(text: source, selection: caret)
        let result = edit?.applied(to: source).text
        #expect(result == "| Size | File || 20×30 | art.tif |\n| 16×24 | p.tif |")
        #expect(!(result ?? "").contains("---"))
    }

    @Test func whatIsLeftIsStillATable() {
        // `TableBlock` accepts two pipe rows without a rule, so the table degrades rather than breaking.
        let caret = NSRange(location: 30, length: 0)
        let result = DocumentAction.backspaceEdit(text: source, selection: caret)?
            .applied(to: source).text ?? ""
        let table = TableBlock.tables(in: result).first
        #expect(table != nil)
        #expect(table?.hasHeaderRule == false)
        #expect(table?.records.count == 1)
    }

    @Test func backspaceElsewhereIsUnchanged() {
        // The guard is narrow: only the start of a line that follows a hidden delimiter.
        #expect(DocumentAction.backspaceEdit(text: source,
                                             selection: NSRange(location: 35, length: 0)) == nil)
        #expect(DocumentAction.backspaceEdit(text: "- Eggs",
                                             selection: NSRange(location: 2, length: 0)) != nil)
        #expect(DocumentAction.backspaceEdit(text: "plain",
                                             selection: NSRange(location: 3, length: 0)) == nil)
    }
}

/// What the styler draws — the presentation half.
@MainActor
struct TableDelimiterRenderingTests {

    private let source = "Above\n| Size | File |\n| --- | --- |\n| 20×30 | art.tif |"

    private func styled() -> NSTextStorage {
        let storage = NSTextStorage(string: source)
        StructuredTextStyler.apply(to: storage, textColor: .label)
        return storage
    }

    @Test func theDelimitersGlyphsAreHiddenWhileEditing() {
        let storage = styled()
        let delimiter = StructuredText.characterRange(ofLines: 2...2, in: source as NSString)!
        for offset in delimiter.location..<NSMaxRange(delimiter) {
            #expect(storage.attribute(.astHiddenMarker, at: offset, effectiveRange: nil) as? Bool == true,
                    "character \(offset) of the delimiter row is still drawn")
        }
    }

    @Test func theDelimitersLineKeepsNoHeightOfItsOwn() {
        let storage = styled()
        let delimiter = StructuredText.characterRange(ofLines: 2...2, in: source as NSString)!
        let paragraph = storage.attribute(.paragraphStyle, at: delimiter.location,
                                          effectiveRange: nil) as? NSParagraphStyle
        #expect(paragraph?.maximumLineHeight == 1)
    }

    @Test func everyOtherRowIsStillDrawnExactlyAsTyped() {
        // The rejected 2026-08-21 approach re-spaced the source. This one draws one line fewer and
        // changes nothing else, so the header and the rows keep every character they had.
        let storage = styled()
        for line in [1, 3] {
            let range = StructuredText.characterRange(ofLines: line...line, in: source as NSString)!
            #expect(storage.attribute(.astHiddenMarker, at: range.location, effectiveRange: nil) == nil,
                    "line \(line) was hidden and should not have been")
        }
        #expect(storage.string == source)
    }

    @Test func proseIsUntouched() {
        let storage = styled()
        #expect(storage.attribute(.astHiddenMarker, at: 0, effectiveRange: nil) == nil)
    }

    @Test func theDelimiterOfTheEditedTableIsHiddenEvenWhileAnotherTableIsACard() {
        // Per-block editing asks the styler for both presentations at once: the table the caret is in
        // shows its source, every other table stays a card. The one being edited must still hide its
        // delimiter row — it is how the note records which row is the header, and nobody typed it to
        // be read, on any surface.
        let two = "| a | b |\n| --- | --- |\n| 1 | 2 |\nprose\n| c | d |\n| --- | --- |\n| 3 | 4 |"
        let storage = NSTextStorage(string: two)
        StructuredTextStyler.apply(to: storage, textColor: .label, tableCards: [4...6: 90])

        let delimiter = StructuredText.characterRange(ofLines: 1...1, in: two as NSString)!
        #expect(storage.attribute(.astHiddenMarker, at: delimiter.location, effectiveRange: nil) as? Bool == true,
                "the edited table's delimiter row was drawn because another table was a card")
        // And the table that is a card is still hidden whole.
        let carded = StructuredText.characterRange(ofLines: 4...4, in: two as NSString)!
        #expect(storage.attribute(.astHiddenMarker, at: carded.location, effectiveRange: nil) as? Bool == true)
    }

    @Test func aLonePipeRowIsNeverHidden() {
        let storage = NSTextStorage(string: "| --- | --- |")
        StructuredTextStyler.apply(to: storage, textColor: .label)
        #expect(storage.attribute(.astHiddenMarker, at: 0, effectiveRange: nil) == nil)
    }
}

/// What the layout does — the half no text assertion can see.
///
/// Hiding a line means two things that pull against each other: the delimiter must take no vertical
/// space, and the row *under* it must still be a line of its own at full height. A hidden marker is
/// given zero advancement rather than being nulled precisely so its line survives layout
/// (`StructuredLayoutTests`); a hidden **line** has to lose its height without taking its neighbour's.
@MainActor
struct TableDelimiterLayoutTests {

    private let source = "Above\n| Size | File |\n| --- | --- |\n| 20×30 | art.tif |\n| 16×24 | p.tif |"

    private func laidOut() -> UITextView {
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        tv.font = StructuredTextStyle.bodyFont()
        tv.text = source
        StructuredTextStyler.apply(to: tv.textStorage, textColor: .label)
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        return tv
    }

    private func fragment(_ tv: UITextView, line index: Int) -> CGRect {
        let line = MarkupDocument(source).lines[index]
        let glyph = tv.layoutManager.glyphIndexForCharacter(at: line.sourceRange.location)
        return tv.layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
    }

    @Test func theHiddenRowTakesNoHeight() {
        // "No height" means what TextKit will actually give: a fragment clamped to one point still
        // measures a couple of points, so the assertion is against a *line* of body text rather than
        // against zero. Under three points is air nobody can see; a drawn row would be ~24.
        let tv = laidOut()
        let hidden = fragment(tv, line: 2)
        #expect(hidden.height < fragment(tv, line: 1).height / 4)
    }

    @Test func theRowUnderItIsStillAFullLineOfItsOwn() {
        // The failure this pins: hiding the delimiter's *newline* along with its characters would stop
        // it ending the paragraph, and the first data row would be swallowed into the invisible line —
        // collapsed to a point, with the words gone from the note.
        let tv = laidOut()
        let header = fragment(tv, line: 1)
        let row = fragment(tv, line: 3)

        #expect(row.minY > header.minY)
        #expect(row.height == header.height)
        #expect(fragment(tv, line: 4).minY > row.minY)
    }

    @Test func theRowsCloseUpOverTheHiddenLine() {
        // No gap where the delimiter was: a table with an invisible line's worth of air inside it is
        // two tables as far as a reader is concerned.
        let tv = laidOut()
        let header = fragment(tv, line: 1)
        let row = fragment(tv, line: 3)
        #expect(row.minY - header.maxY < header.height / 4)
    }

    @Test func aTableWithNoRuleKeepsEveryLine() {
        let plain = "| a | b |\n| c | d |"
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        tv.font = StructuredTextStyle.bodyFont()
        tv.text = plain
        StructuredTextStyler.apply(to: tv.textStorage, textColor: .label)
        tv.layoutManager.ensureLayout(for: tv.textContainer)

        let lines = MarkupDocument(plain).lines
        let heights = lines.map { line -> CGFloat in
            let glyph = tv.layoutManager.glyphIndexForCharacter(at: line.sourceRange.location)
            return tv.layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).height
        }
        #expect(heights.allSatisfy { $0 > 2 })
    }
}
