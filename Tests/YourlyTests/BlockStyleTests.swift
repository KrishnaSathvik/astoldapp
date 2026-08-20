import Testing
import Foundation
@testable import Yourly

/// The Style menu's model: what it offers, what it reports as current, and what applying it does to
/// more than one line at a time.
///
/// The multi-line cases are the reason this feature needed code rather than wiring. Everything else
/// in the editor acts on the line under the caret; a control a writer taps after selecting four
/// lines has to act on four, and has to do it as one thing they can undo once.
struct BlockStyleTests {

    // MARK: What the menu offers

    /// Six, and the six the product locked (RULES.md §7). A seventh arriving here is the moment the
    /// contextual control starts becoming the formatting ribbon the rules refuse.
    @Test func offersExactlySixStructures() {
        #expect(BlockStyle.allCases == [.paragraph, .heading, .subheading, .bullet, .numbered, .checklist])
    }

    /// Inline formatting is a different category and stays out of V1: no style may name one.
    @Test func offersNoInlineFormatting() {
        let forbidden = ["bold", "italic", "underline", "strikethrough", "highlight", "color", "font"]
        for style in BlockStyle.allCases {
            for word in forbidden {
                #expect(!style.name.lowercased().contains(word),
                        "\(style.name) is inline rich text, which V1 does not ship")
            }
        }
    }

    /// Title case, which is Apple's wording for these rows and the convention the whole menu now keeps
    /// (2026-08-20). One sentence-cased row among five title-cased ones reads as a typo in exactly the
    /// row someone was trying to improve, which is how "Bulleted List" nearly shipped beside
    /// "Numbered list".
    @Test func everyMenuLabelIsTitleCase() {
        for style in BlockStyle.allCases {
            for word in style.name.split(separator: " ") {
                #expect(word.first?.isUppercase == true,
                        "“\(style.name)” is not title case — “\(word)” starts lowercase")
            }
        }
    }

    @Test func everyStyleRoundTripsThroughTheKindItApplies() {
        for style in BlockStyle.allCases {
            #expect(BlockStyle(style.kind) == style)
        }
    }

    /// A style names a structure, not a line's state: item 4 and item 1 are both Numbered List, and a
    /// ticked box is still Checklist. Otherwise the menu could never check the current row.
    @Test func perLineStateDoesNotChangeWhichStyleALineIs() {
        #expect(BlockStyle(.numbered(4)) == .numbered)
        #expect(BlockStyle(.numbered(1)) == .numbered)
        #expect(BlockStyle(.checklist(checked: true)) == .checklist)
        #expect(BlockStyle(.checklist(checked: false)) == .checklist)
    }

    // MARK: What the menu checks

    @Test func currentStyleIsTheStyleOfTheLineUnderTheCaret() {
        #expect(BlockStyle.current(in: "# Alaska", selection: NSRange(location: 3, length: 0)) == .heading)
        #expect(BlockStyle.current(in: "plain", selection: NSRange(location: 0, length: 0)) == .paragraph)
        #expect(BlockStyle.current(in: "- [x] done", selection: NSRange(location: 8, length: 0)) == .checklist)
    }

    @Test func currentStyleIsSharedWhenEverySelectedLineAgrees() {
        let text = "- one\n- two\n- three"
        #expect(BlockStyle.current(in: text, selection: NSRange(location: 0, length: 19)) == .bullet)
    }

    /// A selection covering a heading and a bullet is not any one style, so the menu checks nothing.
    /// Reporting the first line's style would be a checkmark that lies about the other three.
    @Test func currentStyleIsNilWhenTheSelectionMixesStyles() {
        let text = "# Alaska\n- one"
        #expect(BlockStyle.current(in: text, selection: NSRange(location: 0, length: 14)) == nil)
    }

    /// Numbering differs line to line but the style does not, so a numbered list still checks cleanly.
    @Test func aNumberedListReadsAsOneStyleDespiteDifferentNumbers() {
        let text = "1. one\n2. two\n3. three"
        #expect(BlockStyle.current(in: text, selection: NSRange(location: 0, length: 22)) == .numbered)
    }

    // MARK: Multi-line conversion

    @Test func convertingASelectionStylesEveryLineItTouches() {
        let text = "one\ntwo\nthree"
        let r = DocumentAction.setBlockKind(.bullet, text: text,
                                            selection: NSRange(location: 0, length: 13))
        #expect(r.text == "- one\n- two\n- three")
    }

    @Test func convertingASelectionToHeadingsStylesEveryLine() {
        let text = "one\ntwo"
        let r = DocumentAction.setBlockKind(.heading, text: text,
                                            selection: NSRange(location: 0, length: 7))
        #expect(r.text == "# one\n# two")
    }

    @Test func convertingASelectionToAChecklistStylesEveryLine() {
        let text = "milk\neggs"
        let r = DocumentAction.setBlockKind(.checklist(checked: false), text: text,
                                            selection: NSRange(location: 0, length: 9))
        #expect(r.text == "- [ ] milk\n- [ ] eggs")
    }

    /// A partial selection still owns whole lines — you cannot style half a line — but only the lines
    /// it actually reaches.
    @Test func convertingAPartialSelectionStylesOnlyTheLinesItReaches() {
        let text = "one\ntwo\nthree"
        // From inside "one" to inside "two"; "three" is untouched.
        let r = DocumentAction.setBlockKind(.bullet, text: text,
                                            selection: NSRange(location: 2, length: 4))
        #expect(r.text == "- one\n- two\nthree")
    }

    /// A selection ending exactly at a line's start has taken the newline and nothing else. Styling
    /// that line would convert one the writer never selected.
    @Test func aSelectionEndingAtTheNextLineStartDoesNotStyleThatLine() {
        let text = "one\ntwo"
        let r = DocumentAction.setBlockKind(.bullet, text: text,
                                            selection: NSRange(location: 0, length: 4))
        #expect(r.text == "- one\ntwo")
    }

    @Test func convertingBackToNormalStripsEveryMarkerInTheSelection() {
        let text = "# one\n- two\n- [ ] three"
        let r = DocumentAction.setBlockKind(.paragraph, text: text,
                                            selection: NSRange(location: 0, length: 23))
        #expect(r.text == "one\ntwo\nthree")
    }

    /// Mixed structure in, one structure out — the same result as selecting them and typing the
    /// marker on each, which is what the menu is a shortcut for.
    @Test func convertingASelectionOfMixedStylesUnifiesThem() {
        let text = "# one\ntwo\n- [x] three"
        let r = DocumentAction.setBlockKind(.bullet, text: text,
                                            selection: NSRange(location: 0, length: 21))
        #expect(r.text == "- one\n- two\n- three")
    }

    // MARK: Numbering

    @Test func numberingASelectionRunsInSequence() {
        let text = "one\ntwo\nthree"
        let r = DocumentAction.setBlockKind(.numbered(1), text: text,
                                            selection: NSRange(location: 0, length: 13))
        #expect(r.text == "1. one\n2. two\n3. three")
    }

    /// The number is not "1" because the writer asked for a numbered item — it is the next one in the
    /// list they are standing in.
    @Test func numberingContinuesFromTheNumberedLineAbove() {
        let text = "1. one\n2. two\nthree"
        let r = DocumentAction.setBlockKind(.numbered(1), text: text,
                                            selection: NSRange(location: 16, length: 0))
        #expect(r.text == "1. one\n2. two\n3. three")
    }

    @Test func numberingASelectionContinuesFromTheLineAboveInSequence() {
        let text = "5. five\nsix\nseven"
        let r = DocumentAction.setBlockKind(.numbered(1), text: text,
                                            selection: NSRange(location: 8, length: 9))
        #expect(r.text == "5. five\n6. six\n7. seven")
    }

    @Test func numberingRestartsAtOneWhenNothingNumberedPrecedesIt() {
        let text = "- bullet\none\ntwo"
        let r = DocumentAction.setBlockKind(.numbered(1), text: text,
                                            selection: NSRange(location: 9, length: 7))
        #expect(r.text == "- bullet\n1. one\n2. two")
    }

    /// Renumbering an existing run the writer selected is renumbering; touching the items *below* it
    /// is rewriting lines they did not select, which the control must never do.
    @Test func numberingLeavesLinesOutsideTheSelectionAlone() {
        let text = "one\n7. seven"
        let r = DocumentAction.setBlockKind(.numbered(1), text: text,
                                            selection: NSRange(location: 0, length: 3))
        #expect(r.text == "1. one\n7. seven")
    }

    @Test func numberingASelectionOfExistingItemsResequencesThem() {
        let text = "3. one\n9. two\n1. three"
        let r = DocumentAction.setBlockKind(.numbered(1), text: text,
                                            selection: NSRange(location: 0, length: 22))
        #expect(r.text == "1. one\n2. two\n3. three")
    }

    // MARK: Ticked items survive

    /// Tapping Checklist on a list already half worked through must not clear it. The menu shows a
    /// checkmark against the current style, which invites a second tap; a second tap has to be safe.
    @Test func reapplyingChecklistKeepsItemsTicked() {
        let text = "- [x] done\n- [ ] todo"
        let r = DocumentAction.setBlockKind(.checklist(checked: false), text: text,
                                            selection: NSRange(location: 0, length: 21))
        #expect(r.text == text)
    }

    @Test func convertingAwayFromAndBackToAChecklistLosesTheTick() {
        // Not a bug to hide: "- " genuinely has nowhere to keep it. Pinned so the loss stays a
        // deliberate consequence of leaving the structure rather than a surprise.
        let bulleted = DocumentAction.setBlockKind(.bullet, text: "- [x] done",
                                                   selection: NSRange(location: 6, length: 0))
        #expect(bulleted.text == "- done")
        let back = DocumentAction.setBlockKind(.checklist(checked: false), text: bulleted.text,
                                               selection: NSRange(location: 2, length: 0))
        #expect(back.text == "- [ ] done")
    }

    // MARK: One action, one edit, one undo step

    /// The editor registers exactly one undo entry per `TextEdit` it applies, so "one undo step for a
    /// multi-line conversion" is the claim that the conversion is *one* edit — a single contiguous
    /// range covering every line that changed, not one edit per line.
    @Test func aMultiLineConversionIsASingleContiguousEdit() {
        let text = "one\ntwo\nthree"
        let edit = DocumentAction.setBlockKindEdit(.bullet, text: text,
                                                   selection: NSRange(location: 0, length: 13))
        #expect(edit.range == NSRange(location: 0, length: 13))
        #expect(edit.string == "- one\n- two\n- three")
    }

    /// The span starts and ends at the lines that changed — an edit reaching past them would undo
    /// text the writer never converted.
    @Test func theEditSpansOnlyTheConvertedLines() {
        let text = "keep\none\ntwo\nkeep"
        let edit = DocumentAction.setBlockKindEdit(.bullet, text: text,
                                                   selection: NSRange(location: 5, length: 7))
        #expect(edit.range == NSRange(location: 5, length: 7))
        #expect(edit.string == "- one\n- two")
    }

    /// A one-line conversion stays a marker-sized edit rather than rewriting the paragraph around it.
    @Test func aSingleLineConversionReplacesOnlyItsMarker() {
        let edit = DocumentAction.setBlockKindEdit(.heading, text: "- hello",
                                                   selection: NSRange(location: 2, length: 0))
        #expect(edit.range == NSRange(location: 0, length: 2))
        #expect(edit.string == "# ")
    }

    /// Undo is the edit's inverse, so a multi-line conversion must invert to exactly the text and the
    /// selection the writer had before they opened the menu.
    @Test func undoingAMultiLineConversionRestoresTheTextAndTheSelection() {
        let text = "one\ntwo\nthree"
        let before = NSRange(location: 0, length: 13)
        let edit = DocumentAction.setBlockKindEdit(.checklist(checked: false), text: text, selection: before)
        let (converted, _) = edit.applied(to: text)
        #expect(converted == "- [ ] one\n- [ ] two\n- [ ] three")

        let (restored, selection) = edit.inverse(in: text, caret: before).applied(to: converted)
        #expect(restored == text)
        #expect(selection == before)
    }

    // MARK: The selection survives

    /// Converting four lines leaves those four lines selected, so a writer who picked the wrong style
    /// can pick another without reselecting.
    @Test func theSelectionStillCoversTheSameLinesAfterConverting() {
        let text = "one\ntwo\nthree"
        let r = DocumentAction.setBlockKind(.bullet, text: text,
                                            selection: NSRange(location: 0, length: 13))
        #expect(r.text == "- one\n- two\n- three")
        // Same three lines, now six characters longer.
        #expect(r.selection == NSRange(location: 0, length: 19))
    }

    /// A caret is not a selection and must not become one.
    @Test func aCaretStaysACaretAfterConverting() {
        let r = DocumentAction.setBlockKind(.bullet, text: "hello",
                                            selection: NSRange(location: 5, length: 0))
        #expect(r.selection == NSRange(location: 7, length: 0))
    }

    /// The caret is never left inside a hidden marker — an offset that would land there snaps to the
    /// line's first visible character.
    @Test func aCaretAtALineStartLandsAfterTheNewMarker() {
        let r = DocumentAction.setBlockKind(.checklist(checked: false), text: "hello",
                                            selection: NSRange(location: 0, length: 0))
        #expect(r.selection == NSRange(location: 6, length: 0))
    }

    // MARK: The other two ways in are unaffected

    /// Voice calls the same primitive with a caret, and must keep behaving exactly as it did before
    /// the menu existed.
    @Test func aCaretConversionMatchesWhatVoiceAlreadyProduced() {
        let text = "one\ntwo"
        let r = DocumentAction.setBlockKind(.bullet, text: text, selection: NSRange(location: 5, length: 0))
        #expect(r.text == "one\n- two")
    }

    @Test func multiLineEditsMatchTheWholeTextOperation() {
        let text = "one\ntwo\nthree"
        let selection = NSRange(location: 0, length: 13)
        let viaEdit = DocumentAction.setBlockKindEdit(.numbered(1), text: text, selection: selection)
            .applied(to: text)
        let whole = DocumentAction.setBlockKind(.numbered(1), text: text, selection: selection)
        #expect(viaEdit.text == whole.text)
        #expect(viaEdit.selection == whole.selection)
    }
}
