import Testing
import Foundation
import SwiftData
@testable import Yourly

/// Two defects found by typing every marker path through the real editor (2026-08-19).
///
/// Both are about *input tolerance*, not new syntax: As Told still has exactly one bullet marker and
/// exactly two heading levels (RULES.md §7 — no Markdown aliases). What changes is that a writer who
/// types a capital `X`, or who changes their mind on a freshly continued list line, gets what they
/// obviously meant instead of literal text.
@Suite struct CheckedChecklistToleranceTests {

    @Test func lowercaseXIsACheckedItem() {
        let (kind, len) = BlockKind.parse(line: "- [x] done")
        #expect(kind == .checklist(checked: true))
        #expect(len == 6)
    }

    /// iOS autocapitalization is on by default, and `[X]` is what a hand reaches for anyway. Rejecting
    /// it turned a checked item into a bullet whose visible text was "[X] done".
    @Test func uppercaseXIsAlsoACheckedItem() {
        let (kind, len) = BlockKind.parse(line: "- [X] done")
        #expect(kind == .checklist(checked: true))
        #expect(len == 6)
    }

    @Test func uppercaseXHidesItsMarkerLikeAnyOther() {
        #expect(MarkupDocument("- [X] done").visibleText() == "done")
    }

    /// Tolerance on the way in, one representation on the way out: `[X]` must never become a second
    /// stored format that every later operation has to understand.
    @Test func canonicalSourceRewritesUppercaseToLowercase() {
        #expect(StructuredText.canonicalized("- [X] done") == "- [x] done")
    }

    @Test func canonicalSourceRewritesEveryUppercaseLine() {
        let source = "- [X] one\n- [x] two\n- [X] three"
        #expect(StructuredText.canonicalized(source) == "- [x] one\n- [x] two\n- [x] three")
    }

    /// Same UTF-16 length, so a caret held anywhere in the note stays exactly where it was. This is
    /// what makes it safe to canonicalize on save while an editor is still open.
    @Test func canonicalizingPreservesLength() {
        let source = "- [X] done\nplain"
        #expect((StructuredText.canonicalized(source) as NSString).length == (source as NSString).length)
    }

    @Test func canonicalSourceLeavesEverythingElseAlone() {
        let source = "# Heading\n## Sub\n- bullet\n1. one\n- [ ] open\nplain [X] text\n007. odd"
        #expect(StructuredText.canonicalized(source) == source)
    }

    /// `[X]` mid-line is ordinary prose, not a marker.
    @Test func uppercaseXAwayFromLineStartIsUntouched() {
        #expect(StructuredText.canonicalized("rated - [X] overall") == "rated - [X] overall")
    }
}

/// Return creates an empty marker; typing a different complete marker there should *replace* it.
/// Before this, continuing a bullet and then typing "1. " produced `- 1. ` — a bullet whose text is
/// "1. ", which reads as broken even though it is literally consistent.
@Suite struct EmptyMarkerReplacementTests {

    /// The caret sits at the end of the line being typed on — where Return left it, plus whatever
    /// partial marker has been typed since.
    private func caretAtEndOfLastLine(_ text: String) -> NSRange {
        let line = MarkupDocument(text).lines.last!
        return NSRange(location: line.sourceRange.location + line.sourceRange.length, length: 0)
    }

    private func typing(_ char: String, into text: String) -> (text: String, selection: NSRange)? {
        guard let edit = DocumentAction.markerReplacementEdit(
            text: text, selection: caretAtEndOfLastLine(text), replacementText: char
        ) else { return nil }
        return edit.applied(to: text)
    }

    @Test func bulletBecomesNumbered() {
        // "- milk\n- " with the caret after the empty marker; the writer types the space of "1. ".
        let result = typing(" ", into: "- milk\n- 1.")
        #expect(result?.text == "- milk\n1. ")
    }

    @Test func bulletBecomesHeading() {
        #expect(typing(" ", into: "- milk\n- #")?.text == "- milk\n# ")
    }

