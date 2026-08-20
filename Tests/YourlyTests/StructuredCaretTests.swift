import Foundation
import Testing
import UIKit
import SwiftUI
@testable import Yourly

// Where the caret is *drawn* after leaving a list.
//
// These assert pixels, not characters, and that is the point. `DocumentAction.returnEdit` had always
// produced the right document — the marker removed, the line a paragraph — while the caret stayed
// sitting at the list indent until the writer typed a character, at which point it jumped left. The
// document layer could not see it: every text assertion passed.
//
// The cause was that an empty last line has no characters of its own, so nothing in the text storage
// describes it; TextKit lays that final fragment out from the text view's `typingAttributes`, which
// still described the bullet the writer had just left. So these tests drive the **real** coordinator,
// not a re-implementation of it, and then measure `caretRect`.

@MainActor
private enum Caret {
    /// A text view wired to the real `BodyTextView.Coordinator`, holding `source` with the caret at
    /// `caret`, laid out and ready to measure.
    static func editor(_ source: String, caret: Int) -> (UITextView, BodyTextView.Coordinator) {
        let parent = BodyTextView(text: .constant(source),
                                  selectedRange: .constant(NSRange(location: caret, length: 0)),
                                  isFocused: .constant(false),
                                  isEditable: true,
                                  keyboardAppearance: .light)
        let coordinator = BodyTextView.Coordinator(parent)
        let tv = StructuredTextView.make()
        tv.delegate = coordinator
        tv.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        tv.font = StructuredTextStyle.bodyFont()
        tv.text = source
        tv.selectedRange = NSRange(location: caret, length: 0)
        coordinator.restyle(tv)
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        return (tv, coordinator)
    }

    static func rect(_ tv: UITextView) -> CGRect {
        let position = tv.position(from: tv.beginningOfDocument, offset: tv.selectedRange.location)!
        return tv.caretRect(for: position)
    }

    /// Where the caret sits on an ordinary empty paragraph — the inset every exit must land on.
    static var paragraphX: CGFloat {
        let (tv, _) = editor("One\n", caret: 4)
        return rect(tv).minX
    }

    /// Whether the caret is drawn in the list gutter. Compared against the indent itself rather than
    /// against another measured caret: UIKit draws a caret one point back from the character it
    /// precedes but flush at the end of the document, and that one point is not what these tests are
    /// about. The bug moved the caret by the full 28-point gutter.
    static func isInListGutter(_ tv: UITextView) -> Bool {
        abs(rect(tv).minX - StructuredTextStyle.listIndent) <= 1
    }

    /// Applies an edit exactly as the editor does, then relays out.
    static func apply(_ edit: TextEdit, _ tv: UITextView, _ coordinator: BodyTextView.Coordinator) {
        _ = coordinator.apply(edit, to: tv)
        tv.layoutManager.ensureLayout(for: tv.textContainer)
    }
}

@MainActor
struct StructuredCaretTests {

    /// Every list kind, every empty item: Return leaves the caret at the paragraph inset immediately,
    /// with no character typed. This is the bug, stated three times because it has to hold three times.
    @Test(arguments: ["- One\n- ", "1. One\n2. ", "- [ ] One\n- [ ] "])
    func returnOnAnEmptyItemMovesTheCaretOutOfTheGutter(source: String) {
        let end = (source as NSString).length
        let (tv, coordinator) = Caret.editor(source, caret: end)
        #expect(Caret.isInListGutter(tv), "the caret should start out inside the list")

        let edit = DocumentAction.returnEdit(text: tv.text, selection: NSRange(location: end, length: 0))
        #expect(edit != nil, "Return on an empty item must be handled, not left to the text view")
        Caret.apply(edit!, tv, coordinator)

        #expect(Caret.rect(tv).minX == Caret.paragraphX,
                "the caret is still drawn in the list gutter after leaving the list")
    }

    /// The explicit way out has to arrive at the same place as the fast one: Style → Paragraph on an
    /// empty item leaves the caret exactly where Return on an empty item does.
    @Test(arguments: ["- One\n- ", "1. One\n2. ", "- [ ] One\n- [ ] "])
    func styleParagraphMovesTheCaretOutOfTheGutter(source: String) {
        let end = (source as NSString).length
        let (tv, coordinator) = Caret.editor(source, caret: end)

        let edit = DocumentAction.setBlockKindEdit(BlockStyle.paragraph.kind, text: tv.text,
                                                   selection: NSRange(location: end, length: 0))
        Caret.apply(edit, tv, coordinator)

        #expect(tv.text == (source as NSString).substring(to: (source as NSString).range(of: "\n").location + 1))
        #expect(Caret.rect(tv).minX == Caret.paragraphX)
    }

    /// And so does Backspace at the start of the item, which demotes it the same way.
    @Test(arguments: ["- One\n- ", "1. One\n2. ", "- [ ] One\n- [ ] "])
    func backspaceOutOfAnEmptyItemMovesTheCaretOutOfTheGutter(source: String) {
        let end = (source as NSString).length
        let (tv, coordinator) = Caret.editor(source, caret: end)

        let edit = DocumentAction.backspaceEdit(text: tv.text, selection: NSRange(location: end, length: 0))
        #expect(edit != nil)
        Caret.apply(edit!, tv, coordinator)

        #expect(Caret.rect(tv).minX == Caret.paragraphX)
    }

    /// Not only after an edit. A note that was *saved* ending in a list, then reopened with the caret
    /// on the empty line below it, is the same empty-last-line with no attributes of its own.
    @Test(arguments: ["- One\n", "1. One\n", "- [ ] One\n"])
    func openingANoteThatEndsBelowAListPutsTheCaretAtTheParagraphInset(source: String) {
        let (tv, _) = Caret.editor(source, caret: (source as NSString).length)
        #expect(Caret.rect(tv).minX == Caret.paragraphX)
    }

    /// The correction must not overshoot: a caret that is still *in* a list belongs in the gutter, and
    /// an empty item the writer has not left yet is still an item.
    @Test(arguments: ["- One\n- ", "1. One\n2. ", "- [ ] One\n- [ ] "])
    func aCaretStillInsideAnEmptyItemStaysIndented(source: String) {
        let (tv, _) = Caret.editor(source, caret: (source as NSString).length)
        #expect(Caret.isInListGutter(tv))
        #expect(StructuredTextStyle.listIndent > Caret.paragraphX,
                "a list item is indented; the fixture is wrong if not")
    }

    /// Height, not just position: the empty line after a heading is a paragraph, so the caret is body
    /// height. A caret drawn at heading height announces a heading the writer is not in.
    @Test func theCaretBelowAHeadingIsBodyHeight() {
        let (heading, _) = Caret.editor("# Title\n", caret: 8)
        let (plain, _) = Caret.editor("Title\n", caret: 6)
        #expect(Caret.rect(heading).height == Caret.rect(plain).height)
    }
}
