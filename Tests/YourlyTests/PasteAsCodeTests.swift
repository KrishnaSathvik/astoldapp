import Testing
import Foundation
@testable import Yourly

// **Paste as Code** — the explicit half of "never guess that something is code".
//
// A "Copy code" button in a chat app or a docs site often puts nothing but plain text on the
// pasteboard: no `<pre>`, no `language-…`, no fences. The code-ness was discarded before As Told saw
// it, so there is nothing to preserve and the importer is right to leave the text alone. What was
// missing is a way for the person who knows to say so — one verb in the menu they already open
// (RULES.md §7, amended 2026-08-24).

struct PasteAsCodeTests {

    private let clipboard = "SELECT *\nFROM users;"

    private func applied(_ pasted: String, to text: String, at selection: NSRange) -> String? {
        DocumentAction.pasteAsCodeEdit(pasted, text: text, selection: selection)?
            .applied(to: text).text
    }

    @Test func plainTextBecomesAFencedBlock() {
        // The trailing newline is the block's closing line boundary, not a character of the paste: a
        // block that ends the note leaves the caret nowhere outside itself to go, and a caret in the
        // fence puts the card straight back into source. See `theCaretEndsOutsideTheBlock`.
        let out = applied(clipboard, to: "", at: NSRange(location: 0, length: 0))
        #expect(out == "```\nSELECT *\nFROM users;\n```\n")
    }

    @Test func whatLandsIsACodeBlockTheCardCanDraw() {
        let out = applied(clipboard, to: "", at: NSRange(location: 0, length: 0)) ?? ""
        let block = CodeBlock.blocks(in: out).first
        #expect(block?.codeLines == ["SELECT *", "FROM users;"])
        #expect(block?.language == nil)
    }

    @Test func noLanguageIsInvented() {
        // This *is* SQL and the clipboard did not say so. Reading `SELECT` and writing ```` ```sql ````
        // is the guess this entire path exists to avoid — so: no language, no label, no colour.
        let out = applied(clipboard, to: "", at: NSRange(location: 0, length: 0)) ?? ""
        #expect(!out.contains("```sql"))
        #expect(CodeHighlighting.language(named: CodeBlock.blocks(in: out).first?.language ?? nil) == nil)
    }

    @Test func everyCharacterOfTheClipboardSurvives() {
        // Indentation, blank lines, and trailing spaces are the code. Nothing is trimmed, reflowed, or
        // corrected — the fences are the only characters this adds.
        let messy = "def f():\n    if x:\n\n        return 1\t"
        let out = applied(messy, to: "", at: NSRange(location: 0, length: 0)) ?? ""
        #expect(CodeBlock.blocks(in: out).first?.code == messy)
    }

    @Test func aFenceOpensItsOwnLineWhenTheCaretIsMidLine() {
        // A fence that starts mid-sentence is not a fence, and the words before it would be swallowed.
        let out = applied(clipboard, to: "Notes so far", at: NSRange(location: 12, length: 0)) ?? ""
        #expect(out.hasPrefix("Notes so far\n```\n"))
        #expect(CodeBlock.blocks(in: out).first?.codeLines == ["SELECT *", "FROM users;"])
    }

    @Test func theLineAfterTheBlockStaysALine() {
        let out = applied(clipboard, to: "before\nafter", at: NSRange(location: 6, length: 0)) ?? ""
        #expect(out.contains("```\nafter"))
        #expect(CodeBlock.blocks(in: out).count == 1)
    }

    @Test func anAlreadyFencedClipboardIsNotFencedTwice() {
        // A clipboard that *did* state its structure keeps it. Wrapping it again would put a fence
        // inside a fence, where the inner one closes the outer and the block breaks in half.
        let fenced = "```sql\nSELECT 1\n```"
        let out = applied(fenced, to: "", at: NSRange(location: 0, length: 0)) ?? ""
        #expect(CodeBlock.blocks(in: out).count == 1)
        #expect(CodeBlock.blocks(in: out).first?.language == "sql")
        #expect(CodeBlock.blocks(in: out).first?.codeLines == ["SELECT 1"])
    }

