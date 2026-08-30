import Testing
import Foundation
@testable import Yourly

// **Paste as Preformatted** — the second explicit verb, and the same argument as the first.
//
// A "Copy" button on a chat answer frequently puts nothing but `public.utf8-plain-text` on the
// pasteboard. When what was copied is an architecture diagram, its alignment is the entire content and
// there is nothing in the clipboard that says so. As Told will not read four lines of text and decide
// they are a diagram — that is the guess this app exists not to make (RULES.md §4). So the person who
// knows says so, in the menu they already opened to paste (added 2026-08-25).
//
// Deliberately *not* built: any inference. `CodeDetection` was a single narrow amendment for code the
// detector is certain about; ASCII art has no equivalent bar, and a note rewritten into a diagram
// nobody asked for is the failure mode this whole design avoids.
struct PasteAsPreformattedTests {

    private let diagram = "DOL / USCIS\n    │\n    ▼\nAirflow"

    private func applied(_ pasted: String, to text: String = "",
                         at selection: NSRange = NSRange(location: 0, length: 0)) -> String? {
        DocumentAction.pasteAsPreformattedEdit(pasted, text: text, selection: selection)?
            .applied(to: text).text
    }

    @Test func plainTextBecomesAPlainTextBlock() {
        // The trailing newline is the block's closing line boundary, exactly as **Paste as Code**
        // writes one: a caret left in the fence would put the card straight back into source.
        #expect(applied(diagram) == "```text\nDOL / USCIS\n    │\n    ▼\nAirflow\n```\n")
    }

    @Test func whatLandsIsAPreformattedBlockTheCardCanDraw() {
        let block = CodeBlock.blocks(in: applied(diagram) ?? "").first
        #expect(block?.kind == .preformatted)
        #expect(block?.cardLabel == "Plain text")
        #expect(block?.codeLines == ["DOL / USCIS", "    │", "    ▼", "Airflow"])
    }

    @Test func everyCharacterOfTheClipboardSurvives() {
        let awkward = "  two spaces\n\tone tab\n\n│├└─┌┐▼▲→←\ttrailing\t"
        let block = CodeBlock.blocks(in: applied(awkward) ?? "").first
        #expect(block?.codeLines == ["  two spaces", "\tone tab", "", "│├└─┌┐▼▲→←\ttrailing\t"])
    }

    @Test func nothingInsideItIsReadAsStructure() {
        let markers = "# Historical evidence\n ┌──────┼──────┐\n | a | b |\n - [ ] x"
        let out = applied(markers) ?? ""
        let doc = MarkupDocument(out)
        #expect(doc.lines.allSatisfy { $0.kind == .paragraph })
        #expect(TableBlock.tables(in: out).isEmpty)
    }

    @Test func aClipboardThatIsAlreadyOneTextBlockIsNotFencedTwice() {
        let out = applied("```text\nA\n│\nB\n```") ?? ""
        #expect(CodeBlock.blocks(in: out).count == 1)
        #expect(CodeBlock.blocks(in: out).first?.codeLines == ["A", "│", "B"])
    }

    @Test func aStrayFenceIsInsertedAsItStandsRatherThanBreakingInHalf() {
        // Same answer **Paste as Code** gives, and for the storage format's reason: a fence wrapped
        // around text containing one is closed by *that* line instead of its own.
        let out = applied("before\n```\nafter") ?? ""
        #expect(out.hasPrefix("before\n```\nafter"))
    }

    @Test func anEmptyClipboardDoesNothing() {
        #expect(DocumentAction.pasteAsPreformattedEdit("", text: "Note",
                                                       selection: NSRange(location: 0, length: 0)) == nil)
    }

    @Test func aBlockPastedMidLineStartsItsOwnLine() {
        // A fence has to begin a line or it is not a fence.
        let out = applied(diagram, to: "See this:", at: NSRange(location: 9, length: 0)) ?? ""
        #expect(out == "See this:\n```text\nDOL / USCIS\n    │\n    ▼\nAirflow\n```\n")
    }

    @Test func theCaretEndsOutsideTheBlock() {
        let edit = DocumentAction.pasteAsPreformattedEdit(diagram, text: "",
                                                          selection: NSRange(location: 0, length: 0))
        let out = edit?.applied(to: "")
        let caretLine = StructuredText.lineIndex(of: out?.selection.location ?? 0,
                                                 in: (out?.text ?? "") as NSString)
        #expect(CodeBlock.block(in: out?.text ?? "", atLine: caretLine) == nil)
    }

    @Test func pasteAsCodeStillWritesNoLanguage() {
        // The two verbs stay distinct: one states plain text, the other states nothing at all.
        let out = DocumentAction.pasteAsCodeEdit(diagram, text: "",
                                                 selection: NSRange(location: 0, length: 0))?
            .applied(to: "").text
        #expect(CodeBlock.blocks(in: out ?? "").first?.language == nil)
        #expect(CodeBlock.blocks(in: out ?? "").first?.kind == .code)
    }
}