    @Test func bulletBecomesChecklist() {
        // "- " alone is a bullet-to-bullet no-op and is deliberately not swapped, which is exactly
        // what lets the writer keep typing "[ ] " and land on a checklist.
        #expect(typing(" ", into: "- milk\n- - [ ]")?.text == "- milk\n- [ ] ")
    }

    @Test func numberedBecomesBullet() {
        #expect(typing(" ", into: "1. one\n2. -")?.text == "1. one\n- ")
    }

    @Test func caretLandsAfterTheNewMarker() {
        let result = typing(" ", into: "- milk\n- 1.")
        #expect(result?.selection == NSRange(location: (("- milk\n1. ") as NSString).length, length: 0))
    }

    /// The rule is restricted to an *otherwise empty* structured line. A line with real words is the
    /// writer's content and must never be rewritten under them.
    @Test func aLineWithContentIsNeverRewritten() {
        #expect(typing(" ", into: "- milk\n- eggs 1.") == nil)
    }

    @Test func sameKindIsNotSwapped() {
        // Typing "- " on an empty bullet line changes nothing, so it must not cost an undo step.
        #expect(typing(" ", into: "- milk\n- -") == nil)
    }

    @Test func aPlainParagraphIsNotAffected() {
        // No marker to replace — "# " here is the ordinary way to start a heading on a blank line.
        #expect(typing(" ", into: "#") == nil)
    }

    @Test func anIncompleteMarkerIsJustTyping() {
        // "1" is not yet a marker; it stays as content until the writer completes it.
        #expect(typing("1", into: "- milk\n- ") == nil)
    }

    @Test func aliasesAreStillNotMarkers() {
        // Deliberately unsupported (RULES.md §7): "* " and "### " stay literal here too.
        #expect(typing(" ", into: "- milk\n- *") == nil)
        #expect(typing(" ", into: "- milk\n- ###") == nil)
    }
}

/// The contract end to end: tolerated on the way in, canonical on the way out.
@MainActor
@Suite struct CheckedChecklistPersistenceTests {

    @Test func savingRewritesUppercaseToTheCanonicalMarker() throws {
        let container = try NoteStoreContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Shopping", body: "- [X] milk\n- [ ] eggs")
        context.insert(note)

        let model = EditorModel(note: note, context: context)
        model.finish()

        #expect(note.body == "- [x] milk\n- [ ] eggs")
    }

    @Test func aNoteWithNothingToNormalizeIsLeftAlone() throws {
        let container = try NoteStoreContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Shopping", body: "- [x] milk")
        context.insert(note)

        let model = EditorModel(note: note, context: context)
        model.finish()

        #expect(note.body == "- [x] milk")
    }
}

/// "Strict storage, forgiving input." A keyboard that substitutes a smart dash or a non-breaking
/// space must not silently cost the writer their structure — but prose must never be rewritten to
/// buy that, which is the line every test below defends.
@Suite struct StructuralPrefixNormalizationTests {

    // MARK: What gets fixed

    @Test func smartDashesBecomeABullet() {
        for dash in ["\u{2013}", "\u{2014}", "\u{2212}", "\u{2010}"] {
            #expect(StructuredText.normalizedStructuralPrefix("\(dash) milk") == "- milk")
        }
    }

    @Test func nonBreakingSpacesBecomeAMarkerSpace() {
        #expect(StructuredText.normalizedStructuralPrefix("#\u{00A0}Trip") == "# Trip")
        #expect(StructuredText.normalizedStructuralPrefix("-\u{202F}milk") == "- milk")
    }

    @Test func aSubstitutedChecklistIsRecovered() {
        #expect(StructuredText.normalizedStructuralPrefix("\u{2013} [X] done") == "- [x] done")
    }

    // MARK: What must never be touched

