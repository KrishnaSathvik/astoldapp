import Testing
import Foundation
import UIKit
@testable import Yourly

/// The preformatted card: what it says it is, what it copies, and what a screen reader is told.
///
/// It is the **same card** as a code block's, deliberately — same ground, same monospaced face, same
/// sideways scroll, same one-tap copy. A directory tree and a function body need identical treatment
/// (do not touch these characters, do not let them wrap), and building a second card would have meant a
/// second layout, a second presenter, and two things to keep in step forever. What differs is the two
/// things that are actually different: the word in the header, and the absence of syntax colour.
@MainActor
struct PreformattedCardTests {

    private let tree = """
    sponsor-intelligence/
    │
    ├── apps/
    │   └── api/
    """

    private func card(_ text: String, language: String?) -> CodeBlockView {
        let lines = text.components(separatedBy: "\n")
        let block = CodeBlock(language: language, lineRange: 0...(lines.count + 1), codeLines: lines)
        let layout = CodeCardLayout.layout(for: block, availableWidth: 353)!
        let view = CodeBlockView(block: block, layout: layout, palette: .ds)
        view.frame = CGRect(origin: .zero, size: layout.size)
        view.layoutIfNeeded()
        return view
    }

    // MARK: The header

    @Test func theHeaderSaysPlainText() {
        // Not `text`, which is the fence's spelling and is storage a reader should never see.
        #expect(card(tree, language: "text").drawnLanguage == "Plain text")
        #expect(card(tree, language: "plaintext").drawnLanguage == "Plain text")
        #expect(card(tree, language: "txt").drawnLanguage == "Plain text")
    }

    @Test func aCodeBlockIsUnaffected() {
        #expect(card("SELECT 1", language: "sql").drawnLanguage == "SQL")
        #expect(card("SELECT 1", language: nil).drawnLanguage == nil)
    }

    // MARK: No colour

    @Test func aDiagramIsDrawnInExactlyOneColour() {
        // `text` is not a language the highlighter knows, so there are no spans to apply. A diagram
        // coloured as if it were code would be As Told claiming to understand it, which it does not.
        let view = card("SELECT │ FROM ▼ WHERE", language: "text")
        var colours: Set<UIColor> = []
        let attributed = view.drawnCode ?? NSAttributedString()
        attributed.enumerateAttribute(.foregroundColor,
                                      in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let colour = value as? UIColor { colours.insert(colour) }
        }
        #expect(colours.count == 1)
    }

    @Test func drawingADiagramNeverChangesItsCharacters() {
        #expect(card(tree, language: "text").drawnCode?.string == tree)
    }

    // MARK: Copy

    @Test func copyPutsTheCharactersOnTheClipboardWithoutFences() {
        let view = card(tree, language: "text")
        UIPasteboard.general.string = ""
        view.copyCode()
        #expect(UIPasteboard.general.string == tree)
        #expect(UIPasteboard.general.string?.contains("```") == false)
    }

    @Test func copyPreservesEverySpaceAndBoxCharacter() {
        let awkward = "A\n    │\n ┌──┼──┐\n ▼  ▼  ▼"
        let view = card(awkward, language: "text")
        UIPasteboard.general.string = ""
        view.copyCode()
        #expect(UIPasteboard.general.string == awkward)
    }

    // MARK: Reading it aloud

    @Test func aScreenReaderIsToldItIsPlainTextNotCode() {
        // "Code block, Plain text" would be two contradictory claims in one sentence.
        #expect(card(tree, language: "text").drawnCodeAccessibilityLabel == "Plain text block")
    }

    @Test func aCodeBlocksAnnouncementIsUnchanged() {
        #expect(card("x", language: "sql").drawnCodeAccessibilityLabel == "Code block, SQL")
        #expect(card("x", language: nil).drawnCodeAccessibilityLabel == "Code block")
    }
}
