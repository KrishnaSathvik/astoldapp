import Foundation

// A code block inside a note.
//
// Like a table, a code block is not a new model and not a migration (RULES.md §5) — it is a run of
// ordinary lines in `body`, fenced the way every editor in the world fences code:
//
//   ```python
//   def hello():
//       print("hello")
//   ```
//
// What makes code different from every other structure As Told holds is that **its characters mean
// nothing to As Told**. A `#` inside a fence is a Python comment, not a heading. A `- ` is a YAML
// item, not a bullet. So a fence does not merely render differently; it switches marker parsing off
// for the lines inside it, which is why `MarkupDocument` consults this type before it parses anything
// (RULES.md §7, code-blocks exception).
//
// Both fences are required. An unterminated fence is ordinary text, so a stray ``` typed into a note
// can never swallow everything after it into a code card.
//
// Known limitation, in the same shape as a table's multi-line cell: a fence cannot contain a line
// that is itself a bare fence, because that line closes it. Nested fences are out of scope.

/// One code block found in a note's source.
struct CodeBlock: Equatable, Identifiable {
    /// Where it sits in the note — enough to tell two blocks apart while one is on screen.
    var id: ClosedRange<Int> { lineRange }

    /// What the opening fence's declared language says these characters *are*.
    ///
    /// Two cases, and the difference between them is two things and nothing else: what the card's
    /// header says, and whether syntax colour is applied. Everything that makes a fence a fence — the
    /// literal region, the hidden fence lines, the card, the sideways scroll, Copy — is shared, because
    /// a directory tree and a function body need exactly the same treatment: **do not touch these
    /// characters, and do not let them wrap** (added 2026-08-25).
    enum Kind: Equatable {
        /// A program. Labelled with its language when the fence named one this app knows, and coloured.
        case code
        /// Aligned plain text the author drew: an ASCII diagram, a directory tree, a column of figures.
        /// Labelled "Plain text", never coloured — As Told does not read it, it only keeps it.
        case preformatted
    }

    /// The spellings a fence may use to declare that its characters are plain text rather than code.
    /// Read all three; write only `preformattedLanguage`.
    static let preformattedLanguages: Set<String> = ["text", "plaintext", "txt"]

    /// The one spelling As Told writes. A block this app produced never says `txt`.
    static let preformattedLanguage = "text"

    /// Whether `declared` is one of the plain-text spellings.
    ///
    /// A fence that named **nothing** is not preformatted: `Paste as Code` writes a bare fence and
    /// states no language, and reading that as plain text would silently relabel every block that path
    /// has ever produced.
    static func isPreformattedLanguage(_ declared: String?) -> Bool {
        guard let declared else { return false }
        return preformattedLanguages.contains(
            declared.trimmingCharacters(in: .whitespaces).lowercased())
    }

    /// The language the opening fence named, if it named one. Carried for display only; nothing in
    /// As Told interprets it, and nothing runs it (RULES.md §7 — no execution, no IDE).
    var language: String?
    /// The lines of `body` this block occupies, fences included.
    var lineRange: ClosedRange<Int>
    /// The code between the fences. Empty when the block holds nothing.
    var codeLines: [String]

    /// The code as one string, indentation, whitespace, and line breaks exactly as written.
    var code: String { codeLines.joined(separator: "\n") }

    var isEmpty: Bool { codeLines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }

    /// Which of the two a block is.
    var kind: Kind { Self.isPreformattedLanguage(language) ? .preformatted : .code }

    var isPreformatted: Bool { kind == .preformatted }

    /// What the card's header shows, or `nil` when there is nothing honest to show.
    ///
    /// A preformatted block says **Plain text** — the fence's own spelling is storage, and `txt` is not
    /// a word to put in front of a reader. A code block says whatever its fence declared, and a fence
    /// that declared nothing says nothing at all, because a label nobody wrote is a guess.
    var cardLabel: String? {
        switch kind {
        case .preformatted: return "Plain text"
        case .code: return CodeHighlighting.displayName(for: language)
        }
    }

    // MARK: Writing

    static let fence = "```"

    /// The canonical source for code a clipboard stated. Used only by paste; nothing rewrites a note
    /// into this shape on its own.
    static func source(code: String, language: String? = nil) -> String {
        var name = (language ?? "").trimmingCharacters(in: .whitespaces)
        // Three spellings are read, one is written. Whatever `plaintext` or `txt` the source said, a
        // block As Told writes says `text`, so `body` holds one shape for one thing.
        if isPreformattedLanguage(name) { name = preformattedLanguage }
        let opening = name.isEmpty || name.contains(fence) ? fence : fence + name
        var lines = code.components(separatedBy: "\n")
        // A block's own trailing blank line is the fence's job, not the code's.
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        return ([opening] + lines + [fence]).joined(separator: "\n")
    }

