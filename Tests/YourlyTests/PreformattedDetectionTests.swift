import Testing
import Foundation
@testable import Yourly

// The second — and last — place As Told infers structure from plain prose.
//
// `CodeDetection` was the first, and the argument here is identical (RULES.md §4). A "Copy" button on
// a chat answer puts nothing but `public.utf8-plain-text` on the pasteboard. When what was copied is an
// architecture diagram, its *alignment is the entire content*, and pasting it as prose destroys it
// immediately: proportional type throws the columns out and wrapping breaks the arrows. Unlike code
// left as prose — a small disappointment — a diagram left as prose is unreadable.
//
// So the bar is set the same way, and for the same reason: **wrong in the safe direction**. Prose
// turned into a diagram card is the note being rewritten, which is the failure this app exists not to
// have. The discriminator that makes it safe is narrow and deliberate:
//
//   **Real Unicode box-drawing characters** (U+2500–U+257F) — `│ ├ └ ─ ┌ ┐ ┬ ┼ ┤` — never ASCII
//   `|`, `-`, or `+`. Nobody types `├──` in a sentence. Everybody types `|` and `-`.
//
// That single choice is what keeps a grocery list, a Markdown rule, and `A | B` out, without needing a
// prose guard to rescue them.
struct PreformattedDetectionTests {

    // MARK: The shapes that must be caught

    @Test func aDirectoryTreeIsDetected() {
        let tree = """
        sponsor-intelligence/
        │
        ├── apps/
        │   ├── web/
        │   └── api/
        """
        #expect(PreformattedDetection.isDiagram(tree))
    }

    @Test func aVerticalPipelineIsDetected() {
        let flow = """
        DOL / USCIS
            │
            ▼
        Airflow detects new release
            │
            ▼
        Download
        """
        #expect(PreformattedDetection.isDiagram(flow))
    }

    @Test func aBranchingFlowIsDetected() {
        let branch = """
        Historical evidence
                │
         ┌──────┼────────┐
         ▼      ▼        ▼
        Company Role   Location
        """
        #expect(PreformattedDetection.isDiagram(branch))
    }

    @Test func aDeeplyNestedTreeIsDetected() {
        let tree = """
        repo/
        ├── apps/
        │   ├── web/
        │   │   └── Next.js
        │   └── api/
        │       └── FastAPI
        └── docs/
        """
        #expect(PreformattedDetection.isDiagram(tree))
    }

    // MARK: The shapes that must NOT be caught
    //
    // Every one of these is ordinary writing. A false positive here writes fence characters into
    // somebody's note that nobody typed, which is worse than any missed diagram.

    @Test func anASCIIPipeSketchIsNotADiagram() {
        // The example called out by name. `|` is a character people type; `│` is not.
        #expect(!PreformattedDetection.isDiagram("A\n|\nB"))
        #expect(!PreformattedDetection.isDiagram("A\n|\nv\nB"))
    }

    @Test func aGroceryListIsNotADiagram() {
        #expect(!PreformattedDetection.isDiagram("Eggs\nMilk\nBread\nCoffee"))
    }

    @Test func aBulletedListIsNotADiagram() {
        #expect(!PreformattedDetection.isDiagram("- Eggs\n- Milk\n- Bread"))
    }

    @Test func proseContainingAPipeIsNotADiagram() {
        #expect(!PreformattedDetection.isDiagram(
            "Use grep | sort to filter.\nThen check the output.\nIt should be sorted."))
    }

    @Test func proseContainingOneArrowIsNotADiagram() {
        #expect(!PreformattedDetection.isDiagram(
            "The plan → ship it Friday.\nEverything else can wait.\nWe will review on Monday."))
    }

    @Test func aMarkdownHorizontalRuleIsNotADiagram() {
        #expect(!PreformattedDetection.isDiagram("Notes\n\n---\n\nMore notes"))
        #expect(!PreformattedDetection.isDiagram("Notes\n***\nMore"))
    }

    @Test func aTableOfPipesIsNotADiagram() {
        // It is a table, and `TableBlock` already reads it. Never both.
        #expect(!PreformattedDetection.isDiagram(
            "| Company | Role |\n| --- | --- |\n| Acme | SDE |"))
    }

    @Test func oneLineIsNeverADiagram() {
        #expect(!PreformattedDetection.isDiagram("├── apps/"))
        #expect(!PreformattedDetection.isDiagram("┌──────┼──────┐"))
    }

    @Test func aSentenceThatHappensToUseADashIsNotADiagram() {
        #expect(!PreformattedDetection.isDiagram(
            "I met Ravi — he was late.\nWe talked about the trip.\nHe will book the flights."))
    }

    @Test func emptyAndBlankInputAreNotDiagrams() {
        #expect(!PreformattedDetection.isDiagram(""))
        #expect(!PreformattedDetection.isDiagram("\n\n\n"))
    }

    // MARK: It must never compete with code detection

    @Test func realCodeIsNotClaimedAsADiagram() {
        #expect(!PreformattedDetection.isDiagram("def hello(name):\n    return name\n"))
        #expect(!PreformattedDetection.isDiagram("SELECT id, name\nFROM users\nWHERE id = 1;"))
    }
}
