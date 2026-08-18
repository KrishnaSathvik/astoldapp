import Foundation
import Testing
@testable import Yourly

// The manual voice corpus, run as text. Real audio still has to answer "did the model transcribe it this
// way?", but everything downstream of the transcript is pinned here — above all the false positives, which
// are the failures that matter: normal speech MUST NEVER restructure the document (RULES.md §2).

private func spoken(_ transcript: String, into body: String = "", at offset: Int? = nil) -> String {
    VoiceStructureParser.apply(transcript, into: body,
                               atUTF16: offset ?? (body as NSString).length).text
}

struct VoiceCorpusCommandTests {
    @Test func newParagraph() {
        #expect(spoken("New paragraph. I want to write something else.", into: "Before.")
                == "Before.\n\nI want to write something else.")
    }

    @Test func newParagraphWithDots() {
        #expect(spoken("New paragraph... I want to write something else.", into: "Before.")
                == "Before.\n\nI want to write something else.")
    }

    @Test func newParagraphWithAnEllipsis() {
        #expect(spoken("New paragraph… I want to write something else.", into: "Before.")
                == "Before.\n\nI want to write something else.")
    }

    @Test func heading() {
        #expect(spoken("Heading. Alaska trip.") == "# Alaska trip.")
    }

    @Test func subheading() {
        #expect(spoken("Subheading. Where to stay.") == "## Where to stay.")
    }

    @Test func bulletListWithNextItems() {
        #expect(spoken("Bullet list. Anchorage. Next item. Seward. Next item. Denali.")
                == "- Anchorage.\n- Seward.\n- Denali.")
    }

    @Test func checklistWithNextItems() {
        #expect(spoken("Checklist. Call Ravi. Next item. Buy groceries.")
                == "- [ ] Call Ravi.\n- [ ] Buy groceries.")
    }

    @Test func endListReturnsToProse() {
        let list = spoken("Checklist. Call Ravi.")
        #expect(spoken("End list. Another thing I was thinking about…", into: list)
                == "- [ ] Call Ravi.\nAnother thing I was thinking about…")
    }
}

struct VoiceCorpusFalsePositiveTests {
    // Every one of these is ordinary speech. The document MUST come back with the words untouched and no
    // structure applied — a missed command is tolerable, a phantom one is not.

    @Test(arguments: [
        "The phrase new paragraph is annoying.",
        "I told him to add a checklist.",
        "The heading was completely wrong.",
        "Maybe use a bullet list for that.",
        "She said new paragraph and then continued.",
        "Okay, new paragraph.",
        "I don't know, maybe heading back tomorrow makes sense.",
        "My checklist is getting too long.",
        "So yeah um new paragraph... actually I don't know maybe let's talk about something else.",
        "Okay new paragraph, I think Alaska might be better.",
    ])
    func conversationalSpeechStaysLiteral(_ transcript: String) {
        #expect(spoken(transcript) == transcript)
    }

    @Test(arguments: [
        "The phrase new paragraph is annoying.",
        "Okay, new paragraph.",
        "My checklist is getting too long.",
    ])
    func literalSpeechAppendsToAnExistingNoteWithoutStructuring(_ transcript: String) {
        #expect(spoken(transcript, into: "Existing note.") == "Existing note. " + transcript)
    }
}

struct VoiceCorpusCodeSwitchTests {
    // English commands inside natural Telugu/Hindi speech. The non-English words are content and MUST
    // survive exactly (RULES.md §2); only the clearly isolated English command may act.

    @Test func englishCommandInsideTeluguSpeech() {
        #expect(spoken("నాకు ఇంకో idea ఉంది. New paragraph. Maybe మనం Seward లో two nights ఉండచ్చు.")
                == "నాకు ఇంకో idea ఉంది.\n\nMaybe మనం Seward లో two nights ఉండచ్చు.")
    }

    @Test func aCommandWordInsideTeluguSpeechStaysLiteral() {
        // "checklist" here is part of a sentence, not a standalone command.
        let transcript = "ఇక్కడ checklist add చేయాలి."
        #expect(spoken(transcript) == transcript)
    }

    @Test func teluguContentAfterACommandIsUntouched() {
        #expect(spoken("Heading. మనం ఎక్కడ ఉండాలి.") == "# మనం ఎక్కడ ఉండాలి.")
    }
}
