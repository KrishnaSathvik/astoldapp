import Testing
import Foundation
import UIKit
@testable import Yourly

/// Everything a preformatted block inherits by *being* a fenced block, pinned so that inheritance
/// cannot quietly stop.
///
/// None of this is new code. A diagram is edited, rendered, copied, exported and read back through the
/// exact paths a code block uses, because those paths were never about code — they are about a run of
/// characters As Told must not touch and must not wrap. These tests exist because "it works for free"
/// is a claim, and a claim about behaviour a writer depends on has to be checked.
struct PreformattedBehaviorTests {

    private let diagram = """
    ```text
    DOL / USCIS
        │
        ▼
    Airflow detects new release
    ```
    """

    // MARK: Editing in place — the fences are storage, and storage is not a place

    @Test func theFencesAreNotLinesTheCaretCanRestOn() {
        // Arrowing down off the opening fence lands on the first line of the drawing, not inside
        // ```` ```text ````, where the next keystroke would break the fence and drop the card.
        let escape = CodeBlock.caretEscape(in: diagram, from: 0, movingForward: true)
        #expect(escape != nil)
        let line = StructuredText.lineIndex(of: escape ?? 0, in: diagram as NSString)
        #expect(line == 1)
    }

    @Test func theFenceLinesAreKnownToBeFences() {
        #expect(CodeBlock.isFenceLine(0, in: diagram))
        #expect(CodeBlock.isFenceLine(5, in: diagram))
        #expect(!CodeBlock.isFenceLine(2, in: diagram))
    }

    @Test func typingElsewhereLeavesTheDiagramAsACard() {
        // The 2026-08-23 rule: only the block the caret is *inside* gives up its card. A note with a
        // diagram at the top must not visibly break because a sentence is being typed at the bottom.
        let source = diagram + "\nA sentence being typed."
        let caret = StructuredText.lineIndices(touchedBy: NSRange(location: (source as NSString).length, length: 0),
                                               in: source as NSString)
        let block = CodeBlock.blocks(in: source).first
        #expect(block?.lineRange.overlaps(caret) == false)
    }

    @Test func theCardKeepsItsGeometryWhicheverKindItIs() {
        // Same layout, same reserved height, same sideways scroll: a wrapped line of a diagram is a
        // different diagram, exactly as a wrapped line of code is different code.
        let wide = String(repeating: "─", count: 400)
        let block = CodeBlock(language: "text", lineRange: 0...2, codeLines: [wide])
        let layout = CodeCardLayout.layout(for: block, availableWidth: 353)
        #expect(layout?.scrolls == true)
        #expect(layout?.size.width == 353)
    }

    // MARK: Copy and export

    @Test func copyingTheNoteGivesTheDrawingWithoutItsFences() {
        let out = StructuredTextExport.plainText(diagram)
        #expect(out == "DOL / USCIS\n    │\n    ▼\nAirflow detects new release")
        #expect(!out.contains("```"))
    }

    @Test func everyBoxCharacterSurvivesThePlainFlavor() {
        let art = "┌──────┼──────┐\n▼      ▼      ▼\n│├└─┐▲→←"
        let source = CodeBlock.preformattedSource(text: art)
        #expect(StructuredTextExport.plainText(source) == art)
        // …and as the bytes the pasteboard actually carries, which is where the mojibake bug lived.
        #expect(String(data: Data(StructuredTextExport.plainText(source).utf8), encoding: .utf8) == art)
    }

    @Test func aDiagramSurvivesTheRichFlavorIntact() {
        // The HTML flavor is written when the selection carries a link; the diagram travels with it,
        // through `<pre>`, escaping and a declared charset.
        let art = "A & B\n  <tag>\n  │\n  ▼\n  ’ — → తెలుగు"
        let source = "See [x](https://astold.app)\n" + CodeBlock.preformattedSource(text: art)
        let range = NSRange(location: 0, length: (source as NSString).length)
        guard let html = StructuredTextExport.html(from: source, range: range) else {
            Issue.record("a selection carrying a link should produce an HTML flavor")
            return
        }
        #expect(html.contains("<pre>"))
        #expect(html.contains("&amp;"))
        #expect(html.contains("&lt;tag&gt;"))

        let bytes = Data(html.utf8)
        let decoded = String(data: bytes, encoding: .utf8) ?? ""
        let back = RichPasteHTML.source(from: decoded) ?? ""
        #expect(CodeBlock.blocks(in: back).first?.codeLines == art.components(separatedBy: "\n"))
    }

    @Test func asToldToAsToldIsAnExactRoundTrip() {
        let range = NSRange(location: 0, length: (diagram as NSString).length)
        #expect(StructuredTextExport.structuredText(from: diagram, range: range) == diagram)
    }

