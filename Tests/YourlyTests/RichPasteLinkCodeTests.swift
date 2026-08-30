import Testing
import Foundation
@testable import Yourly

/// Paste, for the two things `body` can now hold. The rule is unchanged and is the whole discipline:
/// **preserve declared structure, don't guess structure.**
struct RichPasteLinkTests {

    private func source(html: String) -> String? {
        RichPasteDocument.canonicalSource(RichPasteHTML.document(from: html))
    }

    @Test func anAnchorKeepsItsWordsAndItsDestination() {
        #expect(source(html: "<p>Booking is at <a href=\"https://astold.app/r/8\">Open reservation</a></p>")
                == "Booking is at [Open reservation](https://astold.app/r/8)")
    }

    @Test func anAnchorWhoseTextIsItsAddressNeedsNoTranslatedPaste() {
        // No labelled link is written — `[https://x](https://x)` would be syntax nobody wrote — and
        // with nothing else stated, the paste falls through to the system's own plain-text insert,
        // which already carries those exact characters. `LinkSpan` reads them back as a link.
        #expect(source(html: "<p><a href=\"https://astold.app\">https://astold.app</a></p>") == nil)
    }

    @Test func anAnchorAsToldWouldNotOpenKeepsOnlyItsWords() {
        // Every character of the text is preserved; the destination is the part that cannot travel.
        #expect(source(html: "<p><a href=\"javascript:alert(1)\">Click me</a></p>") == nil)
        #expect(source(html: "<p>Read <a href=\"mailto:hi@astold.app\">our email</a> now</p>")
                == nil)
    }

    @Test func anAnchorWithNoWordsContributesNothing() {
        // There is no text to preserve, and writing the bare href would put a URL on the page the
        // source never showed.
        #expect(source(html: "<p>Before<a href=\"https://astold.app\"></a>After</p>") == nil)
    }

    @Test func aLinkInsideAListItemKeepsBoth() {
        #expect(source(html: "<ul><li>See <a href=\"https://astold.app\">the docs</a></li></ul>")
                == "- See [the docs](https://astold.app)")
    }

    @Test func aLinkIsEnoughStructureToBeWorthATranslatedPaste() {
        // A paragraph carrying only a hyperlink states structure. Falling through to the system's
        // plain-text paste would drop the destination the clipboard stated.
        #expect(source(html: "<p><a href=\"https://astold.app\">As Told</a></p>")
                == "[As Told](https://astold.app)")
    }

    @Test func aDeclaredMarkdownLinkKeepsItsDestination() {
        #expect(RichPasteMarkdown.inlineText("See [the docs](https://astold.app) now")
                == "See [the docs](https://astold.app) now")
    }

    @Test func aMarkdownImageStillKeepsOnlyItsWords() {
        // As Told has no images, and an image's address is not something a reader can use.
        #expect(RichPasteMarkdown.inlineText("![a picture](https://astold.app/x.png)") == "a picture")
    }

    @Test func aMarkdownTitleIsNotPartOfTheAddress() {
        #expect(RichPasteMarkdown.inlineText("[docs](https://astold.app \"Tooltip\")")
                == "[docs](https://astold.app)")
    }

    @Test func angleBracketsAroundADestinationAreMarkdownsAndNotTheAddress() {
        #expect(RichPasteMarkdown.inlineText("[docs](<https://astold.app>)")
                == "[docs](https://astold.app)")
    }

    @Test func plainTextIsStillNeverReadForLinks() {
        // `public.plain-text` names no format and states no structure. A URL typed into a note becomes
        // a link because `LinkSpan` reads it back, not because paste rewrote anything.
        #expect(source(html: "") == nil)
    }
}

struct RichPasteCodeTests {

    private func source(html: String) -> String? {
        RichPasteDocument.canonicalSource(RichPasteHTML.document(from: html))
    }

