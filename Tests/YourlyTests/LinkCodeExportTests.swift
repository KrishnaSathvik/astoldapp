import Testing
import Foundation
@testable import Yourly

/// What leaves the note. Three destinations, three answers — and none of them may lose a destination
/// the writer put in their own note (RULES.md §3).
struct LinkExportTests {

    private let source = "Booking is at [Open reservation](https://astold.app/r/8fa2)"
    private var whole: NSRange { NSRange(location: 0, length: (source as NSString).length) }

    @Test func plainTextKeepsBothHalvesOfALink() {
        // "The page as it reads" would send "Open reservation" and silently destroy the address.
        #expect(StructuredTextExport.plainText(from: source, range: whole)
                == "Booking is at Open reservation — https://astold.app/r/8fa2")
    }

    @Test func aBareURLTravelsAsItself() {
        let bare = "Booking is at https://astold.app"
        #expect(StructuredTextExport.plainText(bare) == bare)
    }

    @Test func richAppsGetARealHyperlink() {
        let html = StructuredTextExport.html(from: source, range: whole)
        // The document scaffolding carries the charset: without it a receiving app guesses an
        // encoding and every character above ASCII arrives mangled (`ClipboardEncodingTests`).
        #expect(html == "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body>"
                + "<div>Booking is at <a href=\"https://astold.app/r/8fa2\">Open reservation</a></div>"
                + "</body></html>")
    }

    @Test func aNoteWithoutLinksPutsNoHTMLOnThePasteboard() {
        // Nothing new on the pasteboard means nothing new for a receiving app to prefer.
        #expect(StructuredTextExport.html(from: "- Eggs\n- Milk", range: NSRange(location: 0, length: 13)) == nil)
    }

    @Test func hyperlinkTextIsEscapedForHTML() {
        let source = "[A & B <c>](https://astold.app/?x=1&y=2)"
        let html = StructuredTextExport.html(from: source,
                                             range: NSRange(location: 0, length: (source as NSString).length))
        #expect(html?.contains("A &amp; B &lt;c&gt;") == true)
        #expect(html?.contains("href=\"https://astold.app/?x=1&amp;y=2\"") == true)
    }

    @Test func aHomeRowShowsTheWordsAndNotTheSyntax() {
        #expect(StructuredTextExport.previewText(source) == "Booking is at Open reservation")
    }

    @Test func voiceOverIsToldItIsALink() {
        // The same rule that makes a checkbox say "Checked" rather than draw a glyph. A link that
        // differs only by colour conveys nothing to someone who cannot see the page.
        #expect(StructuredTextExport.spokenText(source) == "Booking is at Link, Open reservation")
    }

    @Test func noSurfaceThatShowsANoteAsTextEverLeaksLinkSyntax() {
        for rendered in [StructuredTextExport.previewText(source),
                         StructuredTextExport.spokenText(source),
                         StructuredTextExport.plainText(source)] {
            #expect(!rendered.contains("]("))
        }
    }

    @Test func aFragmentOfALinkCarriesWordsAndNoSyntax() {
        // A selection that clipped a link is not a link, and a stray "](https://…" must never travel.
        let partial = NSRange(location: 0, length: 25)   // stops inside the label
        let text = StructuredTextExport.plainText(from: source, range: partial)
        #expect(!text.contains("["))
        #expect(!text.contains("]("))
    }

    @Test func anAsToldToAsToldCopyKeepsTheLink() {
        #expect(StructuredTextExport.structuredText(from: source, range: whole) == source)
    }

    @Test func aBareURLNeedsNoPrivateFlavor() {
        // It round-trips as plain text on its own; there is no structure to preserve.
        let bare = "Booking at https://astold.app"
        #expect(StructuredTextExport.structuredText(from: bare,
                                                    range: NSRange(location: 0, length: (bare as NSString).length)) == nil)
    }
}

/// A fence is how the note stores code. It is not part of the code, and no surface shows it except the
/// one belonging to the person editing it.
struct CodeExportTests {

