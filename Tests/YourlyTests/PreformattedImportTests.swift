import Testing
import Foundation
@testable import Yourly

// Where a preformatted block comes from: a source that **stated** its characters are literal.
//
// The rule the importer has always followed is unchanged — preserve declared structure, never guess it
// (RULES.md §4). What is new is that HTML has two different ways of declaring literalness and they mean
// two different things:
//
//   <pre>…</pre>                             — "these characters are preformatted"  → Plain text
//   <pre><code class="language-python">…     — "these characters are Python"        → code, coloured
//   <pre><code>…</code></pre>                — "these characters are code"          → code, unlabelled
//
// Nothing here reads the characters to decide. `<pre>` alone is HTML's own word for preformatted text,
// and `<code>` is HTML's own word for code; As Told is translating a claim, not making one.
struct PreformattedImportTests {

    private func source(html: String) -> String? {
        RichPasteDocument.canonicalSource(RichPasteHTML.document(from: html))
    }

    private func block(html: String) -> CodeBlock? {
        CodeBlock.blocks(in: source(html: html) ?? "").first
    }

    // MARK: HTML

    @Test func aBarePreIsPreformatted() {
        // `<pre>` says preformatted and says nothing about code. Before 2026-08-25 this produced an
        // unlabelled code block, which rendered the same but called a diagram a program.
        #expect(block(html: "<pre>A\n│\n▼\nB</pre>")?.kind == .preformatted)
        #expect(source(html: "<pre>A\n│\n▼\nB</pre>") == "```text\nA\n│\n▼\nB\n```")
    }

    @Test func aPreWhoseCodeNamesPlainTextIsPreformatted() {
        #expect(block(html: "<pre><code class=\"language-text\">A\n│\nB</code></pre>")?.kind == .preformatted)
        #expect(block(html: "<pre><code class=\"language-plaintext\">A</code></pre>")?.kind == .preformatted)
    }

    @Test func aPreWhoseCodeNamesALanguageIsStillCode() {
        let python = block(html: "<pre><code class=\"language-python\">x = 1</code></pre>")
        #expect(python?.kind == .code)
        #expect(python?.language == "python")
    }

    @Test func aPreWithAnUnlabelledCodeIsStillCode() {
        // `<code>` is an explicit claim that these characters are code, even with no language on it.
        // Reading it as plain text would throw away the one thing the source did say.
        let block = block(html: "<pre><code>x = 1</code></pre>")
        #expect(block?.kind == .code)
        #expect(block?.language == nil)
    }

    // MARK: The shapes a real clipboard arrives in

    @Test func aDiagramWrappedOneDivPerLineKeepsItsSpacingExactly() {
        // The shape every syntax highlighter and most chat apps put on the pasteboard.
        let html = """
        <pre>\
        <div>DOL / USCIS</div>\
        <div>    │</div>\
        <div>    ▼</div>\
        <div>Airflow detects new release</div>\
        </pre>
        """
        let block = block(html: html)
        #expect(block?.kind == .preformatted)
        #expect(block?.codeLines == ["DOL / USCIS", "    │", "    ▼", "Airflow detects new release"])
    }

    @Test func aTreeWrappedInSpansKeepsEveryBoxCharacter() {
        let html = """
        <pre>\
        <span>sponsor-intelligence/</span>\n\
        <span>├── apps/</span>\n\
        <span>│   └── api/</span>\
        </pre>
        """
        #expect(block(html: html)?.codeLines == ["sponsor-intelligence/", "├── apps/", "│   └── api/"])
    }

    @Test func theGapBetweenTwoBranchesOfATreeSurvives() {
        // The blank-line rule is the one `<pre>` already had and is not preformatted's to change: two
        // explicit breaks are a gap the author left, two element boundaries are one line ending and the
        // next beginning (`RichPasteLinkCodeTests.aBlankLineInsideCodeSurvives`). A diagram needs the
        // gap for exactly the reason a script does.
        let html = "<pre><div>├── apps/</div><div><br><br></div><div>└── packages/</div></pre>"
        #expect(block(html: html)?.codeLines == ["├── apps/", "", "└── packages/"])
    }

    // MARK: Markdown

    @Test func aDeclaredTextFenceIsPreformatted() {
        let out = RichPasteDocument.canonicalSource(
            RichPasteMarkdown.document(from: "```text\nA\n│\nB\n```"))
        #expect(CodeBlock.blocks(in: out ?? "").first?.kind == .preformatted)
    }

    @Test func theOtherSpellingsAreNormalisedOnTheWayIn() {
        // Read `plaintext`, write `text`: one shape in `body` for one thing.
        for declared in ["plaintext", "txt"] {
            let out = RichPasteDocument.canonicalSource(
                RichPasteMarkdown.document(from: "```\(declared)\nA\n```"))
            #expect(out == "```text\nA\n```", "`\(declared)` should be written as `text`")
        }
    }

    @Test func aDeclaredLanguageFenceIsUntouched() {
        let out = RichPasteDocument.canonicalSource(
            RichPasteMarkdown.document(from: "```python\nx = 1\n```"))
        #expect(out == "```python\nx = 1\n```")
    }
}
