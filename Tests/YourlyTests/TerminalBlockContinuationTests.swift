import Testing
import Foundation
import UIKit
import SwiftUI
@testable import Yourly

/// Writing on, after a note that ends inside a rendered block.
///
/// The defect these close (2026-08-28): a note whose last line was a closing fence had **no legal
/// caret position after it**. The fences are storage and `CodeBlock.caretEscape` refuses to leave a
/// caret on one — correctly, since the next keystroke would land inside ```` ```sql ```` and break the
/// block back into prose — and there was no line after the block to escape *to*. Every tap under the
/// card resolved to the end of the document, which is the closing fence, and was pushed straight back
/// inside the code. A writer who had just pasted a query could not write the sentence explaining it.
///
/// The fix is one newline, made on demand, through the ordinary undoable edit path. Nothing appends a
/// paragraph to a block in advance: a note that ends in a block is a good note until somebody asks to
/// write past it, and a blank line nobody typed would be in `body`, in Share, and in every copy of it.
@MainActor
struct TerminalBlockContinuationTests {

    private func page(_ text: String) -> (BodyTextView.Coordinator, StructuredTextView, UIWindow) {
        var body = text
        var range = NSRange(location: 0, length: 0)
        var focused = false
        let parent = BodyTextView(text: Binding(get: { body }, set: { body = $0 }),
                                  selectedRange: Binding(get: { range }, set: { range = $0 }),
                                  isFocused: Binding(get: { focused }, set: { focused = $0 }),
                                  isEditable: true, keyboardAppearance: .light)
        let co = parent.makeCoordinator()
        let tv = StructuredTextView.make()
        tv.delegate = co
        tv.font = StructuredTextStyle.bodyFont()
        tv.frame = CGRect(x: 0, y: 0, width: 361, height: 700)
        tv.textContainer.size = CGSize(width: 361, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        tv.text = text
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.addSubview(tv)
        window.makeKeyAndVisible()
        co.restyle(tv)
        return (co, tv, window)
    }

    /// A point `dy` below the bottom of the note's last line — i.e. under the rendered block.
    private func belowTheBlock(_ tv: StructuredTextView, dy: CGFloat = 6) -> CGPoint {
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        let ns = tv.text as NSString
        let last = StructuredText.lineIndex(of: ns.length, in: ns)
        let chars = StructuredText.characterRange(ofLines: last...last, in: ns)!
        let glyphs = tv.layoutManager.glyphRange(forCharacterRange: chars, actualCharacterRange: nil)
        var rect = CGRect.null
        tv.layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, _, _ in
            rect = rect.union(fragment)
        }
        return CGPoint(x: 40, y: rect.maxY + tv.textContainerInset.top + dy)
    }

    private let code = "Notes on the query.\n\n```sql\nSELECT 1;\nSELECT 2;\n```"
    private let preformatted = "The tree.\n\n```text\nroot/\n  a/\n  b/\n```"
    private let table = "Costs.\n\n| Item | Estimate |\n| --- | --- |\n| Hotel | $1,400 |"

    // MARK: A tap below a terminal block opens a paragraph after it

    @Test func aTapBelowATerminalCodeBlockOpensAParagraphAfterIt() {
        let (co, tv, _) = page(code)
        co.handleTap(in: tv, at: belowTheBlock(tv))

        #expect(tv.text == code + "\n")
        #expect(tv.selectedRange.location == (tv.text as NSString).length)
        // The caret is on a line of its own, past the block — not inside it.
        let line = StructuredText.lineIndex(of: tv.selectedRange.location, in: tv.text as NSString)
        #expect(CodeBlock.block(in: tv.text, atLine: line) == nil)
    }

    @Test func aTapBelowATerminalPreformattedBlockOpensAParagraphAfterIt() {
        let (co, tv, _) = page(preformatted)
        co.handleTap(in: tv, at: belowTheBlock(tv))

        #expect(tv.text == preformatted + "\n")
        let line = StructuredText.lineIndex(of: tv.selectedRange.location, in: tv.text as NSString)
        #expect(CodeBlock.block(in: tv.text, atLine: line) == nil)
        #expect(CodeBlock.blocks(in: tv.text).first?.isPreformatted == true)
    }