    // MARK: Reading surfaces

    @Test func aHomeRowShowsTheDrawingAndNotItsFences() {
        // Three lines is all a row draws, so the author's own first line is what a reader sees —
        // which is more use than a label As Told invented, and As Told does not name someone's
        // drawing (RULES.md §2). What must never appear is the storage.
        let preview = StructuredTextExport.previewText(diagram)
        #expect(preview.hasPrefix("DOL / USCIS"))
        #expect(!preview.contains("```"))
    }

    @Test func searchStillSeesInsideADiagram() {
        #expect(StructuredTextExport.previewText(diagram).contains("Airflow"))
        #expect(diagram.contains("Airflow"))
    }

    // MARK: A known limitation, found on the simulator and recorded here

    @Test @MainActor func aWideBlockCannotYetBeScrolledByAFinger() {
        // **This test pins a defect, not a design.** A block wider than the page reports `scrolls`,
        // draws a horizontal scroll indicator, and cannot be moved: `CodeBlockView.hitTest` returns nil
        // for every point except Copy, so the card's own `UIScrollView` never receives a touch. Verified
        // on the simulator — a real sideways drag across the card changed nothing at all.
        //
        // It is inherited, not new: the card has been inert except Copy since it shipped, deliberately,
        // so that a tap reaches the source underneath and puts the caret in the code (RULES.md §7,
        // docs/03-design-system.md — "the card is inert except Copy Code"). For code that was a fair
        // trade, because most code fits. For a diagram it is not, because content wider than the page is
        // the entire point of the feature.
        //
        // The content is not lost — tapping into the block shows every character, wrapped — but the
        // aligned drawing cannot be read past the card's edge while reading. Fixing it means changing
        // what the card does with touches, which is a locked interaction rule, so it is recorded here
        // rather than quietly altered.
        let wide = String(repeating: "─", count: 80)
        let block = CodeBlock(language: "text", lineRange: 0...3, codeLines: [wide, wide])
        let layout = CodeCardLayout.layout(for: block, availableWidth: 353)!
        let card = CodeBlockView(block: block, layout: layout, palette: .ds)
        card.frame = CGRect(origin: .zero, size: layout.size)
        card.layoutIfNeeded()

        #expect(layout.scrolls, "the block must want to scroll for this to mean anything")
        let overCode = CGPoint(x: layout.size.width / 2, y: layout.size.height / 2)
        #expect(card.hitTest(overCode, with: nil) == nil,
                "if this now returns a view, sideways scrolling may have been fixed — check the swipe")
    }

    // MARK: Regressions — what this must not have touched

    @Test func aDiagramIsNeverAutoDetectedAsCode() {
        // Normal Paste leaves a diagram as prose. There is no ASCII-art detector, and the code
        // detector must not stand in for one (RULES.md §4).
        let diagrams = [
            "DOL / USCIS\n    │\n    ▼\nAirflow detects new release",
            "sponsor-intelligence/\n├── apps/\n│   ├── web/\n│   └── api/",
            "Historical evidence\n        │\n ┌──────┼──────┐\n ▼      ▼      ▼\nCompany Role Location",
        ]
        for art in diagrams {
            #expect(CodeDetection.detect(art) == nil, "a diagram was auto-fenced as code: \(art)")
        }
    }

    @Test func realCodeIsStillAutoDetected() {
        #expect(CodeDetection.detect("def hello(name):\n    return name")?.language == "python")
        #expect(CodeDetection.detect("SELECT id, name\nFROM users\nWHERE id = 1;")?.language == "sql")
    }

    @Test func aCodeBlockIsUnchangedInEveryWayThatMatters() {
        let python = "```python\ndef hello():\n    print(\"hi\")\n```"
        let block = CodeBlock.blocks(in: python).first
        #expect(block?.kind == .code)
        #expect(block?.language == "python")
        #expect(block?.cardLabel == "Python")
        #expect(CodeHighlighting.language(named: block?.language ?? nil) != nil)
        #expect(StructuredTextExport.plainText(python) == "def hello():\n    print(\"hi\")")
    }

    @Test func ordinaryProseIsStillOrdinaryProse() {
        let note = "# Monday\n- Call Ravi\n- [ ] Book the flight\n\nSee [the docs](https://astold.app)."
        let doc = MarkupDocument(note)
        #expect(doc.lines[0].kind == .heading)
        #expect(doc.lines[1].kind == .bullet)
        #expect(doc.links.first?.destination == "https://astold.app")
        #expect(CodeBlock.blocks(in: note).isEmpty)
    }

    @Test func aRealTableIsStillATable() {
        let table = "| Company | Role |\n| --- | --- |\n| Acme | SDE |"
        #expect(TableBlock.tables(in: table).count == 1)
    }
}
