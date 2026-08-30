import Testing
import Foundation
@testable import Yourly

/// Reading a code block back out of `body`, and the one thing that makes code different from every
/// other structure As Told holds: **its characters mean nothing to As Told**.
struct CodeBlockDetectionTests {

    private let python = "```python\ndef hello():\n    print(\"hello\")\n```"

    @Test func aFencedBlockIsFound() {
        let block = CodeBlock.blocks(in: python).first
        #expect(block?.language == "python")
        #expect(block?.lineRange == 0...3)
        #expect(block?.codeLines == ["def hello():", "    print(\"hello\")"])
    }

    @Test func aFenceMayNameNoLanguage() {
        let block = CodeBlock.blocks(in: "```\nplain\n```").first
        #expect(block?.language == nil)
        #expect(block?.codeLines == ["plain"])
    }

    @Test func anUnterminatedFenceIsOrdinaryText() {
        // Otherwise a stray ``` swallows the rest of the note into a card.
        #expect(CodeBlock.blocks(in: "```python\ndef hello():").isEmpty)
        #expect(CodeBlock.blocks(in: "Notes\n```\nstill writing").isEmpty)
    }

    @Test func indentationAndBlankLinesInsideAFenceSurviveExactly() {
        let source = "```\n  two\n\n\tone tab\n```"
        #expect(CodeBlock.blocks(in: source).first?.codeLines == ["  two", "", "\tone tab"])
    }

    @Test func anEmptyFenceIsStillABlock() {
        let block = CodeBlock.blocks(in: "```\n```").first
        #expect(block?.codeLines.isEmpty == true)
        #expect(block?.isEmpty == true)
    }

    @Test func twoBlocksAreTwoBlocks() {
        let source = "```\na\n```\nbetween\n```\nb\n```"
        let blocks = CodeBlock.blocks(in: source)
        #expect(blocks.count == 2)
        #expect(blocks.map(\.lineRange) == [0...2, 4...6])
        #expect(CodeBlock.block(in: source, atLine: 3) == nil)
    }

    @Test func proseThatMerelyMentionsBackticksIsNotABlock() {
        #expect(CodeBlock.blocks(in: "I use ``` for code\nand that is all").isEmpty)
    }

    @Test func aFenceLineCarryingProseNamesNoLanguage() {
        // "```this is my code" is not a language called "this is my code".
        #expect(CodeBlock.blocks(in: "```this is my code\nx\n```").first?.language == nil)
    }

    @Test func literalLinesCoverTheFencesAsWellAsTheCode() {
        #expect(CodeBlock.literalLineIndices(in: python) == [0, 1, 2, 3])
        #expect(CodeBlock.literalLineIndices(in: "before\n```\nx\n```\nafter") == [1, 2, 3])
    }

    @Test func whatIsWrittenIsWhatIsRead() {
        let source = CodeBlock.source(code: "def hello():\n    print(\"hi\")", language: "python")
        let block = CodeBlock.blocks(in: source).first
        #expect(block?.language == "python")
        #expect(block?.code == "def hello():\n    print(\"hi\")")
    }
}

/// The parser consequence. A `#` inside a fence is a comment, not a heading — and until fences existed
/// there was no way for `body` to say so.
struct CodeBlockLiteralParsingTests {

    @Test func aCommentInsideAFenceIsNotAHeading() {
        let doc = MarkupDocument("```python\n# hello\n```")
        #expect(doc.lines[1].kind == .paragraph)
        #expect(doc.lines[1].isLiteral)
        #expect(doc.lines[1].markerLength == 0)
    }

    @Test func aYAMLItemInsideAFenceIsNotABullet() {
        let doc = MarkupDocument("```yaml\n- item\n- other\n```")
        #expect(doc.lines[1].kind == .paragraph)
        #expect(doc.lines[2].kind == .paragraph)
    }

    @Test func aNumberedLineInsideAFenceIsNotAList() {
        #expect(MarkupDocument("```\n1. not a list\n```").lines[1].kind == .paragraph)
    }

    @Test func aChecklistSpellingInsideAFenceIsNotAChecklist() {
        #expect(MarkupDocument("```\n- [ ] not a box\n```").lines[1].kind == .paragraph)
    }

    @Test func structureOutsideTheFenceIsStillStructure() {
        let doc = MarkupDocument("# Title\n```\n# comment\n```\n- bullet")
        #expect(doc.lines[0].kind == .heading)
        #expect(doc.lines[2].kind == .paragraph)
        #expect(doc.lines[4].kind == .bullet)
    }

    @Test func everyCharacterInsideAFenceIsVisible() {
        // A literal line has no hidden marker, so `visibleText` gives the code back untouched.
        let source = "```\n# hello\n- item\n```"
        #expect(MarkupDocument(source).visibleText() == source)
    }

    @Test func savingNeverRewritesCode() {
        // `- [X] ` is a canonical spelling everywhere except inside a fence, where it is a line of code.
        let source = "- [X] real box\n```\n- [X] code\n```"
        #expect(StructuredText.canonicalized(source) == "- [x] real box\n```\n- [X] code\n```")
    }

    @Test func typingAMarkerInsideAFenceStaysTheCharactersTyped() {
        // `prefixNormalizationEdit` is what turns a typed "- " into a bullet. Inside code it declines.
        let source = "```\n-\n```"
        let caret = NSRange(location: 5, length: 0)   // just after the "-" on line 2
        #expect(DocumentAction.prefixNormalizationEdit(text: source, selection: caret,
                                                       replacementText: " ") == nil)
    }

    @Test func applyingAStyleAcrossAFenceLeavesTheCodeAlone() {
        let source = "before\n```\n# code\n```\nafter"
        let whole = NSRange(location: 0, length: (source as NSString).length)
        let result = DocumentAction.setBlockKind(.bullet, text: source, selection: whole)
        #expect(result.text == "- before\n```\n# code\n```\n- after")
    }

    @Test func codeHasNoBlockStyleToShowAgainst() {
        // A checkmark against "Heading" on a line of Python would describe something the note does
        // not mean, so the menu shows nothing.
        let source = "```\n# comment\n```"
        #expect(BlockStyle.current(in: source, selection: NSRange(location: 6, length: 0)) == nil)
    }

    @Test func theToolbarWithdrawsStructureInsideCode() {
        #expect(WritingToolbar.Mode.resolve(bodyFocused: true, titleFocused: false, inCode: true) == .code)
        #expect(WritingToolbar.Mode.resolve(bodyFocused: true, titleFocused: false, inCode: false) == .writing)
        // Voice survives; the title still wins.
        #expect(WritingToolbar.Mode.resolve(bodyFocused: false, titleFocused: false, inCode: true) == .voiceOnly)
        #expect(WritingToolbar.Mode.resolve(bodyFocused: true, titleFocused: true, inCode: true) == .hidden)
    }
}
