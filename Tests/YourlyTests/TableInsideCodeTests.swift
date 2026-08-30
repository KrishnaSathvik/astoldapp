import Testing
import Foundation
import UIKit
@testable import Yourly

/// Where the two block structures meet: pipes inside a code fence.
///
/// A fence says one thing — these characters are literal — and it has to say it to every reader in the
/// app, not only to the marker parser. `MarkupDocument` has always honoured it; table detection did
/// not, so a snippet holding a Markdown table, a `column | value` log, or an ASCII box was read as a
/// grid *inside* the code block. That is not a cosmetic mistake: the delimiter row was hidden on the
/// page while its author was editing it, a table card was drawn over the code card, and a copy of the
/// note carried two of the block's lines out and left the rest behind (RULES.md §5, §7).
@MainActor
struct TableInsideCodeTests {

    /// A code block whose contents are, character for character, a Markdown table.
    private let source = "```\n| a | b |\n| --- | --- |\n| 1 | 2 |\n```"

    @Test func pipesInsideAFenceAreNotATable() {
        #expect(TableBlock.tables(in: source).isEmpty)
        #expect(CodeBlock.blocks(in: source).first?.lineRange == 0...4)
    }

    @Test func everyLineOfTheBlockIsStillLiteral() {
        #expect(MarkupDocument(source).lines.allSatisfy { $0.isLiteral })
    }

    @Test func nothingOfTheCodeIsHiddenWhileItIsBeingEdited() {
        // The delimiter row is hidden in a *table*. Inside a fence it is a line of somebody's code,
        // and a writer editing it must be able to see every character of it.
        //
        // The block's own fence lines are hidden — that is the 2026-08-24 presentation and is not what
        // this test is about — so the assertion is scoped to the code between them.
        let storage = NSTextStorage(string: source)
        StructuredTextStyler.apply(to: storage, textColor: .label)
        let code = StructuredText.characterRange(ofLines: 1...3, in: source as NSString)!
        for offset in code.location..<NSMaxRange(code) {
            #expect(storage.attribute(.astHiddenMarker, at: offset, effectiveRange: nil) == nil,
                    "character \(offset) of the code was hidden")
        }
        #expect(storage.attribute(.astTableBlock, at: 4, effectiveRange: nil) == nil)
    }

    @Test func onlyOneCardIsDrawnOverIt() {
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 360, height: 800)
        tv.textContainer.size = CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
        tv.text = source

        #expect(TableCardPresenter().plan(for: tv, sourceLines: nil).isEmpty)
        #expect(Array(CodeCardPresenter().plan(for: tv, sourceLines: nil).keys) == [0...4])
    }

    @Test func aCopyCarriesEveryLineOfTheCode() {
        // The failure this pins lost two rows of a three-row block on the way to the pasteboard.
        let out = StructuredTextExport.plainText(source)
        for line in ["| a | b |", "| --- | --- |", "| 1 | 2 |"] {
            #expect(out.contains(line), "the copy lost \(line)")
        }
        #expect(!out.contains(CodeBlock.fence))     // the fences are storage, not content
    }

    @Test func aRealTableOutsideTheFenceStillReads() {
        // The guard is scoped to fenced lines and nothing else.
        let mixed = "| x | y |\n| --- | --- |\n| 1 | 2 |\n```\n| a | b |\n| --- | --- |\n```"
        #expect(TableBlock.tables(in: mixed).map(\.lineRange) == [0...2])
        #expect(CodeBlock.blocks(in: mixed).map(\.lineRange) == [3...6])
    }

    @Test func anUnterminatedFenceLeavesTheTableAlone() {
        // A lone ``` is ordinary text, so it hides nothing — the table under it is still a table.
        let stray = "```\n| a | b |\n| --- | --- |"
        #expect(CodeBlock.blocks(in: stray).isEmpty)
        #expect(TableBlock.tables(in: stray).map(\.lineRange) == [1...2])
    }
}
