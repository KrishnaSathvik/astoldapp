import Testing
import Foundation
import UIKit
@testable import Yourly

/// What the styler writes onto the text storage. Attributes only — never characters — so these also
/// stand as the check that styling a note never edits it.
@MainActor
struct LinkStylingTests {

    private func styled(_ source: String, underlinesLinks: Bool = false) -> NSTextStorage {
        let storage = NSTextStorage(string: source)
        StructuredTextStyler.apply(to: storage,
                                   textColor: .label,
                                   linkColor: .systemTeal,
                                   underlinesLinks: underlinesLinks)
        return storage
    }

    @Test func stylingNeverChangesTheCharacters() {
        let source = "Go to [Open reservation](https://astold.app) now\n```\n# code\n```"
        #expect(styled(source).string == source)
    }

    @Test func aLinksSyntaxIsHiddenAndItsWordsAreNot() {
        let storage = styled("Go [there](https://astold.app)")
        // "[" at 3 is hidden; "there" at 4..8 is not; "](https://astold.app)" is hidden.
        #expect(storage.attribute(.astHiddenMarker, at: 3, effectiveRange: nil) as? Bool == true)
        #expect(storage.attribute(.astHiddenMarker, at: 4, effectiveRange: nil) == nil)
        #expect(storage.attribute(.astHiddenMarker, at: 9, effectiveRange: nil) as? Bool == true)
    }

    @Test func theWordsCarryTheDestinationForTheTap() {
        let storage = styled("Go [there](https://astold.app)")
        #expect(storage.attribute(.astLink, at: 5, effectiveRange: nil) as? String == "https://astold.app")
        #expect(storage.attribute(.astLink, at: 0, effectiveRange: nil) == nil)
    }

    @Test func theWordsTakeTheLinkColour() {
        let storage = styled("Go [there](https://astold.app)")
        #expect(storage.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? UIColor == .systemTeal)
        #expect(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .label)
    }

    @Test func aBareURLIsStyledLikeAnyOtherLink() {
        let storage = styled("Go https://astold.app")
        #expect(storage.attribute(.astLink, at: 4, effectiveRange: nil) as? String == "https://astold.app")
        // Nothing of it is hidden — every character is the reader's.
        #expect(storage.attribute(.astHiddenMarker, at: 3, effectiveRange: nil) == nil)
    }

    @Test func colourIsNotTheOnlySignalWhenTheReaderAsksForMore() {
        // Differentiate Without Color: the words gain an underline as well as the colour (RULES.md §4).
        let plain = styled("Go [there](https://astold.app)")
        #expect(plain.attribute(.underlineStyle, at: 5, effectiveRange: nil) == nil)

        let underlined = styled("Go [there](https://astold.app)", underlinesLinks: true)
        #expect(underlined.attribute(.underlineStyle, at: 5, effectiveRange: nil) as? Int
                == NSUnderlineStyle.single.rawValue)
    }

    @Test func restylingTwiceLeavesNoStaleLinkAttributes() {
        let storage = NSTextStorage(string: "Go [there](https://astold.app)")
        StructuredTextStyler.apply(to: storage, textColor: .label, linkColor: .systemTeal)
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: "just words")
        StructuredTextStyler.apply(to: storage, textColor: .label, linkColor: .systemTeal)

        var found = false
        storage.enumerateAttribute(.astLink, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if value != nil { found = true }
        }
        #expect(!found)
    }
}

@MainActor
struct CodeStylingTests {

    private func styled(_ source: String, codeCards: [ClosedRange<Int>: CGFloat] = [:]) -> NSTextStorage {
        let storage = NSTextStorage(string: source)
        StructuredTextStyler.apply(to: storage, textColor: .label, codeCards: codeCards)
        return storage
    }

    private let source = "Try\n```python\nx = 1\n```"

    @Test func editingHidesTheFencesAndKeepsTheCodeLookingLikeCode() {
        // Amended 2026-08-24: a block being edited no longer shows ```` ```python ````. The fences are
        // storage, like a table's rule row, and a reader should never have to look past them — so the
        // block keeps its ground and its monospaced face while only the fence lines lose their glyphs.
        let storage = styled(source)
        #expect(storage.attribute(.astCodeBlock, at: 6, effectiveRange: nil) != nil)
        let font = storage.attribute(.font, at: 18, effectiveRange: nil) as? UIFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)

