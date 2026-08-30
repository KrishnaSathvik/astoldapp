import Testing
import Foundation
@testable import Yourly

/// High-confidence code detection — the one amendment to "never infer structure from prose"
/// (RULES.md §4, amended 2026-08-24).
///
/// The two halves of this suite are not equal. Missing a snippet costs the writer one tap on
/// **Paste as Code**; fencing a paragraph puts backticks in `body` that nobody typed and turns a note
/// into a card. So the negative half is the one that matters, and it is deliberately the larger.
struct CodeDetectionTests {

    // MARK: What it must recognise

    @Test func obviousPython() {
        let match = CodeDetection.detect("""
        import pandas as pd

        df = pd.DataFrame({"x": [1, 2, 3]})
        """)
        #expect(match?.language == "python")
    }

    @Test func aPythonFunction() {
        #expect(CodeDetection.detect("def hello(name):\n    print(name)")?.language == "python")
    }

    @Test func obviousSQL() {
        let match = CodeDetection.detect("SELECT *\nFROM Employee\nWHERE id = 10;")
        #expect(match?.language == "sql")
    }

    @Test func obviousJavaScript() {
        let match = CodeDetection.detect("""
        function greet(name) {
          console.log(`hi ${name}`);
        }
        """)
        #expect(match?.language == "javascript")
    }

    @Test func obviousSwift() {
        let match = CodeDetection.detect("""
        func total(of items: [Int]) -> Int {
            items.reduce(0, +)
        }
        """)
        #expect(match?.language == "swift")
    }

    @Test func obviousJSONIsProvedRatherThanGuessed() {
        #expect(CodeDetection.detect("{\n  \"x\": 1,\n  \"y\": [2, 3]\n}")?.language == "json")
        // …and text that merely has braces does not parse, so it is not JSON.
        #expect(CodeDetection.detect("{ this is not json at all }")?.language != "json")
    }

    @Test func obviousBash() {
        #expect(CodeDetection.detect("#!/bin/bash\nset -euo pipefail\necho hi")?.language == "bash")
        #expect(CodeDetection.detect("npm install --save-dev vitest\nnpm run test")?.language == "bash")
    }

    @Test func everyDetectedLanguageCanActuallyBeColoured() {
        // A label with no colour behind it is worse than leaving the text alone.
        let samples = ["def f():\n    pass",
                       "SELECT a\nFROM b\nWHERE c = 1;",
                       "{\n  \"a\": 1\n}",
                       "#!/bin/sh\ncd /tmp"]
        for sample in samples {
            guard let match = CodeDetection.detect(sample) else { continue }
            #expect(CodeHighlighting.language(named: match.language) != nil,
                    "\(match.language) is detected but cannot be coloured")
            #expect(CodeHighlighting.displayName(for: match.language) != nil)
        }
    }

    // MARK: What it must NOT touch — the half that matters

    /// Ordinary notes. Not one of these may become a code block.
    private let prose = [
        "Call Ravi about the deck tomorrow.",
        "Groceries:\n- milk\n- eggs\n- coffee",
        "Meeting at 3: go over the Q4 numbers with the team.",
        "I'm building — this → that",
        "I’m testing – everything",
        "తెలుగు లో ఒక చిన్న గమనిక",
        "हिन्दी में एक नोट",
        "Booking is at https://astold.app for three nights.",
        "Ideas\n\nThe first one is about onboarding. The second is about search.",
        "# Shopping\n- [ ] passport\n- [x] tickets",
        "| Base | Nights |\n| --- | --- |\n| Anchorage | 3 |",
        "Pros: cheaper, faster.\nCons: less control, more setup.",
        "Ravi said: let's ship it on Friday and see what happens.",
        "TODO: fix the thing\nTODO: ask about the other thing",
        "Rent: 1200\nUtilities: 90\nInternet: 60",
        "select the best option from the menu and let me know",
        "The function of this team is to import ideas from other groups.",
        "3 x 4 = 12, and 5 + 6 = 11.",
        "See you at 5:30 — bring the notes.",
    ]

    @Test func noOrdinaryNoteIsEverFenced() {
        for sample in prose {
            let match = CodeDetection.detect(sample)
            #expect(match == nil,
                    "\(String(reflecting: sample)) was detected as \(match?.language ?? "?") via \(match?.evidence ?? [])")
        }
    }

    @Test func aFlatListOfColonsIsNeverYAML() {
        // The most dangerous false positive of all: this is what half the notes in the world look
        // like, and As Told already renders `- item` as the list the writer meant.
        #expect(CodeDetection.detect("Name: Krishna\nCity: Dallas\nRole: builder") == nil)
        #expect(CodeDetection.detect("- milk\n- eggs\n- coffee") == nil)
    }

    @Test func realYAMLNeedsAMarkerOrRealNesting() {
        #expect(CodeDetection.detect("---\nname: as-told\nversion: 1")?.language == "yaml")
        #expect(CodeDetection.detect("build:\n  os: macos\n  xcode: 26")?.language == "yaml")
    }

    @Test func oneLineIsNotAProgramUnlessItCouldBeNothingElse() {
        // A lone line with only supporting evidence is left alone…
        #expect(CodeDetection.detect("const x = 1;") == nil)
        // …but a decisive signature stands on its own.
        #expect(CodeDetection.detect("SELECT name FROM users WHERE id = 3;")?.language == "sql")
    }

    @Test func englishThatHappensToUseKeywordsStaysEnglish() {
        for sample in ["We should select a vendor and update the set of requirements.",
                       "Import the data from the old system, then delete the from-field.",
                       "The class starts at noon; return the form to the office."] {
            #expect(CodeDetection.detect(sample) == nil, "\(sample) was fenced")
        }
    }

    @Test func theProseGuardOverrulesScore() {
        // Dense punctuation, but sentences — technical writing is still writing.
        let writing = """
        The function() call is expensive, so we cache it.
        We then compare {a, b} against the previous set of values.
        If the result differs, we log it and continue with the next item.
        """
        #expect(CodeDetection.detect(writing) == nil)
    }

    @Test func emptyAndTinyInputAreLeftAlone() {
        for sample in ["", " ", "\n\n", "x", "ok"] {
            #expect(CodeDetection.detect(sample) == nil)
        }
    }
}