    /// The canonical source for text a clipboard — or a writer using **Paste as Preformatted** — stated
    /// is preformatted. Always `text`, whichever of the three spellings arrived.
    static func preformattedSource(text: String) -> String {
        source(code: text, language: preformattedLanguage)
    }

    // MARK: Reading

    /// Every code block in `source`, in the order they appear.
    static func blocks(in source: String) -> [CodeBlock] {
        let lines = source.components(separatedBy: "\n")
        var found: [CodeBlock] = []
        var index = 0

        while index < lines.count {
            guard let language = openingFenceLanguage(lines[index]) else { index += 1; continue }
            guard let close = (index + 1..<lines.count).first(where: { isClosingFence(lines[$0]) })
            else { index += 1; continue }        // unterminated: ordinary text, and ``` may still open later

            found.append(CodeBlock(language: language,
                                   lineRange: index...close,
                                   codeLines: Array(lines[(index + 1)..<close])))
            index = close + 1
        }
        return found
    }

    /// The block containing `line`, if any.
    static func block(in source: String, atLine line: Int) -> CodeBlock? {
        blocks(in: source).first { $0.lineRange.contains(line) }
    }

    /// Every line index whose characters are code, fences included — the lines that MUST NOT be read
    /// as headings, bullets, checklists, numbers, tables, or links.
    static func literalLineIndices(in source: String) -> Set<Int> {
        var indices: Set<Int> = []
        for block in blocks(in: source) { indices.formUnion(block.lineRange) }
        return indices
    }

    /// `” ```python ”` → `"python"`, `” ``` ”` → `nil` language but still an opening fence.
    /// Returns `.some(nil)` shaped as an optional-of-optional would be clumsy, so the language comes
    /// back as `String?` and the caller learns "not a fence" from this returning nil at all.
    private static func openingFenceLanguage(_ line: String) -> String?? {
        guard line.hasPrefix(fence) else { return nil }
        let name = String(line.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return .some(nil) }
        // A language is one word. Anything else is prose that happened to start with backticks.
        guard !name.contains(fence), name.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return .some(nil) }
        return .some(name)
    }

    /// A closing fence carries nothing but the fence.
    static func isClosingFence(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == fence
    }

    /// Whether `line` is one of a block's two fence lines — the storage the reader never sees.
    static func isFenceLine(_ index: Int, in source: String) -> Bool {
        guard let block = block(in: source, atLine: index) else { return false }
        return index == block.lineRange.lowerBound || index == block.lineRange.upperBound
    }

    /// Where a caret must go when it lands on a fence line, or `nil` when it has not.
    ///
    /// The same argument that keeps a caret out of a hidden block marker and out of a table's rule row
    /// (RULES.md §4). Since 2026-08-24 a fence has no glyphs while its block is being edited either —
    /// the block looks like code the whole time — so a caret left on one is invisible, and the next
    /// keystroke would land *inside* ```` ```python ````, breaking the fence and dropping the block back
    /// to prose. The fences are storage, and storage is not a place.
    ///
    /// - Parameter movingForward: which way the caret was travelling, so arrowing down off the opening
    ///   fence lands on the first line of code and arrowing up off the closing fence lands on the last,
    ///   rather than both directions trapping it against the same edge.
    static func caretEscape(in source: String, from offset: Int, movingForward: Bool) -> Int? {
        let ns = source as NSString
        let index = StructuredText.lineIndex(of: offset, in: ns)
        guard let block = block(in: source, atLine: index) else { return nil }

        let opening = block.lineRange.lowerBound
        let closing = block.lineRange.upperBound
        guard index == opening || index == closing else { return nil }
        // A block holding no code has nowhere inside to put a caret; it stays where it is rather than
        // being thrown out of a block the writer is in the middle of filling.
        guard closing > opening + 1 else { return nil }

        let firstCode = opening + 1
        let lastCode = closing - 1
        let target: Int
        if index == opening {
            target = firstCode                      // down off the header, onto the code
        } else {
            target = movingForward ? closing : lastCode
        }
        if index == closing, movingForward {
            // Past the end of the block entirely — the line after it, when there is one.
            guard let after = StructuredText.characterRange(ofLines: (closing + 1)...(closing + 1), in: ns)
            else { return StructuredText.characterRange(ofLines: lastCode...lastCode, in: ns)
                .map { $0.location + $0.length } }
            return after.location
        }
        guard let range = StructuredText.characterRange(ofLines: target...target, in: ns) else { return nil }
        return index == closing ? range.location + range.length : range.location
    }

    /// Whether this line opens a block that `blocks(in:)` would accept.
    static func isOpeningFence(_ line: String) -> Bool { openingFenceLanguage(line) != nil }
}
