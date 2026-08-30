import Testing
import Foundation
import UIKit
@testable import Yourly

/// Three real diagrams, at the size they are actually written.
///
/// The earlier cases were small enough that a mistake would have been obvious. These are not: 43, 51 and
/// 36 lines, the widest 52 characters, with junction rules eighteen box-drawing characters long. That
/// length is the point — a per-glyph advance that is wrong by a hundredth of a point is invisible in one
/// character and is most of a column by the time a rule has eighteen of them. Sub-point drift is exactly
/// what a screenshot cannot show and what a phone screen cannot be trusted to reveal, so it is measured
/// here **unrounded**.
///
/// The diagrams are stored as explicit line arrays rather than multi-line literals on purpose: leading
/// spaces are the content, and a string literal whose indentation is silently stripped would be a test
/// that agrees with itself about the wrong thing.
@MainActor
struct RealWorldDiagramTests {

    private let pipeline = [
        "DOL / USCIS",
        "     │",
        "     ▼",
        "Airflow detects new release",
        "     │",
        "     ▼",
        "Download",
        "     │",
        "     ▼",
        "ADLS raw",
        "     │",
        "     ▼",
        "Bronze Delta",
        "     │",
        "     ▼",
        "PySpark",
        "     │",
        "     ▼",
        "Silver",
        "     │",
        "     ├── employers",
        "     ├── roles",
        "     ├── wages",
        "     ├── geography",
        "     └── USCIS activity",
        "     │",
        "     ▼",
        "dbt",
        "     │",
        "     ▼",
        "Gold marts",
        "     │",
        "     ▼",
        "Data quality checks",
        "     │",
        "     ▼",
        "Publish",
        "     │",
        "     ▼",
        "PostgreSQL",
        "     │",
        "     ▼",
        "Website now uses new data",
    ].joined(separator: "\n")

    private let flow = [
        "                    USER FINDS JOB",
        "                           │",
        "                           ▼",
        "                     CHECK A JOB",
        "                           │",
        "                           ▼",
        "              Paste details / description",
        "                           │",
        "                           ▼",
        "                   Posting parser",
        "                           │",
        "                           ▼",
        "                    Confirm details",
        "                           │",
        "                           ▼",
        "                  Employer resolver",
        "                           │",
        "                    Role resolver",
        "                           │",
        "                 Location resolver",
        "                           │",
        "                           ▼",
        "                Historical evidence",
        "                           │",
        "        ┌──────────────────┼──────────────────┐",
        "        ▼                  ▼                  ▼",
        "     Company              Role             Location",
        "      history            match              match",
        "        │                  │                  │",
        "        └──────────────────┼──────────────────┘",
        "                           ▼",
        "                         Recency",
        "                           │",
        "                           ▼",
        "                    Decision engine",
        "                           │",
        "          ┌────────────────┴───────────────┐",
        "          ▼                                ▼",
        " Current posting evidence        Historical evidence",
        "          │                                │",
        "          └────────────────┬───────────────┘",
        "                           ▼",
        "                       RESULT",
        "                           │",
        "                           ▼",
        "                Worth investigating?",
        "                           │",
        "              ┌────────────┼────────────┐",
        "              ▼            ▼            ▼",
        "          Company      Evidence      Similar",
        "          profile      filings       sponsors",
    ].joined(separator: "\n")

    private let tree = [
        "sponsor-intelligence/",
        "│",
        "├── apps/",
        "│   ├── web/",
        "│   │   └── Next.js",
        "│   │",
        "│   └── api/",
        "│       └── FastAPI",
        "│",
        "├── data/",
        "│   ├── ingestion/",
        "│   │   ├── dol/",
        "│   │   └── uscis/",
        "│   │",
        "│   ├── spark/",
        "│   │   ├── bronze/",
        "│   │   ├── silver/",
        "│   │   └── enrichment/",
        "│   │",
        "│   └── dbt/",
        "│       ├── staging/",
        "│       ├── intermediate/",
        "│       └── marts/",
        "│",
        "├── services/",
        "│   ├── employer_resolution/",
        "│   ├── role_resolution/",
        "│   ├── location_resolution/",
        "│   ├── job_parser/",
        "│   └── scoring/",
        "│",
        "├── airflow/",
        "├── terraform/",
        "├── tests/",
        "├── docs/",
        "└── .github/",
    ].joined(separator: "\n")

    private var all: [(String, String)] {
        [("pipeline", pipeline), ("flow", flow), ("tree", tree)]
    }

