import Testing
import Foundation
@testable import Yourly

/// Reading a link back out of `body`. Strict on purpose, for the reason `TableBlock` is strict: a note
/// that turned words into links because they resembled one would be worse than a note that linked
/// nothing at all.
struct LinkSpanDetectionTests {

    private func links(_ line: String) -> [LinkSpan] {
        LinkSpan.links(inLineContent: line, offset: 0)
    }

    // MARK: Bare URLs

    @Test func aBareURLIsALink() {
        let found = links("Booking is at https://astold.app")
        #expect(found.count == 1)
        #expect(found.first?.destination == "https://astold.app")
        #expect(found.first?.isLabelled == false)
        #expect(found.first?.hiddenRuns.isEmpty == true)
    }

    @Test func aBareURLShowsEveryCharacterItHas() {
        let line = "See https://astold.app/privacy now"
        let link = links(line).first
        #expect(link?.displayText(in: line) == "https://astold.app/privacy")
        // Nothing is hidden, so what the reader sees is the source.
        #expect(link?.displayRange == link?.sourceRange)
    }

    @Test func proseThatMentionsADomainIsProse() {
        #expect(links("I bought it from apple.com yesterday").isEmpty)
        #expect(links("Ask about www.example.org").isEmpty)
    }

    @Test func onlyWebSchemesAreLinks() {
        // The allowlist is the safety rule, not a formality: `body` is text a note can receive from a
        // clipboard, and a tappable `javascript:` in someone's notes is a hazard.
        #expect(links("javascript:alert(1)").isEmpty)
        #expect(links("file:///etc/passwd").isEmpty)
        #expect(links("mailto:hi@astold.app").isEmpty)
        #expect(links("ftp://files.example.com").isEmpty)
    }

    @Test func aSchemeInsideAWordIsNotALink() {
        #expect(links("xhttps://astold.app").isEmpty)
    }

    @Test func sentencePunctuationIsNotPartOfTheAddress() {
        #expect(links("Read https://astold.app.").first?.destination == "https://astold.app")
        #expect(links("Read https://astold.app, then go").first?.destination == "https://astold.app")
        #expect(links("Really? https://astold.app!").first?.destination == "https://astold.app")
    }

    @Test func aURLKeepsABracketItOpenedItself() {
        let link = links("see https://en.wikipedia.org/wiki/Foo_(bar) now").first
        #expect(link?.destination == "https://en.wikipedia.org/wiki/Foo_(bar)")
    }

    @Test func aURLLosesABracketItNeverOpened() {
        let link = links("(see https://astold.app)").first
        #expect(link?.destination == "https://astold.app")
    }

    @Test func twoBareURLsOnOneLineAreTwoLinks() {
        let found = links("https://a.example.com and https://b.example.com")
        #expect(found.count == 2)
        #expect(found.map(\.destination) == ["https://a.example.com", "https://b.example.com"])
    }

    // MARK: Labelled links

    @Test func aLabelledLinkHidesItsSyntaxAndShowsItsWords() {
        let line = "Booking is at [Open reservation](https://astold.app/r/8fa2)"
        let link = links(line).first
        #expect(link?.destination == "https://astold.app/r/8fa2")
        #expect(link?.isLabelled == true)
        #expect(link?.displayText(in: line) == "Open reservation")
    }

    @Test func onlyAnAbsoluteWebDestinationMakesBracketsALink() {
        // Someone writing "[see](this)" in a note keeps their brackets as words.
        #expect(links("[see](this)").isEmpty)
        #expect(links("[docs](/local/path)").isEmpty)
        #expect(links("[mail](mailto:hi@astold.app)").isEmpty)
    }

    @Test func anEmptyLabelMakesNoLabelledLink() {
        // There is nothing to show, so no labelled link is formed. The address is still *visibly*
        // there in the note's own characters, so it is still read as the bare URL it looks like.
        let found = links("[](https://astold.app)")
        #expect(found.allSatisfy { !$0.isLabelled })
        #expect(found.first?.destination == "https://astold.app")
    }

    @Test func aLinkNeverSpansLines() {
        #expect(LinkSpan.links(inLineContent: "[label", offset: 0).isEmpty)
    }

    @Test func anEscapedBracketStaysInsideTheLabel() {
        let line = "[a \\] b](https://astold.app)"
        let link = links(line).first
        #expect(link?.displayText(in: line) == "a ] b")
    }

    @Test func theDestinationInsideALabelledLinkIsNotASecondLink() {
        let found = links("[Open](https://astold.app)")
        #expect(found.count == 1)
    }

    @Test func rangesAreReportedInWholeSourceCoordinates() {
        let found = LinkSpan.links(inLineContent: "go https://astold.app", offset: 100)
        #expect(found.first?.sourceRange == NSRange(location: 103, length: 18))
    }
}

/// Writing a link into `body`. Only paste ever calls this; nothing rewrites a note on its own.
struct LinkSpanWritingTests {

    @Test func aLabelDifferentFromItsDestinationBecomesALabelledLink() {
        #expect(LinkSpan.source(label: "Open reservation", destination: "https://astold.app/r/8")
                == "[Open reservation](https://astold.app/r/8)")
    }

    @Test func aLabelThatIsAlreadyTheDestinationStaysABareURL() {
        // `[https://x](https://x)` would be the app inventing syntax around words nobody wrote.
        #expect(LinkSpan.source(label: "https://astold.app", destination: "https://astold.app")
                == "https://astold.app")
    }

    @Test func aDestinationAsToldWillNotOpenKeepsOnlyTheWords() {
        #expect(LinkSpan.source(label: "click", destination: "javascript:alert(1)") == "click")
        #expect(LinkSpan.source(label: "home", destination: "/relative") == "home")
    }

    @Test func aBracketInTheLabelTravelsEscaped() {
        let written = LinkSpan.source(label: "a ] b", destination: "https://astold.app")
        #expect(written == "[a \\] b](https://astold.app)")
        // …and reads back as the words it started as.
        #expect(LinkSpan.links(inLineContent: written, offset: 0)
            .first?.displayText(in: written) == "a ] b")
    }

    @Test func whatIsWrittenIsWhatIsRead() {
        for (label, destination) in [("Open reservation", "https://astold.app/r/8fa2"),
                                     ("a (b) c", "https://astold.app/x?y=1&z=2"),
                                     ("తెలుగు", "https://astold.app/te")] {
            let written = LinkSpan.source(label: label, destination: destination)
            let link = LinkSpan.links(inLineContent: written, offset: 0).first
            #expect(link?.displayText(in: written) == label)
            #expect(link?.destination == destination)
        }
    }
}
