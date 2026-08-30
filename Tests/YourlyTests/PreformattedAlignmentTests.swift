import Testing
import Foundation
import UIKit
@testable import Yourly

/// The three diagrams from the device pass, checked the way a screenshot cannot check them.
///
/// "The alignment looks right" is the claim this feature lives or dies on, and an eye reading a phone
/// screen is a poor instrument for it — a column one point out looks fine and *is* broken. So the two
/// things that actually make alignment work are measured here: every glyph advances by the same width
/// (a monospaced face), and the `│` under a `┼` lands at the same **x**, not merely at the same
/// character index. A downscaled screenshot hides exactly this.
///
/// What these do not replace: whether editing one on a real phone *feels* right. That is a judgement,
/// it needs a thumb, and it stays a human's.
@MainActor
struct PreformattedAlignmentTests {

    private let tree = """
    sponsor-intelligence/
    │
    ├── apps/
    │   ├── web/
    │   └── api/
    │
    ├── data/
    │   ├── ingestion/
    │   └── spark/
    │
    └── docs/
    """

    private let flow = """
    DOL / USCIS
        │
        ▼
    Airflow detects new release
        │
        ▼
    Download
        │
        ▼
    ADLS raw
        │
        ▼
    Bronze Delta
        │
        ▼
    PySpark
    """

    private let wide = """
    Historical evidence
            │
     ┌──────┼────────┐
     ▼      ▼        ▼
    Company Role   Location
    history match    match
    """

    private func block(_ text: String) -> CodeBlock {
        CodeBlock(language: "text", lineRange: 0...(text.components(separatedBy: "\n").count + 1),
                  codeLines: text.components(separatedBy: "\n"))
    }

    /// Where a character sits on screen, in points, when the card draws it.
    private func x(of index: Int, on line: String) -> CGFloat {
        (String(Array(line).prefix(index)) as NSString)
            .size(withAttributes: [.font: CodeCardLayout.font()]).width
    }

    private func column(of character: Character, on line: String) -> Int? {
        Array(line).firstIndex(of: character)
    }

    /// Whether two drawn positions are the same column *to the reader*.
    ///
    /// Not `==`. These two numbers come from measuring two **different** prefix strings, and TextKit
    /// sums a per-glyph advance for each — so the same column arrives as 164.3574609375 from one line
    /// and 164.35746093749998 from the other, and an exact comparison fails on a diagram that is
    /// perfectly aligned. (It did: `theBranchArmsLandUnderTheirJunction`, 2026-08-25.) The claim these
    /// tests make is about what a reader sees, and 1.4e-14 pt is not something a reader sees.
    ///
    /// The tolerance is 0.01 pt — two orders of magnitude below one device pixel on a 3× screen, so a
    /// real drift of even a third of a point still fails this the way it should.
    private func sameColumn(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool { abs(lhs - rhs) < 0.01 }

    // MARK: The property everything else rests on

    @Test func theFaceIsMonospacedSoAColumnIsAColumn() {
        // If one glyph is wider than another, every diagram in the app is wrong and no amount of
        // careful drawing by the author can save it.
        let font = CodeCardLayout.font()
        let widths = Set(["│", "├", "└", "─", "┌", "┐", "▼", "▲", "→", "←", "M", "i", " ", "0"].map {
            ($0 as NSString).size(withAttributes: [.font: font]).width.rounded(.toNearestOrEven)
        })
        #expect(widths.count == 1, "the box characters do not share the code font's advance: \(widths)")
    }

    // MARK: Case 1 — the directory tree

    @Test func everyTrunkOfTheTreeSitsInOneColumn() {
        let lines = tree.components(separatedBy: "\n")
        // Every line that starts a trunk glyph starts it at character 0, so at x = 0.
        let trunks = lines.filter { $0.first.map { "│├└".contains($0) } == true }
        #expect(trunks.count == 10)
        let allAtZero = trunks.allSatisfy { x(of: 0, on: $0) == 0 }
        #expect(allAtZero)
    }

    @Test func theNestedBranchesShareOneIndent() {
        let nested = tree.components(separatedBy: "\n").filter { $0.hasPrefix("│   ") }
        #expect(nested.count == 4)
        let offsets = Set(nested.compactMap { line in column(of: "├", on: line) ?? column(of: "└", on: line) })
        #expect(offsets == [4], "the nested branches disagreed on their indent: \(offsets)")
        // …and the same answer in points, which is what the reader actually sees.
        #expect(Set(nested.map { x(of: 4, on: $0) }).count == 1)
    }

    @Test func theTreeIsPreformattedAndNotAListOfBullets() {
        let source = CodeBlock.preformattedSource(text: tree)
        let doc = MarkupDocument(source)
        #expect(CodeBlock.blocks(in: source).first?.kind == .preformatted)
        let allParagraphs = doc.lines.allSatisfy { $0.kind == .paragraph }
        let allLiteral = doc.lines.dropFirst().dropLast().allSatisfy { $0.isLiteral }
        #expect(allParagraphs)
        #expect(allLiteral)
    }

    // MARK: Case 2 — the vertical flow

    @Test func everyBarAndArrowOfTheFlowSharesOneColumn() {
        let lines = flow.components(separatedBy: "\n")
        let connectors = lines.filter { $0.contains("│") || $0.contains("▼") }
        #expect(connectors.count == 10)
        let columns = Set(connectors.compactMap { line in
            column(of: "│", on: line) ?? column(of: "▼", on: line)
        })
        #expect(columns == [4], "the flow's connectors drifted: \(columns)")
        // Same reason `sameColumn` exists: a `Set<CGFloat>` of ten independently accumulated
        // measurements can hold ten members that are all the same column. Compare against the first.
        let drawn = connectors.map { x(of: 4, on: $0) }
        #expect(drawn.allSatisfy { sameColumn($0, drawn[0]) },
                "the flow's connectors drifted in points: \(drawn)")
    }