    @Test func preBecomesAFencedBlock() {
        // The fence says `text` because `<pre>` is HTML's word for preformatted and this one held no
        // `<code>` to say otherwise (changed 2026-08-25, `PreformattedImportTests`). What lands is the
        // same block it always was — same characters, same card, same sideways scroll — and the header
        // now says Plain text where it used to say nothing.
        #expect(source(html: "<pre>def hello():\n    print(\"hi\")</pre>")
                == "```text\ndef hello():\n    print(\"hi\")\n```")
    }

    @Test func aNamedLanguageSurvives() {
        #expect(source(html: "<pre><code class=\"language-python\">x = 1</code></pre>")
                == "```python\nx = 1\n```")
    }

    @Test func indentationInsidePreIsUntouched() {
        let out = source(html: "<pre>if x:\n        deep\n\tt</pre>") ?? ""
        #expect(out.contains("\n        deep\n"))
        #expect(out.contains("\n\tt\n"))
    }

    @Test func codeIsEnoughStructureToBeWorthATranslatedPaste() {
        // Every line of a `<pre>` is a paragraph; without this, a paste of nothing but code fell
        // through to plain text and arrived with no fences at all.
        #expect(source(html: "<pre>x = 1</pre>") != nil)
    }

    @Test func aPastedCommentIsNotAHeading() {
        let out = source(html: "<pre># not a heading</pre>") ?? ""
        #expect(MarkupDocument(out).lines.allSatisfy { $0.kind == .paragraph })
        #expect(CodeBlock.blocks(in: out).first?.codeLines == ["# not a heading"])
    }

    @Test func declaredMarkdownFencesBecomeCodeBlocks() {
        let blocks = RichPasteMarkdown.document(from: "```python\n# comment\n- item\n```")
        guard case .codeBlock(let code)? = blocks.first else {
            Issue.record("expected a code block, got \(blocks)")
            return
        }
        #expect(code.language == "python")
        #expect(code.code == "# comment\n- item")
    }

    @Test func aMarkdownFenceRetiresTheOldLimitation() {
        // This is the V1 limitation the fence removes: a fenced line beginning with "# " used to land
        // in `body` as a heading, because `body` had no way to say "this is code".
        let out = RichPasteDocument.canonicalSource(
            RichPasteMarkdown.document(from: "```\n# hello\n```")) ?? ""
        #expect(MarkupDocument(out).lines.contains { $0.isLiteral })
        #expect(MarkupDocument(out).lines.allSatisfy { $0.kind != .heading })
    }

    // MARK: A `<pre>` whose lines are elements
    //
    // The tests above all paste a `<pre>` holding literal newlines, which is the shape a hand-written
    // page has and almost nothing else does. Every syntax highlighter on the web — and so every copy
    // from a docs site, a code host, or an answer in a chat — wraps each line in its own element and
    // each token in a `<span>`. That copy arrived as ordinary body text: a block tag flushed the code
    // buffer as paragraphs on its way past, so by the time `</pre>` closed there was nothing left to
    // emit and no `.codeBlock` was ever produced.

    @Test func aPreWhoseLinesAreDivsIsStillOneCodeBlock() {
        let html = """
        <pre><code class="language-sql"><div>SELECT managerId</div>\
        <div>FROM Employee</div><div>GROUP BY managerId</div></code></pre>
        """
        let out = source(html: html) ?? ""
        let block = CodeBlock.blocks(in: out).first
        #expect(block?.language == "sql")
        #expect(block?.codeLines == ["SELECT managerId", "FROM Employee", "GROUP BY managerId"])
    }

    @Test func perTokenSpansDoNotBreakTheLine() {
        // Highlighting is markup around words. The words are the code; the colours are not ours.
        let html = """
        <pre><code class="language-sql"><span class="k">SELECT</span> <span class="n">managerId</span>\
        <br><span class="k">FROM</span> <span class="n">Employee</span></code></pre>
        """
        let out = source(html: html) ?? ""
        #expect(CodeBlock.blocks(in: out).first?.codeLines == ["SELECT managerId", "FROM Employee"])
    }

    @Test func aPreWhoseLinesAreParagraphsIsStillOneCodeBlock() {
        let html = "<pre><p>SELECT 1</p><p>FROM t</p></pre>"
        #expect(CodeBlock.blocks(in: source(html: html) ?? "").first?.codeLines
                == ["SELECT 1", "FROM t"])
    }

    @Test func indentationSurvivesPerLineElements() {
        // The reason `<pre>` is honoured at all: the source said these characters are literal.
        let html = "<pre><div>def f():</div><div>    return 1</div></pre>"
        #expect(CodeBlock.blocks(in: source(html: html) ?? "").first?.codeLines
                == ["def f():", "    return 1"])
    }

    @Test func aBlankLineInsideCodeSurvives() {
        // Two explicit breaks are a blank line the author left in their code; two element boundaries
        // are one line ending and the next beginning. The difference has to survive, or a paste either
        // double-spaces every line or loses the gaps between paragraphs of a script.
        let out = source(html: "<pre><div>a</div><div><br><br></div><div>b</div></pre>") ?? ""
        #expect(CodeBlock.blocks(in: out).first?.codeLines == ["a", "", "b"])
    }

    @Test func aRealSQLCopyLandsAsACodeBlock() {
        // The shape a copy out of a docs site or an answer actually has: a wrapper div, a language
        // class, one element per line, one span per token.
        let html = """
        <div class="highlight"><pre><code class="language-sql">\
        <span class="k">SELECT</span> managerId</code></pre></div>
        """
        let out = source(html: html) ?? ""
        let block = CodeBlock.blocks(in: out).first
        #expect(block?.language == "sql")
        #expect(block?.codeLines == ["SELECT managerId"])
        // …and every line of it is literal, so a `#` comment in someone's SQL is never a heading.
        #expect(MarkupDocument(out).lines.allSatisfy { $0.kind == .paragraph })
    }

    @Test func aBlockTagOutsideAPreStillEndsItsLine() {
        // The guard is scoped to `<pre>`: everywhere else a block tag ends the line it is on, which is
        // what keeps two pasted paragraphs from running together.
        #expect(source(html: "<h1>One</h1><div>Two</div><div>Three</div>")
                == "# One\nTwo\n\nThree")
    }

    @Test func aWholePastedDocumentKeepsEveryStructureItStated() {
        let html = """
        <h1>Setup</h1><p>Read the <a href="https://astold.app/docs">docs</a> first.</p>
        <ul><li>One</li><li>Two</li></ul>
        <pre><code class="language-swift">let x = 1</code></pre>
        """
        let out = source(html: html) ?? ""
        let doc = MarkupDocument(out)
        #expect(doc.lines.first?.kind == .heading)
        #expect(doc.links.contains { $0.destination == "https://astold.app/docs" })
        #expect(doc.lines.contains { $0.kind == .bullet })
        #expect(CodeBlock.blocks(in: out).first?.language == "swift")
    }
}
