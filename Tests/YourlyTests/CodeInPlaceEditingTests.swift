import Testing
import Foundation
import UIKit
import SwiftUI
@testable import Yourly

/// Item 5 — a code block that stays code while it is edited (RULES.md §7, amended 2026-08-24).
///
/// Tapping a code card used to replace it with ```` ```python ```` and a wall of unstyled text: the
/// block a reader had been looking at visibly broke the moment they touched it. The fences are storage,
/// exactly like a table's `| --- |` row, and the note is still one plain `String` underneath — nothing
/// here introduces a second editor, a sheet, or a code document.
@MainActor
struct CodeInPlaceEditingTests {

    private let source = "Notes\n```python\ndef f(x):\n    return x + 1\n```\nAfter"

    private func styled(_ text: String) -> NSTextStorage {
        let storage = NSTextStorage(string: text)
        StructuredTextStyler.apply(to: storage, textColor: .label,
                                   codeTokens: [.keyword: .systemPink, .number: .systemOrange])
        return storage
    }

    private func lineRange(_ line: Int, in text: String) -> NSRange {
        StructuredText.characterRange(ofLines: line...line, in: text as NSString)!
    }

    // MARK: What the writer sees

    @Test func neitherFenceIsDrawn() {
        let storage = styled(source)
        for fence in [1, 4] {
            let range = lineRange(fence, in: source)
            for offset in range.location..<NSMaxRange(range) {
                #expect(storage.attribute(.astHiddenMarker, at: offset, effectiveRange: nil) as? Bool == true,
                        "fence character \(offset) was drawn")
            }
        }
    }

    @Test func everyCharacterOfTheCodeIsDrawn() {
        let storage = styled(source)
        for line in [2, 3] {
            let range = lineRange(line, in: source)
            for offset in range.location..<NSMaxRange(range) {
                #expect(storage.attribute(.astHiddenMarker, at: offset, effectiveRange: nil) == nil)
            }
        }
    }

    @Test func theBlockKeepsItsGroundAndItsMonospacedFace() {
        let storage = styled(source)
        let code = lineRange(2, in: source)
        #expect(storage.attribute(.astCodeBlock, at: code.location, effectiveRange: nil) != nil)
        let font = storage.attribute(.font, at: code.location, effectiveRange: nil) as? UIFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
    }

    @Test func syntaxColourIsOnWhileEditing() {
        // `def` is a Python keyword and must be coloured in the storage the writer is typing into —
        // not only on a card's private copy, which is where colour used to live.
        let storage = styled(source)
        let def = (source as NSString).range(of: "def")
        #expect(storage.attribute(.foregroundColor, at: def.location, effectiveRange: nil) as? UIColor
                == .systemPink)
        // …and the prose above it is untouched.
        #expect(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .label)
    }

    @Test func colourStaysInsideTheBlock() {
        // A span is measured against the block's own code; it must never reach a fence or the prose.
        let storage = styled(source)
        for line in [0, 1, 4, 5] {
            let range = lineRange(line, in: source)
            for offset in range.location..<NSMaxRange(range) {
                let colour = storage.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? UIColor
                #expect(colour != .systemPink && colour != .systemOrange,
                        "syntax colour reached offset \(offset), outside the code")
            }
        }
    }

    @Test func theCodeSitsWhereTheCardDrawsIt() {
        // Found by rendering both presentations and measuring them: a card draws its code `cardInsetH`
        // in from its own edge, while the text view lays the same characters against the writing
        // margin. Without an indent every line slid 14 points left the moment the caret arrived — the
        // exact visible break this presentation exists to remove.
        let storage = styled(source)
        for line in [2, 3] {
            let range = lineRange(line, in: source)
            let paragraph = storage.attribute(.paragraphStyle, at: range.location,
                                              effectiveRange: nil) as? NSParagraphStyle
            #expect(paragraph?.firstLineHeadIndent == CodeCardLayout.Metrics.cardInsetH,
                    "code line \(line) is not inset like the card")
            #expect(paragraph?.headIndent == CodeCardLayout.Metrics.cardInsetH)
            // A long line has to wrap inside the card, not run under its right edge.
            #expect(paragraph?.tailIndent == -CodeCardLayout.Metrics.cardInsetH)
        }
        // The prose around it keeps the writing margin.
        let prose = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect((prose?.firstLineHeadIndent ?? 0) == 0)
    }

    @Test func stylingNeverChangesOneCharacter() {
        #expect(styled(source).string == source)
    }

    // MARK: Editing the code in place

    private func editor(_ text: String) -> (BodyTextView.Coordinator, StructuredTextView, UIWindow) {
        var body = text
        var range = NSRange(location: 0, length: 0)
        var focused = true
        let parent = BodyTextView(text: Binding(get: { body }, set: { body = $0 }),
                                  selectedRange: Binding(get: { range }, set: { range = $0 }),
                                  isFocused: Binding(get: { focused }, set: { focused = $0 }),
                                  isEditable: true, keyboardAppearance: .light)
        let co = parent.makeCoordinator()
        let tv = StructuredTextView.make()
        tv.delegate = co
        tv.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        tv.textContainer.size = CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude)
        tv.text = text
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        window.addSubview(tv)
        window.makeKeyAndVisible()
        _ = tv.becomeFirstResponder()
        return (co, tv, window)
    }

    /// Types `insertion` at `offset` through the delegate, exactly as the keyboard would.
    private func type(_ insertion: String, at offset: Int, in tv: StructuredTextView,
                      _ co: BodyTextView.Coordinator) {
        tv.selectedRange = NSRange(location: offset, length: 0)
        if co.textView(tv, shouldChangeTextIn: NSRange(location: offset, length: 0),
                       replacementText: insertion) {
            tv.textStorage.replaceCharacters(in: NSRange(location: offset, length: 0), with: insertion)
            tv.selectedRange = NSRange(location: offset + (insertion as NSString).length, length: 0)
            co.textViewDidChange(tv)
        }
    }

    @Test func editingTheFirstMiddleAndLastCodeLine() {
        let start = "```python\na = 1\nb = 2\nc = 3\n```"
        for line in [1, 2, 3] {
            let (co, tv, _) = editor(start)
            let range = StructuredText.characterRange(ofLines: line...line, in: start as NSString)!
            type("Z", at: NSMaxRange(range), in: tv, co)

            let block = CodeBlock.blocks(in: tv.text).first
            #expect(block?.lineRange == 0...4, "line \(line): the block lost its shape")
            #expect(block?.codeLines.count == 3)
            #expect(block?.codeLines[line - 1].hasSuffix("Z") == true,
                    "line \(line): the character did not land in the code")
            #expect(tv.text.hasPrefix("```python\n"), "line \(line): the opening fence changed")
            #expect(tv.text.hasSuffix("\n```"), "line \(line): the closing fence changed")
        }
    }

    @Test func aNewlineInsideTheCodeAddsACodeLine() {
        let start = "```python\na = 1\nb = 2\n```"
        let (co, tv, _) = editor(start)
        let first = StructuredText.characterRange(ofLines: 1...1, in: start as NSString)!
        type("\n", at: NSMaxRange(first), in: tv, co)

        let block = CodeBlock.blocks(in: tv.text).first
        #expect(block?.codeLines == ["a = 1", "", "b = 2"])
        #expect(block?.language == "python")
    }

    @Test func indentationAndBlankLinesSurviveEditing() {
        let start = "```python\ndef f():\n\n    return 1\n```"
        let (co, tv, _) = editor(start)
        let last = StructuredText.characterRange(ofLines: 3...3, in: start as NSString)!
        type("0", at: NSMaxRange(last), in: tv, co)

        #expect(CodeBlock.blocks(in: tv.text).first?.codeLines == ["def f():", "", "    return 10"])
    }

    @Test func theLanguageSurvivesEditingAndIsNotReDetected() {
        // The language is whatever the fence stored. Typing SQL into a Python block leaves it Python.
        let start = "```python\na = 1\n```"
        let (co, tv, _) = editor(start)
        let code = StructuredText.characterRange(ofLines: 1...1, in: start as NSString)!
        type(" SELECT * FROM t", at: NSMaxRange(code), in: tv, co)
        #expect(CodeBlock.blocks(in: tv.text).first?.language == "python")
    }

    @Test func syntaxColourFollowsTheEdit() {
        let start = "```python\na = 1\n```"
        let (co, tv, _) = editor(start)
        let code = StructuredText.characterRange(ofLines: 1...1, in: start as NSString)!
        type("\nreturn a", at: NSMaxRange(code), in: tv, co)

        let storage = styled(tv.text)
        let ret = (tv.text as NSString).range(of: "return")
        #expect(ret.location != NSNotFound)
        #expect(storage.attribute(.foregroundColor, at: ret.location, effectiveRange: nil) as? UIColor
                == .systemPink, "the newly typed keyword was not coloured")
    }

    @Test func theProseAroundTheBlockIsNeverTouched() {
        let (co, tv, _) = editor(source)
        let code = StructuredText.characterRange(ofLines: 2...2, in: source as NSString)!
        type("!", at: NSMaxRange(code), in: tv, co)
        let lines = tv.text.components(separatedBy: "\n")
        #expect(lines.first == "Notes")
        #expect(lines.last == "After")
    }

    @Test func editingOneBlockNeverTouchesAnother() {
        let two = "```python\na = 1\n```\nmiddle\n```sql\nSELECT 1\n```"
        let (co, tv, _) = editor(two)
        let first = StructuredText.characterRange(ofLines: 1...1, in: two as NSString)!
        type("2", at: NSMaxRange(first), in: tv, co)

        let blocks = CodeBlock.blocks(in: tv.text)
        #expect(blocks.count == 2)
        #expect(blocks[0].codeLines == ["a = 12"])
        #expect(blocks[1].codeLines == ["SELECT 1"], "the other block changed")
        #expect(blocks[1].language == "sql")
    }

    @Test func copyCodeAfterAnEditReturnsTheUpdatedCode() {
        let start = "```python\na = 1\n```"
        let (co, tv, _) = editor(start)
        let code = StructuredText.characterRange(ofLines: 1...1, in: start as NSString)!
        type("23", at: NSMaxRange(code), in: tv, co)

        let block = CodeBlock.blocks(in: tv.text).first!
        let layout = CodeCardLayout.layout(for: block, availableWidth: 320)!
        let card = CodeBlockView(block: block, layout: layout, palette: .ds, mode: .editing)
        card.copyCode()
        #expect(UIPasteboard.general.string == "a = 123")
        #expect(UIPasteboard.general.string?.contains(CodeBlock.fence) == false)
    }

    // MARK: The fences are not reachable

    @Test func theCaretIsMovedOffAFenceLine() {
        let (co, tv, _) = editor(source)
        for fence in [1, 4] {
            let range = StructuredText.characterRange(ofLines: fence...fence, in: source as NSString)!
            tv.selectedRange = NSRange(location: range.location + 2, length: 0)
            co.textViewDidChangeSelection(tv)
            let landed = StructuredText.lineIndex(of: tv.selectedRange.location, in: tv.text as NSString)
            #expect(landed != fence, "the caret stayed on fence line \(fence)")
        }
    }

    @Test func aCaretOnTheCodeIsLeftAlone() {
        let (co, tv, _) = editor(source)
        let code = StructuredText.characterRange(ofLines: 2...2, in: source as NSString)!
        for offset in code.location...NSMaxRange(code) {
            tv.selectedRange = NSRange(location: offset, length: 0)
            co.textViewDidChangeSelection(tv)
            #expect(tv.selectedRange.location == offset, "a caret at \(offset) was moved")
        }
    }

    @Test func anEmptyBlockDoesNotTrapTheCaret() {
        // Nothing inside to escape to, and its fences are still on screen — so it is left alone.
        #expect(CodeBlock.caretEscape(in: "```\n```", from: 0, movingForward: true) == nil)
    }

    // MARK: Undo, and coming back out

    @Test func typingInCodeUndoesAndRedoesWithoutTouchingTheFences() {
        // The block is edited as ordinary text, so it undoes as ordinary text — no separate code
        // document to keep a history of its own.
        let start = "```python\na = 1\n```"
        let harness = StructuredEditorUndoTests.Harness(start, caret: 15)   // end of "a = 1"
        harness.type("23")
        #expect(CodeBlock.blocks(in: harness.source).first?.codeLines == ["a = 123"])

        harness.undo()
        #expect(harness.source == start, "undo did not restore the note")
        #expect(CodeBlock.blocks(in: harness.source).first?.language == "python")

        harness.redo()
        #expect(CodeBlock.blocks(in: harness.source).first?.codeLines == ["a = 123"])
        #expect(harness.source.hasPrefix("```python\n"))
        #expect(harness.source.hasSuffix("\n```"))
    }

    @Test func aBlockGoesBackToItsRenderedCardWhenTheCaretLeaves() {
        let (co, tv, _) = editor(source)
        let presenter = CodeCardPresenter()

        // Caret in the code: the header only, and the block's lines keep their own heights.
        tv.selectedRange = StructuredText.characterRange(ofLines: 2...2, in: source as NSString)!
        let editing = presenter.plan(for: tv, sourceLines: StructuredText.lineIndices(
            touchedBy: tv.selectedRange, in: tv.text as NSString))
        #expect(editing.isEmpty, "an edited block reserved card height it does not need")

        // Caret back in the prose: the whole card again.
        tv.selectedRange = NSRange(location: 0, length: 0)
        co.textViewDidChangeSelection(tv)
        let reading = presenter.plan(for: tv, sourceLines: StructuredText.lineIndices(
            touchedBy: tv.selectedRange, in: tv.text as NSString))
        #expect(Array(reading.keys) == [1...4], "the block did not go back to a card")
        #expect((reading[1...4] ?? 0) > 0)
    }

    @Test func theFenceLinesCarryEverythingTheCardDrawsAroundItsCode() {
        // The header is positioned over the opening fence, so that line has to keep the height the
        // header needs — otherwise the label and Copy Code would overlap the first line of code.
        //
        // It keeps more than the header, though (amended 2026-08-28). A block occupies the same space
        // whichever presentation is on screen, so the two fences carry the air around the block and the
        // card's own padding as well: `blockMargin` above, then the header, then `cardInsetV` before the
        // code — and `cardInsetV` then `blockMargin` after it. Held at exactly `headerHeight`, the
        // editing presentation had no margin above it while the reading one did, and moving focus to
        // the title slid the whole block down the page.
        let storage = styled(source)
        let opening = lineRange(1, in: source)
        let paragraph = storage.attribute(.paragraphStyle, at: opening.location,
                                          effectiveRange: nil) as? NSParagraphStyle
        let top = CodeCardLayout.Metrics.blockMargin
            + CodeCardLayout.Metrics.headerHeight
            + CodeCardLayout.Metrics.cardInsetV
        #expect(paragraph?.minimumLineHeight == top)
        #expect(paragraph?.maximumLineHeight == top)

        let closing = lineRange(4, in: source)
        let bottom = storage.attribute(.paragraphStyle, at: closing.location,
                                       effectiveRange: nil) as? NSParagraphStyle
        #expect(bottom?.maximumLineHeight
                == CodeCardLayout.Metrics.cardInsetV + CodeCardLayout.Metrics.blockMargin)
    }

    @Test func theFencesSurviveEveryEditInThisSuite() {
        // The storage contract, asserted directly: `body` is still canonical fenced source.
        let start = "```python\na = 1\nb = 2\n```"
        let (co, tv, _) = editor(start)
        for offset in [10, 16, 20] { type("x", at: offset, in: tv, co) }
        let lines = tv.text.components(separatedBy: "\n")
        #expect(lines.first == "```python")
        #expect(lines.last == "```")
        #expect(CodeBlock.blocks(in: tv.text).count == 1)
    }
}