    private let source = "Try this\n```python\ndef hello():\n    print(\"hi\")\n```\nDone"
    private var whole: NSRange { NSRange(location: 0, length: (source as NSString).length) }

    @Test func copyingCodeDropsTheFences() {
        #expect(StructuredTextExport.plainText(from: source, range: whole)
                == "Try this\ndef hello():\n    print(\"hi\")\nDone")
    }

    @Test func indentationSurvivesTheCopy() {
        #expect(StructuredTextExport.plainText(from: source, range: whole).contains("    print"))
    }

    @Test func aHomeRowShowsCodeAndNotBackticks() {
        let preview = StructuredTextExport.previewText(source)
        #expect(!preview.contains("```"))
        #expect(preview.contains("def hello():"))
    }

    @Test func voiceOverHearsTheCodeAndNotTheFence() {
        #expect(!StructuredTextExport.spokenText(source).contains("```"))
    }

    @Test func aMarkerInsideCodeIsNeverSpokenAsStructure() {
        // Without fence awareness this said "Bullet, item" for a line of YAML.
        let yaml = "```yaml\n- item\n```"
        #expect(StructuredTextExport.spokenText(yaml) == "- item")
    }

    @Test func codeKeepsItsIndentationInTheRichFlavorToo() {
        // HTML collapses runs of spaces, so `<br>`-separated code would arrive in Mail with its
        // indentation gone. `<pre>` is the only thing that keeps it.
        let source = "See [docs](https://astold.app)\n```\nif x:\n    deep\n```"
        let html = StructuredTextExport.html(from: source,
                                             range: NSRange(location: 0, length: (source as NSString).length))
        #expect(html?.contains("<pre>if x:\n    deep</pre>") == true)
        #expect(html?.contains("<a href=\"https://astold.app\">docs</a>") == true)
    }

    @Test func anAsToldToAsToldCopyKeepsTheFences() {
        // The private flavor is the one place the canonical source travels, so a round trip inside the
        // app gives back code that is still code.
        #expect(StructuredTextExport.structuredText(from: source, range: whole) == source)
    }
}

/// Everything the rich flavor emits must be escaped, not only the parts that obviously look like
/// markup. `html(from:range:)` runs whenever a selection carries a link, so the prose *around* that
/// link is emitted too — and prose is where `<` and `&` actually turn up.
struct HTMLEscapingTests {

    private func html(_ source: String) -> String? {
        StructuredTextExport.html(from: source,
                                  range: NSRange(location: 0, length: (source as NSString).length))
    }

    @Test func codeInsideAPreIsEscaped() {
        let out = html("See [docs](https://astold.app)\n```\nif a < b && c > d\n```") ?? ""
        #expect(out.contains("if a &lt; b &amp;&amp; c &gt; d"))
        #expect(!out.contains("a < b"))
    }

    @Test func proseAroundALinkIsEscaped() {
        let out = html("if a < b && c > d see [docs](https://astold.app)") ?? ""
        #expect(out.contains("if a &lt; b &amp;&amp; c &gt; d"))
        #expect(!out.contains("a < b"))
    }

    @Test func aBareURLsOwnCharactersAreEscaped() {
        let out = html("[x](https://astold.app) then https://astold.app/?a=1&b=2") ?? ""
        #expect(!out.contains("?a=1&b=2"))
    }

    @Test func nothingUnescapedSurvivesAnywhereInTheFlavor() {
        let out = html("a & b <tag> [docs](https://astold.app) \"quoted\"\n```\n<x> & <y>\n```") ?? ""
        // Every "<" that remains must be the start of a tag this function wrote itself.
        for (index, character) in out.enumerated() where character == "<" {
            let rest = String(out.dropFirst(index))
            let tags = ["<div", "</div", "<a ", "</a", "<br", "<pre", "</pre",
                        // the document the charset declaration needs
                        "<!DOCTYPE", "<html", "</html", "<head", "</head", "<meta", "<body", "</body"]
            #expect(tags.contains { rest.hasPrefix($0) },
                    "unescaped '<' at \(index) in: \(out)")
        }
    }
}