        // The opening fence has no glyphs…
        #expect(storage.attribute(.astHiddenMarker, at: 4, effectiveRange: nil) as? Bool == true)
        // …and neither has the closing one.
        let closing = StructuredText.characterRange(ofLines: 3...3, in: source as NSString)!
        #expect(storage.attribute(.astHiddenMarker, at: closing.location, effectiveRange: nil) as? Bool == true)
        // …but every character of the code is still drawn, because it is what is being typed into.
        let code = StructuredText.characterRange(ofLines: 2...2, in: source as NSString)!
        for offset in code.location..<NSMaxRange(code) {
            #expect(storage.attribute(.astHiddenMarker, at: offset, effectiveRange: nil) == nil,
                    "character \(offset) of the code was hidden")
        }
        #expect(storage.string == source)
    }

    @Test func anEmptyBlockKeepsItsFencesOnScreen() {
        // Hiding both fences of a block with nothing in it would leave an empty strip the writer
        // cannot identify or find their way into.
        let storage = styled("```\n```")
        #expect(storage.attribute(.astHiddenMarker, at: 0, effectiveRange: nil) == nil)
    }

    @Test func readingHidesEveryLineOfTheBlock() {
        let storage = styled(source, codeCards: [1...3: 120])
        for offset in [4, 14, 20] {
            #expect(storage.attribute(.astHiddenMarker, at: offset, effectiveRange: nil) as? Bool == true,
                    "line at \(offset) still had glyphs while the card was drawn")
        }
        // The prose above it is untouched.
        #expect(storage.attribute(.astHiddenMarker, at: 0, effectiveRange: nil) == nil)
    }

    @Test func theBlockBeingEditedIsStyledEvenWhileAnotherIsACard() {
        // Per-block editing means one block gives up its card while the others keep theirs — so the
        // styler is asked to draw *both* presentations in one pass. A note with a second code block in
        // it must not cost the block being edited its monospace face, its ground, or its recessed
        // fences: that is the presentation the writer is editing in.
        let two = "```\na\n```\nprose\n```\nb\n```"        // lines 0...2, prose, lines 4...6
        let storage = styled(two, codeCards: [4...6: 120])     // the second block is a card

        let inA = (two as NSString).range(of: "a").location
        #expect(storage.attribute(.astCodeBlock, at: inA, effectiveRange: nil) != nil,
                "the edited block lost its ground because another block was a card")
        let font = storage.attribute(.font, at: inA, effectiveRange: nil) as? UIFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true,
                "the edited block lost its monospace face because another block was a card")
        // And the block that is a card is still hidden.
        #expect(storage.attribute(.astHiddenMarker,
                                  at: (two as NSString).range(of: "b").location,
                                  effectiveRange: nil) as? Bool == true)
    }

    @Test func aCodeLineIsNeverGivenAListIndent() {
        // `- item` inside a fence is a YAML item; giving it the *list* indent would style it as the
        // bullet it is not. It takes the **code** inset instead, which is what sits it where the card
        // draws it — a different number for a different reason, and the two must not be confused.
        let storage = styled("```yaml\n- item\n```")
        let paragraph = storage.attribute(.paragraphStyle, at: 9, effectiveRange: nil) as? NSParagraphStyle
        #expect(paragraph?.firstLineHeadIndent != StructuredTextStyle.listIndent,
                "a fenced line was indented as a list item")
        #expect(paragraph?.firstLineHeadIndent == CodeCardLayout.Metrics.cardInsetH)
        // …and a real bullet outside any fence still gets the list indent.
        let list = styled("- item")
        let bullet = list.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(bullet?.firstLineHeadIndent == StructuredTextStyle.listIndent)
    }
}

/// The card's arithmetic, which is the part that has to hold at a width nobody thought of.
struct CodeCardLayoutTests {

    @Test func aBlockReservesRoomForEveryLineItHas() {
        let block = CodeBlock.blocks(in: "```\na\nb\nc\n```").first!
        let one = CodeCardLayout.layout(for: CodeBlock.blocks(in: "```\na\n```").first!, availableWidth: 320)!
        let three = CodeCardLayout.layout(for: block, availableWidth: 320)!
        #expect(three.size.height > one.size.height)
    }

    @Test func aLongLineMakesTheCardScrollRatherThanGrow() {
        let long = String(repeating: "x = someVeryLongFunctionName(argument) ", count: 6)
        let block = CodeBlock.blocks(in: "```\n\(long)\n```").first!
        let layout = CodeCardLayout.layout(for: block, availableWidth: 320)!
        #expect(layout.size.width == 320)          // the card is the page's width
        #expect(layout.codeWidth > 320)            // the code is wider
        #expect(layout.scrolls)
    }

    @Test func aShortBlockDoesNotScroll() {
        let block = CodeBlock.blocks(in: "```\nx = 1\n```").first!
        #expect(CodeCardLayout.layout(for: block, availableWidth: 320)?.scrolls == false)
    }

    @Test func thereIsNoLayoutBeforeThereIsAWidth() {
        let block = CodeBlock.blocks(in: "```\nx\n```").first!
        #expect(CodeCardLayout.layout(for: block, availableWidth: 0) == nil)
    }

    @Test func anEmptyBlockStillReservesACard() {
        // A block that vanished while it was being filled would look broken.
        let block = CodeBlock.blocks(in: "```\n```").first!
        #expect((CodeCardLayout.layout(for: block, availableWidth: 320)?.size.height ?? 0) > 0)
    }
}
