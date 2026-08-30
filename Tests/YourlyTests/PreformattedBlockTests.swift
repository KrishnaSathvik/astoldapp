import Testing
import Foundation
@testable import Yourly

// A **preformatted block** — an ASCII diagram, a directory tree, a column of aligned plain text.
//
// It is not a new structure in `body` and not a second parser. It is the fenced block As Told already
// holds, whose opening fence declared `text`:
//
//   ```text
//   sponsor-intelligence/
//   ├── apps/
//   ```
//
// The distinction matters for exactly two things — the card says **Plain text** instead of a language
// name, and no syntax colour is applied — and for nothing else. Everything that makes a fence a fence
// is unchanged, which is the point: a diagram containing `#`, `- `, `| … |` and `[x](y)` must be as
// literal as a line of Python, and it already is (RULES.md §7, code-blocks exception).
struct PreformattedBlockTests {

    private let tree = """
    ```text
    sponsor-intelligence/
    │
    ├── apps/
    │   ├── web/
    │   └── api/
    ```
    """

    // MARK: What a fence declares

    @Test func aTextFenceIsPreformatted() {
        #expect(CodeBlock.blocks(in: tree).first?.kind == .preformatted)
    }

    @Test func theSpellingsOfPlainTextAllCount() {
        for declared in ["text", "plaintext", "txt", "TEXT", " Text "] {
            let source = "```\(declared)\nA\n```"
            #expect(CodeBlock.blocks(in: source).first?.kind == .preformatted,
                    "`\(declared)` should declare preformatted text")
        }
    }

    @Test func aLanguageFenceIsStillCode() {
        for declared in ["python", "sql", "swift", "rust"] {
            let source = "```\(declared)\nA\n```"
            #expect(CodeBlock.blocks(in: source).first?.kind == .code,
                    "`\(declared)` should stay code")
        }
    }

    @Test func aBareFenceStaysGenericCode() {
        // **Paste as Code** writes exactly this and states no language. Reading a bare fence as
        // preformatted would relabel every block that path has ever produced.
        #expect(CodeBlock.blocks(in: "```\nA\n```").first?.kind == .code)
    }

    // MARK: The label

    @Test func aPreformattedBlockSaysPlainText() {
        // Not `text` — the fence's spelling is storage. "Plain text" is what the reader is looking at.
        #expect(CodeBlock.blocks(in: tree).first?.cardLabel == "Plain text")
    }

    @Test func aCodeBlockStillSaysItsLanguage() {
        #expect(CodeBlock.blocks(in: "```sql\nSELECT 1\n```").first?.cardLabel == "SQL")
        #expect(CodeBlock.blocks(in: "```\nA\n```").first?.cardLabel == nil)
    }

    @Test func plainTextIsNeverSyntaxColoured() {
        // Falls out of the closed list rather than being special-cased anywhere: `text` is not a
        // language `CodeHighlighting` knows, so there is nothing for it to colour.
        #expect(CodeHighlighting.language(named: "text") == nil)
        #expect(CodeHighlighting.language(named: "plaintext") == nil)
        #expect(CodeHighlighting.language(named: "txt") == nil)
    }

    // MARK: Writing one

    @Test func asToldWritesTheCanonicalSpelling() {
        // Three spellings are read; one is written. A note As Told produced never says `txt`.
        let source = CodeBlock.preformattedSource(text: "A\n│\nB")
        #expect(source == "```text\nA\n│\nB\n```")
    }

    // MARK: What the characters mean — which is nothing

    @Test func everyMarkerInsideADiagramStaysLiteral() {
        // The reason this feature is a fence and not a new block kind. An architecture diagram is made
        // of exactly the characters As Told reads as structure.
        let diagram = """
        ```text
        # Historical evidence
        - not a bullet
        1. not a number
        - [ ] not a checkbox
        | Company | Role |
        [text](https://example.com)
        ```
        """
        let doc = MarkupDocument(diagram)
        for index in 1...6 {
            #expect(doc.lines[index].isLiteral, "line \(index) of a diagram must be literal")
            #expect(doc.lines[index].kind == .paragraph, "line \(index) must claim no block kind")
        }
        #expect(doc.lines[6].links.isEmpty)
    }

    @Test func pipesInsideADiagramAreNeverATable() {
        let source = """
        ```text
        | Company | Role |
        | --- | --- |
        | Acme | SDE |
        ```
        """
        #expect(TableBlock.tables(in: source).isEmpty)
    }

    @Test func theTreeCharactersSurviveExactly() {
        let block = CodeBlock.blocks(in: tree).first
        #expect(block?.codeLines == ["sponsor-intelligence/",
                                     "│",
                                     "├── apps/",
                                     "│   ├── web/",
                                     "│   └── api/"])
    }

    @Test func anUnterminatedTextFenceIsOrdinaryText() {
        #expect(CodeBlock.blocks(in: "```text\nA\n│\nB").isEmpty)
    }
}
