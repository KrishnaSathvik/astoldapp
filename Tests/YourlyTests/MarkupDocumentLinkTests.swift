import Testing
import Foundation
@testable import Yourly

/// The source↔visible mapping, which is the riskiest thing links touched. Every caret move, every
/// selection, every voice insertion and every undo goes through it, so the first thing it owes is that
/// a note **without** a link is on exactly the arithmetic it was on before links existed.
struct MarkupDocumentHiddenRunTests {

    // MARK: The promise for notes that hold no links

    @Test func aNoteWithoutLinksIsUnchanged() {
        for source in ["", "plain", "# Heading\nbody", "- one\n- two\n1. three",
                       "- [ ] a\n- [x] b", "| a | b |\n| --- | --- |",
                       "line\n\nafter a blank"] {
            let doc = MarkupDocument(source)
            #expect(doc.lines.allSatisfy { $0.hiddenRuns.isEmpty })
            #expect(doc.lines.allSatisfy { $0.visibleLength == $0.contentLength })
            // Every visible offset round-trips, exactly as before.
            let visible = doc.visibleText() as NSString
            for offset in 0...visible.length {
                #expect(doc.visibleOffset(forSource: doc.sourceOffset(forVisible: offset)) == offset)
            }
        }
    }

    @Test func markersStillMapTheWayTheyAlwaysDid() {
        let doc = MarkupDocument("- Eggs")
        #expect(doc.visibleText() == "Eggs")
        #expect(doc.visibleOffset(forSource: 0) == 0)   // inside the marker clamps to content start
        #expect(doc.visibleOffset(forSource: 2) == 0)
        #expect(doc.visibleOffset(forSource: 3) == 1)
        #expect(doc.sourceOffset(forVisible: 0) == 2)
    }

    // MARK: Labelled links

    private let source = "Go to [Open reservation](https://astold.app) now"
    //                    0123456
    private var visible: String { "Go to Open reservation now" }

    @Test func aLabelledLinkShowsOnlyItsWords() {
        #expect(MarkupDocument(source).visibleText() == visible)
    }

    @Test func everyVisibleOffsetRoundTrips() {
        let doc = MarkupDocument(source)
        for offset in 0...(visible as NSString).length {
            let back = doc.visibleOffset(forSource: doc.sourceOffset(forVisible: offset))
            #expect(back == offset, "visible offset \(offset) did not survive the round trip")
        }
    }

    @Test func aSourceOffsetInsideHiddenSyntaxNeverBecomesAVisibleOne() {
        let doc = MarkupDocument(source)
        let ns = source as NSString
        // Walk the whole source; a visible offset must never exceed the visible length, and must never
        // move backwards as the source offset advances.
        var previous = 0
        for offset in 0...ns.length {
            let mapped = doc.visibleOffset(forSource: offset)
            #expect(mapped >= previous)
            #expect(mapped <= (visible as NSString).length)
            previous = mapped
        }
    }