    @Test func theFlowKeepsEveryLineIncludingItsRepeats() {
        // Six stages, ten connector lines, nothing collapsed or de-duplicated on the way in.
        let source = CodeBlock.preformattedSource(text: flow)
        #expect(CodeBlock.blocks(in: source).first?.codeLines == flow.components(separatedBy: "\n"))
    }

    // MARK: Case 3 — the wide one, which is the one that matters

    @Test func theBranchArmsLandUnderTheirJunction() {
        let lines = wide.components(separatedBy: "\n")
        let rule = lines[2]          // " ┌──────┼────────┐"
        let arrows = lines[3]        // " ▼      ▼        ▼"
        guard let junction = column(of: "┼", on: rule),
              let corner = column(of: "┌", on: rule),
              let end = column(of: "┐", on: rule) else {
            Issue.record("the junction rule lost its characters")
            return
        }
        let heads = Array(arrows).enumerated().filter { $0.element == "▼" }.map(\.offset)
        #expect(heads == [corner, junction, end],
                "the arrowheads do not sit under ┌ ┼ ┐ — got \(heads), wanted \([corner, junction, end])")
        // And in points, which is the claim the reader can actually see.
        for (head, above) in zip(heads, [corner, junction, end]) {
            #expect(sameColumn(x(of: head, on: arrows), x(of: above, on: rule)),
                    "arrowhead at \(head) does not sit under the character at \(above)")
        }
    }

    @Test func theTrunkMeetsTheJunctionItHangsFrom() {
        let lines = wide.components(separatedBy: "\n")
        #expect(column(of: "│", on: lines[1]) == column(of: "┼", on: lines[2]))
    }

    @Test func theWideDiagramScrollsRatherThanWrapping() {
        // A phone is 353 pt of writing width. This diagram is wider, so the card must scroll — a
        // wrapped line here is a different diagram, and the arms stop pointing at anything.
        let long = wide + "\n" + String(repeating: "─", count: 120)
        let block = self.block(long)
        guard let layout = CodeCardLayout.layout(for: block, availableWidth: 353) else {
            Issue.record("353pt is a width; the layout should exist")
            return
        }
        #expect(layout.scrolls, "the widest line fit, so this no longer proves anything")
        #expect(layout.size.width == 353, "the card grew past the page instead of scrolling inside it")
        #expect(layout.codeWidth > layout.size.width)
    }

    @Test func theCardDrawsTheWideDiagramAtItsFullWidth() {
        let block = self.block(wide)
        let layout = CodeCardLayout.layout(for: block, availableWidth: 353)!
        let card = CodeBlockView(block: block, layout: layout, palette: .ds)
        card.frame = CGRect(origin: .zero, size: layout.size)
        card.layoutIfNeeded()
        #expect(card.drawnCode?.string == wide, "the card redrew the diagram instead of showing it")
        #expect(card.drawnLanguage == "Plain text")
    }

    // MARK: What the writer sees when they tap into one

    @Test func neitherFenceIsDrawnWhileTheDiagramIsEdited() {
        let source = CodeBlock.preformattedSource(text: flow)
        let storage = NSTextStorage(string: source)
        StructuredTextStyler.apply(to: storage, textColor: .label)
        let lines = source.components(separatedBy: "\n")
        for fence in [0, lines.count - 1] {
            let range = StructuredText.characterRange(ofLines: fence...fence, in: source as NSString)!
            for offset in range.location..<NSMaxRange(range) {
                #expect(storage.attribute(.astHiddenMarker, at: offset, effectiveRange: nil) as? Bool == true,
                        "a fence character was drawn at \(offset)")
            }
        }
    }

    @Test func theDiagramKeepsItsGroundAndItsMonospacedFaceWhileEdited() {
        let source = CodeBlock.preformattedSource(text: flow)
        let storage = NSTextStorage(string: source)
        StructuredTextStyler.apply(to: storage, textColor: .label)
        let firstCode = StructuredText.characterRange(ofLines: 1...1, in: source as NSString)!
        #expect(storage.attribute(.astCodeBlock, at: firstCode.location, effectiveRange: nil) != nil)
        let font = storage.attribute(.font, at: firstCode.location, effectiveRange: nil) as? UIFont
        #expect(font == CodeCardLayout.font())
    }

    @Test func editingADiagramNeverRecolorsIt() {
        // `text` is not a language, so the storage carries exactly one foreground colour.
        let source = CodeBlock.preformattedSource(text: "SELECT │ FROM ▼ WHERE")
        let storage = NSTextStorage(string: source)
        StructuredTextStyler.apply(to: storage, textColor: .label,
                                   codeTokens: [.keyword: .systemPink, .number: .systemOrange])
        let code = StructuredText.characterRange(ofLines: 1...1, in: source as NSString)!
        var colours: Set<UIColor> = []
        storage.enumerateAttribute(.foregroundColor, in: code) { value, _, _ in
            if let colour = value as? UIColor { colours.insert(colour) }
        }
        #expect(colours.count <= 1, "a diagram was syntax-coloured: \(colours)")
    }
}