    /// A terminal table is the same dead end wearing different syntax: its last row is drawn as part
    /// of a card, so a tap under it landed in hidden source and the next keystroke went into a cell.
    @Test func aTapBelowATerminalTableOpensAParagraphAfterIt() {
        let (co, tv, _) = page(table)
        co.handleTap(in: tv, at: belowTheBlock(tv))

        #expect(tv.text == table + "\n")
        let line = StructuredText.lineIndex(of: tv.selectedRange.location, in: tv.text as NSString)
        #expect(TableBlock.tables(in: tv.text).allSatisfy { !$0.lineRange.contains(line) })
        #expect(TableBlock.tables(in: tv.text).first?.rows.count == 2)
    }

    // MARK: What must not change

    @Test func theBlockIsStillARenderedBlockAfterwards() {
        let (co, tv, _) = page(code)
        let before = CodeBlock.blocks(in: tv.text)
        co.handleTap(in: tv, at: belowTheBlock(tv))

        #expect(CodeBlock.blocks(in: tv.text) == before, "the block's shape changed")
        // Both fences are still storage the reader never sees.
        for fence in [2, 5] {
            let range = StructuredText.characterRange(ofLines: fence...fence, in: tv.text as NSString)!
            for offset in range.location..<NSMaxRange(range) {
                #expect(tv.textStorage.attribute(.astHiddenMarker, at: offset,
                                                 effectiveRange: nil) as? Bool == true,
                        "fence character \(offset) became visible")
            }
        }
        #expect(tv.subviews.contains { $0 is CodeBlockView }, "the card de-rendered")
    }

    @Test func theWriterCanTypeOrdinaryProseThere() {
        let (co, tv, _) = page(code)
        co.handleTap(in: tv, at: belowTheBlock(tv))

        let caret = tv.selectedRange
        if co.textView(tv, shouldChangeTextIn: caret, replacementText: "This returns two rows.") {
            tv.textStorage.replaceCharacters(in: caret, with: "This returns two rows.")
            co.textViewDidChange(tv)
        }
        #expect(tv.text == code + "\nThis returns two rows.")
        #expect(CodeBlock.blocks(in: tv.text).first?.codeLines == ["SELECT 1;", "SELECT 2;"],
                "the prose reached the code")
    }

    @Test func oneUndoPutsTheNoteBack() {
        let (co, tv, _) = page(code)
        co.handleTap(in: tv, at: belowTheBlock(tv))
        #expect(tv.text == code + "\n")

        tv.undoManager?.undo()
        #expect(tv.text == code, "one undo did not return the note to how it was")
    }

    @Test func aTapBelowANoteThatDoesNotEndInABlockChangesNothing() {
        let text = code + "\n\nAnd a closing paragraph."
        let (co, tv, _) = page(text)
        co.handleTap(in: tv, at: belowTheBlock(tv))
        #expect(tv.text == text, "a paragraph was appended to a note that did not need one")
    }

    @Test func aTapOnTheBlockItselfChangesNothing() {
        let (co, tv, _) = page(code)
        // Well inside the card rather than under it.
        co.handleTap(in: tv, at: CGPoint(x: 40, y: belowTheBlock(tv, dy: 0).y - 30))
        #expect(tv.text == code)
    }

    @Test func nothingIsAppendedUntilSomebodyAsks() {
        let (co, tv, _) = page(code)
        co.restyle(tv)
        co.restyle(tv)
        #expect(tv.text == code, "rendering a terminal block changed the note")
    }

    // MARK: The rule itself

    @Test func aNoteThatAlreadyHasARoomAfterTheBlockIsLeftAlone() {
        #expect(DocumentAction.continuePastTerminalBlockEdit(text: code + "\n") == nil)
        #expect(DocumentAction.continuePastTerminalBlockEdit(text: code + "\nProse.") == nil)
        #expect(DocumentAction.continuePastTerminalBlockEdit(text: "Just prose.") == nil)
        #expect(DocumentAction.continuePastTerminalBlockEdit(text: "") == nil)
        // An unterminated fence is ordinary text, so there is nothing to write past.
        #expect(DocumentAction.continuePastTerminalBlockEdit(text: "```sql\nSELECT 1;") == nil)
    }

    @Test func theEditIsOneNewlineAtTheVeryEnd() {
        let edit = DocumentAction.continuePastTerminalBlockEdit(text: code)
        #expect(edit?.string == "\n")
        #expect(edit?.range == NSRange(location: (code as NSString).length, length: 0))
        #expect(edit?.selection == NSRange(location: (code as NSString).length + 1, length: 0))
    }
}