    @Test func aStrayFenceIsNotMistakenForAFencedBlock() {
        // "Already fenced" must mean *one complete block*, not "contains three backticks somewhere".
        // Prose with a fence in the middle of it is not a code block, and treating it as one would let
        // arbitrary text bypass wrapping.
        let notABlock = "intro\n```\nSELECT 1\n```"
        #expect(CodeBlock.blocks(in: notABlock).first?.lineRange != 0...3)
    }

    @Test func textCarryingAFenceLineIsInsertedVerbatimRatherThanWrapped() {
        // …and it is not wrapped either, which is the hazard on the other side: a fence placed around
        // text containing a fence is closed by *that* line, so the block would break in half and the
        // tail would fall out as loose text. Every character still lands in `body` exactly as copied.
        let strays = ["SELECT 1\n```", "intro\n```\nSELECT 1\n```"]
        for clipboard in strays {
            let out = applied(clipboard, to: "", at: NSRange(location: 0, length: 0)) ?? ""
            // Every character as copied, plus the closing line boundary every insert gets.
            #expect(out == clipboard + "\n", "\(clipboard) was rewritten")
        }
    }

    @Test func anEmptyClipboardDoesNothing() {
        #expect(DocumentAction.pasteAsCodeEdit("", text: "note", selection: NSRange(location: 0, length: 0)) == nil)
    }

    @Test func aSelectionIsReplacedByTheBlock() {
        let out = applied(clipboard, to: "replace me", at: NSRange(location: 0, length: 10)) ?? ""
        #expect(!out.contains("replace me"))
        #expect(CodeBlock.blocks(in: out).first?.codeLines == ["SELECT *", "FROM users;"])
    }

    @Test func theCaretEndsOutsideTheBlock() {
        // Landing inside the fence would put the card straight back into its source, so the writer
        // would never see the thing they just asked for.
        let edit = DocumentAction.pasteAsCodeEdit(clipboard, text: "", selection: NSRange(location: 0, length: 0))
        let result = edit?.applied(to: "")
        let caretLine = StructuredText.lineIndex(of: result?.selection.location ?? 0,
                                                 in: (result?.text ?? "") as NSString)
        let block = CodeBlock.blocks(in: result?.text ?? "").first
        #expect(block?.lineRange.contains(caretLine) == false)
    }

    @Test func ordinaryPasteIsUnchangedByAnyOfThis() {
        // The same clipboard through the normal path stays prose: nothing declared it to be code, and
        // normal Paste is exactly what it was.
        let normal = DocumentAction.pasteEdit(clipboard, text: "", selection: NSRange(location: 0, length: 0))
        #expect(normal.applied(to: "").text == clipboard)
        #expect(CodeBlock.blocks(in: clipboard).isEmpty)
    }
}

/// The middle row of the model: plain text that carries its *own* fences.
///
/// `body` **is** the source, so a plain-text paste of fenced characters needs no importer at all — the
/// characters land in `body` and `CodeBlock` reads them back. This is asserted rather than assumed,
/// because "it should already work" is how a gap survives a review.
struct FencedPlainTextPasteTests {

    @Test func fencedClipboardTextRendersWithoutTheImporter() {
        let clipboard = "```sql\nSELECT managerId\nFROM Employee\n```"
        // Nothing on the pasteboard states structure, so the importer declines and the system's own
        // plain-text paste puts these characters in `body` verbatim.
        #expect(RichPasteHTML.source(from: clipboard) == nil)

        let body = DocumentAction.pasteEdit(clipboard, text: "", selection: NSRange(location: 0, length: 0))
            .applied(to: "").text
        #expect(body == clipboard)

        let block = CodeBlock.blocks(in: body).first
        #expect(block?.language == "sql")
        #expect(block?.codeLines == ["SELECT managerId", "FROM Employee"])
        #expect(CodeHighlighting.language(named: block?.language)?.displayName == "SQL")
    }

    @Test func andItsLinesAreLiteral() {
        // The fence switches marker parsing off, so a `#` inside it is a comment in someone's shell
        // script rather than a heading in their note.
        let body = "```bash\n# not a heading\necho hi\n```"
        #expect(MarkupDocument(body).lines.allSatisfy { $0.kind == .paragraph })
    }
}