    @Test func aVisibleOffsetNeverLandsInsideHiddenSyntax() {
        let doc = MarkupDocument(source)
        let line = doc.lines[0]
        for offset in 0...(visible as NSString).length {
            let mapped = doc.sourceOffset(forVisible: offset)
            #expect(line.hiddenRun(containing: mapped) == nil,
                    "visible offset \(offset) landed inside hidden link syntax at \(mapped)")
        }
    }

    @Test func aCaretInsideHiddenSyntaxIsGivenAWayOut() {
        // Every offset inside `](https://…)` draws at the same point, so a caret left there is
        // invisible — and the next character to arrive lands in the destination.
        let doc = MarkupDocument(source)
        let run = doc.lines[0].hiddenRuns.first { $0.length > 1 }!
        let inside = run.location + run.length / 2

        #expect(doc.caretEscapingHiddenSyntax(from: inside, movingForward: true) == NSMaxRange(run))
        #expect(doc.caretEscapingHiddenSyntax(from: inside, movingForward: false) == run.location)
        // Both answers are places the reader can see.
        for forward in [true, false] {
            let out = doc.caretEscapingHiddenSyntax(from: inside, movingForward: forward)!
            #expect(doc.lines[0].hiddenRun(containing: out) == nil)
        }
    }

    @Test func anOffsetTheReaderCanSeeIsLeftAlone() {
        // The escape must be silent everywhere else, or it would drag the caret around ordinary words.
        let doc = MarkupDocument(source)
        let line = doc.lines[0]
        for offset in 0...(source as NSString).length where line.hiddenRun(containing: offset) == nil {
            #expect(doc.caretEscapingHiddenSyntax(from: offset, movingForward: true) == nil,
                    "offset \(offset) was moved and should not have been")
        }
    }

    @Test func aRunsEdgesAreNotInsideIt() {
        // The end of the words before a link and the start of what follows it are both places a
        // writer is allowed to be, so neither is escaped.
        let doc = MarkupDocument(source)
        let run = doc.lines[0].hiddenRuns.first { $0.length > 1 }!
        #expect(doc.caretEscapingHiddenSyntax(from: run.location, movingForward: true) == nil)
        #expect(doc.caretEscapingHiddenSyntax(from: NSMaxRange(run), movingForward: false) == nil)
    }

    @Test func aNoteWithNoLinksHasNothingToEscape() {
        let doc = MarkupDocument("- Eggs\nplain words")
        for offset in 0...("- Eggs\nplain words" as NSString).length {
            #expect(doc.caretEscapingHiddenSyntax(from: offset, movingForward: true) == nil)
        }
    }

    @Test func theWordsBeforeAndAfterALinkKeepTheirPlaces() {
        let doc = MarkupDocument(source)
        #expect(doc.sourceOffset(forVisible: 0) == 0)                 // "G" of "Go"
        #expect(doc.visibleOffset(forSource: 0) == 0)
        // The visible offset of " now" is past the label, and maps back beyond the closing paren.
        let afterLabel = ("Go to Open reservation" as NSString).length
        #expect(doc.sourceOffset(forVisible: afterLabel + 1) > 43)
    }

    @Test func aLinkOnAStructuredLineKeepsBothHiddenThings() {
        let source = "- [Docs](https://astold.app) matter"
        let doc = MarkupDocument(source)
        #expect(doc.lines[0].kind == .bullet)
        #expect(doc.visibleText() == "Docs matter")
        for offset in 0...("Docs matter" as NSString).length {
            #expect(doc.visibleOffset(forSource: doc.sourceOffset(forVisible: offset)) == offset)
        }
    }

    @Test func twoLinksOnOneLineBothMap() {
        let source = "[A](https://a.example.com) and [B](https://b.example.com)"
        let doc = MarkupDocument(source)
        #expect(doc.visibleText() == "A and B")
        #expect(doc.lines[0].links.count == 2)
        for offset in 0...("A and B" as NSString).length {
            #expect(doc.visibleOffset(forSource: doc.sourceOffset(forVisible: offset)) == offset)
        }
    }

    @Test func aLinkOnALaterLineMapsAcrossTheOnesAboveIt() {
        let source = "first\nsecond\ngo [there](https://astold.app)"
        let doc = MarkupDocument(source)
        #expect(doc.visibleText() == "first\nsecond\ngo there")
        for offset in 0...("first\nsecond\ngo there" as NSString).length {
            #expect(doc.visibleOffset(forSource: doc.sourceOffset(forVisible: offset)) == offset)
        }
    }

    @Test func aBareURLHidesNothingAndMapsOneToOne() {
        let source = "Booking at https://astold.app"
        let doc = MarkupDocument(source)
        #expect(doc.visibleText() == source)
        #expect(doc.lines[0].hiddenRuns.isEmpty)
        #expect(doc.lines[0].links.first?.isLabelled == false)
    }

    @Test func aLinkIsFoundByTheOffsetATapResolvesTo() {
        let doc = MarkupDocument(source)
        #expect(doc.link(atSource: 10)?.destination == "https://astold.app")
        #expect(doc.link(atSource: 0) == nil)
    }

    @Test func codeInsideAFenceIsNeverReadAsALink() {
        // The characters are code. A URL in a comment is part of the code, not a tappable thing.
        let doc = MarkupDocument("```\n// see https://astold.app\n```")
        #expect(doc.lines[1].links.isEmpty)
        #expect(doc.links.isEmpty)
    }

    @Test func theCaretKnowsWhenItIsInCode() {
        let source = "before\n```\ncode\n```\nafter"
        let doc = MarkupDocument(source)
        #expect(doc.isLiteral(atSource: 0) == false)
        #expect(doc.isLiteral(atSource: 12) == true)
        #expect(doc.isLiteral(atSource: (source as NSString).length) == false)
    }
}
