import Testing
import Foundation
@testable import Yourly

/// The help surfaces are only worth having if they stay true. These tests pin the reference content
/// to the code that implements the behavior, so help cannot quietly drift from what the app accepts —
/// a help sheet that lies is worse than no help sheet.
struct WritingHelpTests {

    // MARK: Typing reference

    @Test func typingReferenceCoversEveryStructureAWriterCanType() {
        let shown = Set(WritingHelp.typingMarkers.map(\.marker))
        // Every kind except `paragraph`, which has no marker — it is what you get by typing nothing.
        let structural: [BlockKind] = [
            .heading, .subheading, .bullet, .numbered(1), .checklist(checked: false),
        ]
        for kind in structural {
            #expect(shown.contains(kind.marker), "help omits the marker for \(kind)")
        }
        #expect(shown.count == structural.count, "help shows a marker no BlockKind produces")
    }

    /// The trailing space is the difference between a bullet and a hyphen. If help ever prints a
    /// trimmed marker, readers will type it and get literal text.
    @Test func everyShownMarkerKeepsItsTrailingSpace() {
        for marker in WritingHelp.typingMarkers {
            #expect(marker.marker.hasSuffix(" "), "\(marker.name) is shown without its trailing space")
        }
    }

    /// What help tells you to type must actually parse as the thing it is named after.
    @Test func everyShownMarkerParsesAsItsAdvertisedKind() {
        for shown in WritingHelp.typingMarkers {
            let (kind, markerLength) = BlockKind.parse(line: shown.marker + "text")
            #expect(kind.marker == shown.marker, "\(shown.marker) does not parse back to itself")
            #expect(markerLength == (shown.marker as NSString).length)
        }
    }

    /// The checked box is intentionally absent from help: you make one by ticking, not by typing.
    @Test func helpDoesNotTeachTheCheckedCheckboxAsSomethingToType() {
        let shown = Set(WritingHelp.typingMarkers.map(\.marker))
        #expect(!shown.contains(BlockKind.checklist(checked: true).marker))
    }

    // MARK: Voice reference

    @Test func voiceReferenceListsExactlyTheNineRecognizedCommands() {
        let shown = Set(WritingHelp.voiceCommands.map { $0.lowercased() })
        #expect(shown == VoiceStructureParser.recognizedPhrases,
                "the help sheet and the parser disagree about the vocabulary")
        #expect(WritingHelp.voiceCommands.count == 9)
    }

    /// Every taught phrase must survive a round trip through the parser it documents.
    @Test func everyTaughtCommandIsActuallyRecognized() {
        for command in WritingHelp.voiceCommands {
            let (text, _) = VoiceStructureParser.apply("\(command). Something.", into: "", atUTF16: 0)
            #expect(!text.lowercased().contains(command.lowercased()),
                    "“\(command)” was inserted as literal text instead of being treated as a command")
        }
    }

    // MARK: Empty-note hint

    /// The hint is the smallest of the surfaces and must stay that way — three markers, drawn from
    /// the same source as the sheet so it cannot contradict it.
    @Test func emptyNoteHintTeachesRealMarkers() {
        let markers = WritingHelp.emptyNoteHintMarkers.map(\.marker)
        #expect(markers == [BlockKind.heading.marker,
                            BlockKind.bullet.marker,
                            BlockKind.checklist(checked: false).marker])
        #expect(!markers.contains(BlockKind.subheading.marker),
                "the hint should stay at three markers; the rest belong in the ? sheet")
    }

    /// The hint must never quote a marker inside prose: the trailing space is what makes the marker
    /// work, and a proportional font between quotes is where it went missing.
    @Test func emptyNoteHintKeepsMarkersOutOfItsSentence() {
        for marker in WritingHelp.emptyNoteHintMarkers.map(\.marker) {
            #expect(!WritingHelp.emptyNoteHintLead.contains(marker.trimmingCharacters(in: .whitespaces)))
        }
    }

    @Test func everyHintMarkerKeepsItsTrailingSpace() {
        for marker in WritingHelp.emptyNoteHintMarkers.map(\.marker) {
            #expect(marker.hasSuffix(" "), "the space is part of the marker and must be shown")
        }
    }

    // MARK: VoiceOver

    @Test func markersAreGivenSpokenNamesRatherThanPunctuation() {
        #expect(WritingHelpSheet.spokenMarker("# ") == "Number sign")
        #expect(WritingHelpSheet.spokenMarker("- ") == "Hyphen")
        #expect(WritingHelpSheet.spokenMarker("- [ ] ")
                == "Hyphen, open bracket, space, close bracket")
    }

    /// Every marker in the sheet needs a spoken form; a fallthrough would read raw punctuation.
    @Test func everyShownMarkerHasASpokenForm() {
        for marker in WritingHelp.typingMarkers {
            let spoken = WritingHelpSheet.spokenMarker(marker.marker)
            #expect(spoken != marker.marker, "\(marker.name) falls through to raw punctuation")
        }
    }
}