    private func x(of index: Int, on line: String) -> CGFloat {
        (String(Array(line).prefix(index)) as NSString)
            .size(withAttributes: [.font: CodeCardLayout.font()]).width
    }

    private func columns(of characters: Set<Character>, on line: String) -> [Int] {
        Array(line).enumerated().filter { characters.contains($0.element) }.map(\.offset)
    }

    // MARK: The advance width, measured rather than rounded

    @Test func everyBoxCharacterAdvancesExactlyAsFarAsALetter() {
        // Unrounded. The earlier check rounded to the nearest point, which would have hidden a drift
        // that only becomes visible once a rule is long — which is precisely these diagrams.
        let font = CodeCardLayout.font()
        let reference = ("M" as NSString).size(withAttributes: [.font: font]).width
        for glyph in ["│", "├", "└", "─", "┌", "┐", "┼", "┬", "┴", "▼", "▲", "→", "←", " ", "/", "."] {
            let width = (glyph as NSString).size(withAttributes: [.font: font]).width
            #expect(width == reference,
                    "`\(glyph)` advances \(width) where a letter advances \(reference)")
        }
    }

    @Test func aFullLengthJunctionRuleDoesNotDriftFromPlainText() {
        // The worst case in these three: `┌` + eighteen `─` + `┼` + eighteen `─` + `┐`.
        let rule = "┌──────────────────┼──────────────────┐"
        let plain = String(repeating: "M", count: rule.count)
        let font = CodeCardLayout.font()
        let ruleWidth = (rule as NSString).size(withAttributes: [.font: font]).width
        let plainWidth = (plain as NSString).size(withAttributes: [.font: font]).width
        #expect(ruleWidth == plainWidth,
                "a 39-character rule drifted by \(ruleWidth - plainWidth) pt against plain text")
    }

    // MARK: What these are, before anything is drawn

    @Test func allThreeAreReadBackAsPreformattedBlocks() {
        for (name, diagram) in all {
            let source = CodeBlock.preformattedSource(text: diagram)
            let block = CodeBlock.blocks(in: source).first
            #expect(block?.kind == .preformatted, "\(name) was not preformatted")
            #expect(block?.cardLabel == "Plain text", "\(name) was mislabelled")
            #expect(block?.codeLines == diagram.components(separatedBy: "\n"),
                    "\(name) lost or gained a line")
        }
    }

    @Test func notOneLineOfAnyOfThemBecomesStructure() {
        // `├── employers` is not a bullet. `└── .github/` is not a bullet. Nothing here is a heading,
        // a number, a checklist, a table, or a link.
        for (name, diagram) in all {
            let source = CodeBlock.preformattedSource(text: diagram)
            let doc = MarkupDocument(source)
            let allParagraphs = doc.lines.allSatisfy { $0.kind == .paragraph }
            let innerAllLiteral = doc.lines.dropFirst().dropLast().allSatisfy { $0.isLiteral }
            #expect(allParagraphs, "\(name) grew a block kind")
            #expect(innerAllLiteral, "\(name) has a line that is not literal")
            #expect(doc.links.isEmpty, "\(name) grew a link")
            #expect(TableBlock.tables(in: source).isEmpty, "\(name) was read as a table")
        }
    }

    @Test func noneOfThemIsAutoDetectedAsCode() {
        // A normal paste must leave every one of these as prose. `Paste as Preformatted` is the only
        // way they become blocks.
        for (name, diagram) in all {
            #expect(CodeDetection.detect(diagram) == nil, "\(name) was auto-fenced as code")
        }
    }

    // MARK: Alignment, in points, on the page

    @Test func thePipelinesTrunkIsOneColumnFromTopToBottom() {
        let lines = pipeline.components(separatedBy: "\n")
        let connectors = lines.filter { $0.contains("│") || $0.contains("▼") }
        let cols = Set(connectors.compactMap { columns(of: ["│", "▼"], on: $0).first })
        #expect(cols == [5], "the pipeline trunk drifted: \(cols)")
        // Compared with a tolerance, not by `Set` membership: these are ten measurements of ten
        // *different* prefix strings, and TextKit's accumulated advances can differ in the last bit
        // while the column is exactly the same one the reader sees (see `PreformattedAlignmentTests`,
        // where the equivalent exact comparison failed on a perfectly aligned diagram).
        let xs = connectors.map { x(of: 5, on: $0) }
        #expect(xs.allSatisfy { abs($0 - xs[0]) < 0.01 },
                "the trunk sat at more than one x position: \(xs)")
    }

    @Test func theSilverBranchHangsOffThatSameTrunk() {
        let branches = pipeline.components(separatedBy: "\n").filter {
            $0.hasPrefix("     ├──") || $0.hasPrefix("     └──")
        }
        #expect(branches.count == 5)
        let cols = Set(branches.compactMap { columns(of: ["├", "└"], on: $0).first })
        #expect(cols == [5], "a Silver branch did not start on the trunk: \(cols)")
    }

    @Test func everyJunctionInTheFlowSitsOnItsSpine() {
        // The invariant that makes this diagram readable: the trunk, and every ┼ ┬ ┴ it passes
        // through, share one column — 27 — over 51 lines.
        let lines = flow.components(separatedBy: "\n")
        let spine = lines.filter { $0.hasSuffix("│") && $0.trimmingCharacters(in: .whitespaces) == "│" }
        let spineCols = Set(spine.compactMap { columns(of: ["│"], on: $0).first })
        #expect(spineCols == [27], "the spine drifted: \(spineCols)")

        let junctions = lines.flatMap { columns(of: ["┼", "┬", "┴"], on: $0) }
        #expect(!junctions.isEmpty)
        #expect(Set(junctions) == [27], "a junction left the spine: \(Set(junctions))")
    }

    @Test func theThreeWayBranchArmsLandUnderTheirCorners() {
        let lines = flow.components(separatedBy: "\n")
        guard let ruleIndex = lines.firstIndex(where: { $0.contains("┌──────────────────┼") }) else {
            Issue.record("the wide junction rule is missing")
            return
        }
        let rule = lines[ruleIndex]
        let arrows = lines[ruleIndex + 1]
        let corners = columns(of: ["┌", "┼", "┐"], on: rule)
        let heads = columns(of: ["▼"], on: arrows)
        #expect(corners == [8, 27, 46])
        #expect(heads == corners, "arrowheads at \(heads) under corners at \(corners)")
        for (head, corner) in zip(heads, corners) {
            // A tolerance, not a fudge: `NSString.size` accumulates left to right, so two identical
            // column positions reached along different strings differ in the last bits of a Double.
            // The measured gap here is ~1e-13 pt. What would matter — a per-glyph advance that is
            // fractionally wrong — shows up as drift proportional to the column, and 46 columns of it
            // could not hide under a hundredth of a point.
            #expect(abs(x(of: head, on: arrows) - x(of: corner, on: rule)) < 0.01,
                    "column \(head) is at a different x than column \(corner)")
        }
    }

    @Test func theTreesNestingLevelsEachHoldOneColumn() {
        let lines = tree.components(separatedBy: "\n")
        // Depth one: `├──`/`└──` at column 0. Depth two: at column 4. Depth three: at column 8.
        for (prefix, expected) in [("├── ", 0), ("└── ", 0)] {
            let level = lines.filter { $0.hasPrefix(prefix) }
            let cols = Set(level.compactMap { columns(of: ["├", "└"], on: $0).first })
            #expect(cols.isEmpty || cols == [expected], "depth-one drifted: \(cols)")
        }
        let depthTwo = lines.filter { $0.hasPrefix("│   ├") || $0.hasPrefix("│   └") }
        #expect(depthTwo.count == 10)
        let twoCols = Set(depthTwo.compactMap { columns(of: ["├", "└"], on: $0).first })
        #expect(twoCols == [4], "depth-two drifted: \(twoCols)")

        let depthThree = lines.filter { $0.hasPrefix("│   │   ") || $0.hasPrefix("│       ") }
        let threeCols = Set(depthThree.compactMap { line in
            columns(of: ["├", "└"], on: line).last
        })
        #expect(threeCols == [8], "depth-three drifted: \(threeCols)")
    }

    // MARK: The card these produce

    @Test func eachOneScrollsOrFitsHonestly() {
        // 353 pt is the writing width on this phone. Whatever the diagram's width, the card stays the
        // page's width and the drawing scrolls inside it — it never stretches the page.
        for (name, diagram) in all {
            let lines = diagram.components(separatedBy: "\n")
            let block = CodeBlock(language: "text", lineRange: 0...(lines.count + 1), codeLines: lines)
            guard let layout = CodeCardLayout.layout(for: block, availableWidth: 353) else {
                Issue.record("\(name) produced no layout at 353pt")
                continue
            }
            #expect(layout.size.width == 353, "\(name) stretched the page to \(layout.size.width)")
            let widest = lines.map(\.count).max() ?? 0
            let advance = ("M" as NSString).size(withAttributes: [.font: CodeCardLayout.font()]).width
            // The measured width must match the widest line's character count — which is only true if
            // nothing wrapped and every glyph advanced the same.
            #expect(abs(layout.codeWidth - CGFloat(widest) * advance) < 1.0,
                    "\(name): measured \(layout.codeWidth) for \(widest) characters")
        }
    }

    @Test func theWidestDiagramScrollsRatherThanWrapping() {
        let lines = flow.components(separatedBy: "\n")
        let block = CodeBlock(language: "text", lineRange: 0...(lines.count + 1), codeLines: lines)
        let layout = CodeCardLayout.layout(for: block, availableWidth: 353)!
        #expect(layout.scrolls, "a 52-character diagram fit in 353pt, which cannot be right")
    }

    @Test func aFortyThreeLineDiagramReservesRoomForEveryLine() {
        let lines = pipeline.components(separatedBy: "\n")
        let block = CodeBlock(language: "text", lineRange: 0...(lines.count + 1), codeLines: lines)
        let layout = CodeCardLayout.layout(for: block, availableWidth: 353)!
        let expected = CodeCardLayout.Metrics.headerHeight
            + CodeCardLayout.Metrics.cardInsetV * 2
            + CGFloat(lines.count) * layout.lineHeight
        #expect(abs(layout.size.height - expected.rounded(.up)) < 1.0,
                "43 lines reserved \(layout.size.height), wanted \(expected)")
    }

    @Test func theCardDrawsEachDiagramExactlyAsWritten() {
        for (name, diagram) in all {
            let lines = diagram.components(separatedBy: "\n")
            let block = CodeBlock(language: "text", lineRange: 0...(lines.count + 1), codeLines: lines)
            let layout = CodeCardLayout.layout(for: block, availableWidth: 353)!
            let card = CodeBlockView(block: block, layout: layout, palette: .ds)
            card.frame = CGRect(origin: .zero, size: layout.size)
            card.layoutIfNeeded()
            #expect(card.drawnCode?.string == diagram, "\(name) was redrawn rather than shown")
            #expect(card.drawnLanguage == "Plain text")
            #expect(card.drawnCodeAccessibilityLabel == "Plain text block")
        }
    }

    // MARK: The whole trip a writer actually makes

    @Test func pasteThenCopyReturnsTheDiagramByteForByte() {
        for (name, diagram) in all {
            guard let edit = DocumentAction.pasteAsPreformattedEdit(
                diagram, text: "", selection: NSRange(location: 0, length: 0)) else {
                Issue.record("\(name) produced no paste edit")
                continue
            }
            let body = edit.applied(to: "").text
            // The block's own characters are the contract, and they are byte-identical.
            #expect(CodeBlock.blocks(in: body).first?.code == diagram,
                    "\(name) did not survive paste → body")
            // Copying the **whole note** also carries the empty line the paste leaves after the block,
            // which is where the caret goes and is a real line of the note. That trailing newline is
            // the note's, not the diagram's — every character before it is exactly as pasted.
            #expect(StructuredTextExport.plainText(body) == diagram + "\n",
                    "\(name) did not survive paste → body → copy")
            #expect(!StructuredTextExport.plainText(body).contains("```"))
            // …and the As Told → As Told flavor keeps the canonical source.
            let whole = NSRange(location: 0, length: (body as NSString).length)
            #expect(StructuredTextExport.structuredText(from: body, range: whole) == body)
        }
    }

    @Test func aHomeRowShowsTheFirstRealLineAndNoFences() {
        for (name, diagram) in all {
            let body = CodeBlock.preformattedSource(text: diagram)
            let preview = StructuredTextExport.previewText(body)
            #expect(!preview.contains("```"), "\(name) leaked its fences into a preview")
            #expect(preview.hasPrefix(diagram.components(separatedBy: "\n")[0]),
                    "\(name) did not lead with its own first line")
        }
    }

    @Test func searchStillReachesInsideThem() {
        let body = CodeBlock.preformattedSource(text: pipeline)
        for term in ["Airflow", "Bronze Delta", "USCIS activity", "PostgreSQL"] {
            #expect(body.contains(term), "search could not reach \(term)")
            #expect(StructuredTextExport.previewText(body).contains(term))
        }
    }
}
