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

    // MARK: Behavior reference (the part a writer reads first)

    /// Every structure the Style menu can apply is described, and described only once. Paragraph is the
    /// deliberate exception: it is the absence of a structure, and it appears as the way *out* of a
    /// list instead.
    @Test func theBehaviorReferenceCoversEveryStructureTheMenuOffers() {
        let described = WritingHelp.structures.map(\.style)
        let offered = BlockStyle.allCases.filter { $0 != .paragraph }
        #expect(Set(described) == Set(offered), "a structure the menu offers is never described")
        #expect(described.count == offered.count, "a structure is described twice")
    }

    /// The path it tells you to tap is built from the menu's own label, so renaming a row renames it
    /// here too. This is the test that would have caught "Style → Normal" surviving the rename.
    @Test func everyDescribedStructureNamesTheMenuRowThatAppliesIt() {
        for structure in WritingHelp.structures {
            #expect(structure.tapPath == "Style → \(structure.style.name)")
            #expect(structure.name == structure.style.name)
        }
    }

    /// And the phrase it tells you to say has to be one the parser accepts, for the structure it claims.
    @Test func everyDescribedStructureNamesAPhraseThatActuallyProducesIt() {
        for structure in WritingHelp.structures {
            let phrase = structure.spoken.lowercased()
            #expect(VoiceStructureParser.recognizedPhrases[phrase] != nil,
                    "help says to say “\(structure.spoken)”, which the parser does not accept")
            let (text, _) = VoiceStructureParser.apply("\(structure.spoken). Something.",
                                                       into: "", atUTF16: 0)
            #expect(text.hasPrefix(structure.style.kind.marker),
                    "“\(structure.spoken)” did not produce a \(structure.name)")
        }
    }

    /// A label and a phrase are two different jobs, and RULES.md §1 keeps them two different strings.
    /// The row reads "Bulleted List"; nobody says that out loud, so the taught phrase is "Bullet list"
    /// and the parser hears it. Pinned so a later tidy-up cannot collapse them into one string and
    /// quietly break whichever end it was not thinking about.
    @Test func theMenuLabelAndTheTaughtPhraseAreSeparateStrings() {
        let bullet = WritingHelp.structures.first { $0.style == .bullet }
        #expect(bullet?.name == "Bulleted List", "the menu label changed without this test")
        #expect(bullet?.spoken == "Bullet list", "the spoken phrase followed the menu label")
        #expect(VoiceStructureParser.recognizedPhrases["bullet list"] == .bulletList)
    }

    /// The way out is named after the menu row that performs it, for the same reason.
    @Test func leavingAListNamesTheParagraphRow() {
        #expect(WritingHelp.leavingAList.contains(BlockStyle.paragraph.name))
        #expect(WritingHelp.leavingAList.contains("Return"))
    }

    // MARK: Voice reference

    /// Help teaches **one phrasing per action** — nine, the number a person can hold — and every one of
    /// them has to be a phrase the parser accepts. The parser accepts more *spellings* than this
    /// (RULES.md §2 aliases); what it must never do is perform an action nobody was taught, or leave a
    /// taught phrase unrecognized.
    @Test func voiceReferenceTeachesOnePhrasingForEveryActionTheParserPerforms() {
        let shown = Set(WritingHelp.voiceCommands.map { $0.lowercased() })
        let recognized = VoiceStructureParser.recognizedPhrases
        #expect(WritingHelp.voiceCommands.count == 9)
        #expect(shown.isSubset(of: Set(recognized.keys)),
                "the help sheet teaches a phrase the parser does not accept")

        let taught = shown.compactMap { recognized[$0] }
        #expect(Set(taught) == Set(VoiceStructureParser.Command.allCases),
                "the parser performs an action the help sheet never teaches")
        #expect(Set(taught).count == taught.count, "two taught phrases do the same thing")
    }

    /// Every alias must be an alias *of something taught*. An accepted phrase that maps to no taught
    /// action would be a command only the source code knows about.
    @Test func everyAcceptedSpellingIsASpellingOfATaughtAction() {
        let taught = Set(WritingHelp.voiceCommands.compactMap {
            VoiceStructureParser.recognizedPhrases[$0.lowercased()]
        })
        for (phrase, command) in VoiceStructureParser.recognizedPhrases {
            #expect(taught.contains(command), "“\(phrase)” performs an action help never mentions")
        }
    }

    /// Every taught phrase must survive a round trip through the parser it documents.
    @Test func everyTaughtCommandIsActuallyRecognized() {
        for command in WritingHelp.voiceCommands {
            let (text, _) = VoiceStructureParser.apply("\(command). Something.", into: "", atUTF16: 0)
            #expect(!text.lowercased().contains(command.lowercased()),
                    "“\(command)” was inserted as literal text instead of being treated as a command")
        }
    }

    // MARK: The three ways in must agree

    /// Tap, type, and speak must offer the *same* structures. If the Style menu ever grows an option
    /// the typed reference does not cover, a writer learns a structure in one surface that appears
    /// not to exist in the other.
    @Test func theStyleMenuAndTheTypingReferenceCoverTheSameStructures() {
        let typed = Set(WritingHelp.typingMarkers.map(\.marker))
        // Paragraph is the exception by definition: it is the absence of a marker, so it can be tapped
        // but has nothing to type.
        let tappable = BlockStyle.allCases.filter { $0 != .paragraph }
        for style in tappable {
            #expect(typed.contains(style.kind.marker),
                    "\(style.name) can be tapped but the typing reference never teaches it")
        }
        #expect(typed.count == tappable.count,
                "the typing reference teaches a marker the Style menu cannot apply")
    }

    /// The menu's names are the sheet's names. Two labels for one structure is how "Bullet list" and
    /// "Bullets" end up in the same app.
    @Test func theStyleMenuNamesMatchTheTypingReference() {
        let namesByMarker = Dictionary(uniqueKeysWithValues:
            WritingHelp.typingMarkers.map { ($0.marker, $0.name) })
        for style in BlockStyle.allCases where style != .paragraph {
            let reference = namesByMarker[style.kind.marker] ?? "nothing"
            #expect(reference == style.name,
                    "the menu calls it \(style.name), the reference calls it \(reference)")
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