    /// The headline case: an en dash inside a sentence is punctuation, not a marker.
    @Test func proseKeepsItsEnDash() {
        #expect(StructuredText.normalizedStructuralPrefix("I worked 9\u{2013}5 today.")
                == "I worked 9\u{2013}5 today.")
    }

    /// A line may *begin* with a dash and still be prose — it only normalizes if the result is a
    /// real marker, and "—she said" never is.
    @Test func aDashRunOnIsNotAMarker() {
        #expect(StructuredText.normalizedStructuralPrefix("\u{2014}she said") == "\u{2014}she said")
    }

    @Test func capitalLettersOutsideACheckboxSurvive() {
        #expect(StructuredText.normalizedStructuralPrefix("Xylophone practice") == "Xylophone practice")
        #expect(StructuredText.normalizedStructuralPrefix("- [X marker") == "- [X marker")
    }

    @Test func nothingBeyondTheMarkerWindowIsRewritten() {
        let line = "- milk \u{2013} the good kind"
        #expect(StructuredText.normalizedStructuralPrefix(line) == line)
    }

    @Test func normalizationIsLengthPreserving() {
        let line = "\u{2013} [X] done"
        #expect((StructuredText.normalizedStructuralPrefix(line) as NSString).length
                == (line as NSString).length)
    }

    @Test func unsupportedMarkdownIsNotRescuedByNormalization() {
        // Normalizing must not become a back door into aliases (RULES.md §7).
        #expect(StructuredText.normalizedStructuralPrefix("* milk") == "* milk")
        #expect(StructuredText.normalizedStructuralPrefix("### Notes") == "### Notes")
    }

    // MARK: As an edit, at the keystroke that completes the marker

    private func typing(_ char: String, at caret: Int, into text: String) -> String? {
        DocumentAction.prefixNormalizationEdit(
            text: text, selection: NSRange(location: caret, length: 0), replacementText: char
        )?.applied(to: text).text
    }

    @Test func completingASmartDashBulletFixesItInPlace() {
        #expect(typing(" ", at: 1, into: "\u{2013}") == "- ")
    }

    @Test func completingANonBreakingHeadingFixesItInPlace() {
        #expect(typing("\u{00A0}", at: 1, into: "#") == "# ")
    }

    @Test func theEditOnlyFiresAtTheEndOfTheMarker() {
        // Mid-word, long after the prefix — nothing to complete.
        #expect(typing("s", at: 6, into: "\u{2013} milk") == nil)
    }

    @Test func anAlreadyValidMarkerIsLeftAlone() {
        #expect(typing(" ", at: 1, into: "-") == nil)
    }

    @Test func proseIsNeverRewrittenByTheEdit() {
        #expect(typing("5", at: 9, into: "I worked 9\u{2013}") == nil)
    }
}

/// Voice help teaches by example, and the examples have to actually work.
@Suite struct VoiceExampleTests {

    @Test func everyExampleActuallyProducesStructure() {
        for example in WritingHelp.voiceExamples {
            let (body, _) = VoiceStructureParser.apply(example.utterance, into: "", atUTF16: 0)
            let kinds = MarkupDocument(body).lines.map(\.kind)
            #expect(kinds.contains { $0 != .paragraph },
                    "“\(example.utterance)” should produce structure, produced: \(body)")
        }
    }

    @Test func theHeadingExampleMakesAHeading() {
        let (body, _) = VoiceStructureParser.apply("Heading. Alaska plans.", into: "", atUTF16: 0)
        #expect(body.contains(BlockKind.heading.marker))
    }

    @Test func theListExampleMakesMoreThanOneItem() {
        let example = WritingHelp.voiceExamples.first { $0.task == "Make a list" }!
        let (body, _) = VoiceStructureParser.apply(example.utterance, into: "", atUTF16: 0)
        let bullets = MarkupDocument(body).lines.filter { $0.kind == .bullet }
        #expect(bullets.count >= 2, "produced: \(body)")
    }

    @Test func examplesStayShortEnoughToRead() {
        for example in WritingHelp.voiceExamples {
            #expect(example.utterance.count <= 70, "\(example.task) is too long to scan")
        }
    }
}
