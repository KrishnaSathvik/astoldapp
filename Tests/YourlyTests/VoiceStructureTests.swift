import Foundation
import Testing
@testable import Yourly

// Slice 5: conservative voice structure command parsing on top of the shared operations.

struct VoiceStructureVerbatimTests {
    @Test func noCommandInsertsVerbatim() {
        let (text, _) = VoiceStructureParser.apply("Hello world.", into: "", atUTF16: 0)
        #expect(text == "Hello world.")
    }

    @Test func preservesModelNewlinesWhenNoCommand() {
        let (text, _) = VoiceStructureParser.apply("Line one.\nLine two.", into: "", atUTF16: 0)
        #expect(text == "Line one.\nLine two.")
    }

    @Test func inlinePhraseNotAtSentenceStartStaysLiteral() {
        let (text, _) = VoiceStructureParser.apply("I want a new paragraph here.", into: "", atUTF16: 0)
        #expect(text == "I want a new paragraph here.")
    }

    @Test func standaloneCommandWordFollowedByContentStaysLiteral() {
        // "Heading north" — "heading" is not followed by a terminator, so it is ordinary speech.
        let (text, _) = VoiceStructureParser.apply("Heading north on the highway.", into: "", atUTF16: 0)
        #expect(text == "Heading north on the highway.")
    }
}

struct VoiceStructureCommandTests {
    @Test func headingThenParagraph() {
        let (text, _) = VoiceStructureParser.apply(
            "Heading. Why winter feels different. New paragraph. I visited in January.",
            into: "", atUTF16: 0
        )
        #expect(text == "# Why winter feels different.\n\nI visited in January.")
    }

    @Test func checklistWithNextItems() {
        let (text, _) = VoiceStructureParser.apply(
            "Checklist. Finish screenshots. Next item privacy page. Next item TestFlight.",
            into: "", atUTF16: 0
        )
        #expect(text == "- [ ] Finish screenshots.\n- [ ] privacy page.\n- [ ] TestFlight.")
    }

    @Test func bulletList() {
        let (text, _) = VoiceStructureParser.apply(
            "Bullet list. Milk. Next item eggs.", into: "", atUTF16: 0
        )
        #expect(text == "- Milk.\n- eggs.")
    }

    @Test func numberedListIncrements() {
        let (text, _) = VoiceStructureParser.apply(
            "Numbered list. Anchorage. Next item Seward.", into: "", atUTF16: 0
        )
        #expect(text == "1. Anchorage.\n2. Seward.")
    }

    @Test func newLineCommand() {
        let (text, _) = VoiceStructureParser.apply("First. New line. Second.", into: "", atUTF16: 0)
        #expect(text == "First.\nSecond.")
    }

    @Test func endListReturnsToParagraph() {
        let (text, _) = VoiceStructureParser.apply(
            "Checklist. Milk. End list. Just text.", into: "", atUTF16: 0
        )
        #expect(text == "- [ ] Milk.\nJust text.")
    }

    @Test func subheadingCommand() {
        let (text, _) = VoiceStructureParser.apply("Subheading. What to pack.", into: "", atUTF16: 0)
        #expect(text == "## What to pack.")
    }

    // Real speech does not end a command on a single tidy period: the model transcribes "new
    // paragraph..." or "heading…". The punctuation belongs to the command token, and MUST NOT be left
    // behind as stray dots in the note.

    @Test func trailingEllipsisBelongsToTheCommand() {
        let (text, _) = VoiceStructureParser.apply(
            "New paragraph... I visited in January.", into: "Intro.", atUTF16: 6
        )
        #expect(text == "Intro.\n\nI visited in January.")
    }

    @Test func aSingleEllipsisCharacterBelongsToTheCommand() {
        let (text, _) = VoiceStructureParser.apply("Heading… Why I like Alaska.", into: "", atUTF16: 0)
        #expect(text == "# Why I like Alaska.")
    }

    @Test func anExclaimedCommandStillEndsCleanly() {
        let (text, _) = VoiceStructureParser.apply("Checklist! Finish screenshots.", into: "", atUTF16: 0)
        #expect(text == "- [ ] Finish screenshots.")
    }

    @Test func punctuationRunsNeverSwallowTheWordsAfterThem() {
        let (text, _) = VoiceStructureParser.apply("New paragraph. Hello.", into: "Intro.", atUTF16: 6)
        #expect(text == "Intro.\n\nHello.")
    }

    @Test func insertsIntoExistingBodyAtCaret() {
        // Existing paragraph, caret at end; a heading command starts a fresh line.
        let body = "Intro."
        let (text, _) = VoiceStructureParser.apply("Heading. Section.", into: body, atUTF16: (body as NSString).length)
        #expect(text == "Intro.\n# Section.")
    }
}
