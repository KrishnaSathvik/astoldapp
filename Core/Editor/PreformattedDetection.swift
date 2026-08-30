import Foundation

// The second — and last — place As Told infers structure from plain prose (RULES.md §4, amended
// 2026-08-25).
//
// `CodeDetection` was the first, and the argument is identical. A "Copy" button on a chat answer
// frequently puts nothing but `public.utf8-plain-text` on the pasteboard. When what was copied is an
// architecture diagram or a directory tree, its **alignment is the entire content**, and arriving as
// prose destroys it on contact: proportional type throws the columns out of line and the first wrap
// breaks the arrows. That is the asymmetry that justifies this at all — code left as prose is a small
// disappointment fixed by one tap, while a diagram left as prose is simply unreadable.
//
// Everything here is built to be **wrong in the safe direction**, because prose turned into a card is
// the note being rewritten, which is the failure this app exists not to have. One choice does most of
// that work:
//
//   **Only real Unicode box-drawing characters count** — `│ ├ └ ─ ┌ ┐ ┬ ┼ ┤`, U+2500–U+257F. Never
//   ASCII `|`, `-`, or `+`.
//
// Nobody types `├──` in a sentence; everybody types `|` and `-`. That single discriminator is what
// keeps a grocery list, a Markdown rule, `A | B`, and `A\n|\nB` out without needing a prose guard to
// rescue them afterwards. It is also why this cannot fire on a Markdown table: pipes are ASCII.
//
// What this does NOT do, and must never do: interpret the drawing. It answers one question — "are
// these characters aligned art?" — and nothing about what the art means (RULES.md §2, §7).
enum PreformattedDetection {

    /// Whether `text` is aligned art that must keep its spacing exactly.
    ///
    /// Requires **three lines, two independent signals, and at least one real box-drawing character**.
    /// One signal is never enough: each is individually plausible in ordinary writing, and it is their
    /// coincidence — connectors that repeat, and repeat *in the same column* — that no sentence
    /// produces by accident.
    static func isDiagram(_ text: String) -> Bool {
        let lines = text.components(separatedBy: "\n")
        let content = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard content.count >= 3, text.count <= 200_000 else { return false }

        // The gate. No box-drawing glyph, no diagram — however arrow-laden or indented the text is.
        guard content.filter({ $0.unicodeScalars.contains(where: isBoxDrawing) }).count >= 2 else {
            return false
        }

        var signals = 0
        if treeConnectors(content) { signals += 1 }
        if connectorOnlyLines(content) { signals += 1 }
        if alignedConnectorColumn(content) { signals += 1 }
        if junctionRule(content) { signals += 1 }
        return signals >= 2
    }

    // MARK: The signals

    /// `├── `, `└── `, `│   ` — the shape every directory tree in the world is printed in.
    private static func treeConnectors(_ content: [String]) -> Bool {
        content.filter { line in
            let trimmed = line.drop { $0 == " " }
            return trimmed.hasPrefix("├─") || trimmed.hasPrefix("└─") || trimmed.hasPrefix("│")
        }.count >= 2
    }

    /// A line whose entire content is connectors — `│`, `▼`, `┼`. A sentence never is one.
    private static func connectorOnlyLines(_ content: [String]) -> Bool {
        content.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            return trimmed.unicodeScalars.allSatisfy { isBoxDrawing($0) || isArrow($0) }
        }.count >= 2
    }

    /// The same connector character, at the same column, on three or more lines.
    ///
    /// This is the signal that actually means "drawn": a spine holds its column down the page, and
    /// prose containing the odd box character does not.
    private static func alignedConnectorColumn(_ content: [String]) -> Bool {
        var counts: [Int: Int] = [:]
        for line in content {
            for (column, character) in Array(line).enumerated()
            where character.unicodeScalars.contains(where: { isBoxDrawing($0) || isArrow($0) }) {
                counts[column, default: 0] += 1
            }
        }
        return counts.values.contains { $0 >= 3 }
    }

    /// A drawn rule — three or more `─` in a row, with a junction or corner on the same line.
    private static func junctionRule(_ content: [String]) -> Bool {
        content.contains { line in
            guard line.contains("───") else { return false }
            return line.unicodeScalars.contains { scalar in
                "┼┬┴├┤┌┐└┘".unicodeScalars.contains(scalar)
            }
        }
    }

    // MARK: The character classes

    /// Box Drawing, U+2500–U+257F. Deliberately excludes Block Elements and every ASCII lookalike.
    private static func isBoxDrawing(_ scalar: Unicode.Scalar) -> Bool {
        (0x2500...0x257F).contains(Int(scalar.value))
    }

    /// The four arrowheads a diagram actually uses, plus the triangles chat apps draw them with.
    private static func isArrow(_ scalar: Unicode.Scalar) -> Bool {
        "▼▲◀▶→←↑↓".unicodeScalars.contains(scalar)
    }
}