/// Detection as the paste path actually uses it.
struct DetectedPasteTests {

    private func pasted(_ clipboard: String) -> String? {
        guard let match = CodeDetection.detect(clipboard) else { return nil }
        return DocumentAction.pasteAsCodeEdit(clipboard, language: match.language,
                                              text: "", selection: NSRange(location: 0, length: 0))?
            .applied(to: "").text
    }

    @Test func detectedCodeLandsAsALabelledBlock() {
        let out = pasted("SELECT *\nFROM Employee\nWHERE id = 10;") ?? ""
        let block = CodeBlock.blocks(in: out).first
        #expect(block?.language == "sql")
        #expect(block?.codeLines == ["SELECT *", "FROM Employee", "WHERE id = 10;"])
        #expect(CodeHighlighting.displayName(for: block?.language) == "SQL")
        let language = CodeHighlighting.language(named: block?.language)!
        let spans = CodeHighlighting.spans(in: block?.code ?? "", language: language)
        #expect(!spans.isEmpty)
    }

    @Test func everyCharacterOfTheClipboardStillSurvives() {
        let messy = "def f():\n    if x:\n\n        return 1"
        #expect(CodeBlock.blocks(in: pasted(messy) ?? "").first?.code == messy)
    }

    @Test func detectionReusesTheSameBoundaryAndCaretRules() {
        // The fence opens its own line and the caret lands outside the block — the rules Paste as
        // Code already had, not a second insertion path.
        let clipboard = "SELECT *\nFROM users;"
        let edit = DocumentAction.pasteAsCodeEdit(clipboard, language: "sql",
                                                  text: "Notes", selection: NSRange(location: 5, length: 0))
        let result = edit!.applied(to: "Notes")
        #expect(result.text.hasPrefix("Notes\n```sql\n"))
        let caretLine = StructuredText.lineIndex(of: result.selection.location, in: result.text as NSString)
        #expect(CodeBlock.blocks(in: result.text).first?.lineRange.contains(caretLine) == false)
    }

    @Test func pasteAsCodeStillStatesNoLanguage() {
        // The manual verb is unchanged: it fences, and it names nothing, because nobody named one.
        let out = DocumentAction.pasteAsCodeEdit("SELECT * FROM users;", text: "",
                                                 selection: NSRange(location: 0, length: 0))?
            .applied(to: "").text ?? ""
        #expect(CodeBlock.blocks(in: out).first?.language == nil)
    }
}
