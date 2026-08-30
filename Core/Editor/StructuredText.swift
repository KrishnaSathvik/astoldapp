import Foundation

// Structured-text model for the As Told editor.
//
// The note body stays a single plain `String` (RULES.md §5) with lightweight, canonical line markers
// the user never sees:
//   "# "      heading
//   "## "     subheading
//   "- "      bullet
//   "1. "     numbered item (any leading integer)
//   "- [ ] "  unchecked checklist item
//   "- [x] "  checked checklist item
//
// This file is the pure, UIKit-free layer: parsing, source<->visible offset mapping, and the shared
// document operations that both typing and (later) voice call. All offsets/ranges are UTF-16 (NSString)
// units, matching UITextView/NSRange/NSAttributedString. Markers are ASCII, so a marker's UTF-16
// length equals its character count.

/// The kind of a single line of the note body.
enum BlockKind: Equatable {
    case paragraph
    case heading
    case subheading
    case bullet
    case numbered(Int)
    case checklist(checked: Bool)
}

extension BlockKind {
    /// The canonical source marker that prefixes a line of this kind ("" for a paragraph).
    var marker: String {
        switch self {
        case .paragraph: return ""
        case .heading: return "# "
        case .subheading: return "## "
        case .bullet: return "- "
        case .numbered(let n): return "\(n). "
        case .checklist(let checked): return checked ? "- [x] " : "- [ ] "
        }
    }

    /// Parses the block kind from a full source line, returning the kind and the UTF-16 length of its
    /// marker prefix (0 for a paragraph).
    static func parse(line: String) -> (kind: BlockKind, markerLength: Int) {
        if line.hasPrefix("## ") { return (.subheading, 3) }
        if line.hasPrefix("# ") { return (.heading, 2) }
        if line.hasPrefix("- [ ] ") { return (.checklist(checked: false), 6) }
        // Tolerated, not canonical: iOS autocapitalization is on by default and a hand reaches for
        // the capital anyway. `StructuredText.canonicalized` puts it back to "- [x] " on save, so
        // this stays an input spelling and never becomes a second stored format.
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return (.checklist(checked: true), 6) }
        if line.hasPrefix("- ") { return (.bullet, 2) }

        // Numbered: one or more ASCII digits followed by ". ".
        var digits = ""
        for ch in line {
            if ch.isASCII, ch.isNumber { digits.append(ch) } else { break }
        }
        if !digits.isEmpty, line.dropFirst(digits.count).hasPrefix(". "), let n = Int(digits) {
            return (.numbered(n), digits.count + 2)
        }

        return (.paragraph, 0)
    }
}

/// Source-level normalization. Parsing is deliberately tolerant of input spellings; storage is not.
enum StructuredText {
    /// Rewrites tolerated marker spellings to their canonical form. Today that is exactly one case:
    /// a checked checklist typed as `- [X] ` becomes `- [x] `.
    ///
    /// Only same-length rewrites belong here. That is what makes it safe to run while an editor is
    /// open — every caret and selection offset in the note stays valid — and it is why numbered
    /// markers are left alone (`007. ` would canonicalize to `7. ` and move the text under the caret).
    /// Longest canonical marker ("- [ ] "), and therefore the only part of a line that can ever be a
    /// structural prefix. Normalization never looks past it.
    static let markerWindow = 6

    /// Characters a keyboard substitutes for the ones a marker needs. Both maps are strictly
    /// length-preserving in UTF-16, which is what lets normalization run as an in-place substitution
    /// without moving a single caret offset.
    private static let dashSubstitutes: Set<Character> = ["\u{2010}", "\u{2011}", "\u{2012}",
                                                          "\u{2013}", "\u{2014}", "\u{2015}",
                                                          "\u{2212}"]
    private static let spaceSubstitutes: Set<Character> = ["\u{00A0}", "\u{202F}", "\u{2007}",
                                                           "\u{2009}"]

    /// Rewrites a line's *structural prefix* to canonical characters — smart dashes back to `-`,
    /// non-breaking spaces back to a plain space, `[X]` to `[x]` — and returns the line unchanged if
    /// the result is not actually a marker.
    ///
    /// That last condition is the whole safety argument. Only the first `markerWindow` characters are
    /// touched, and only when they resolve to a real marker, so ordinary prose is never rewritten:
    /// "I worked 9–5 today." keeps its en dash because the dash is not at a line start, and
    /// "Xylophone" keeps its capital because "xylophone" is not a marker.
    static func normalizedStructuralPrefix(_ line: String) -> String {
        let ns = line as NSString
        let window = min(ns.length, markerWindow)
        guard window > 0 else { return line }

        var head = String(ns.substring(to: window).map { ch -> Character in
            if dashSubstitutes.contains(ch) { return "-" }
            if spaceSubstitutes.contains(ch) { return " " }
            return ch
        })
        if head.hasPrefix("- [X] ") { head = "- [x] " }

        guard head != ns.substring(to: window) else { return line }
        let candidate = head + ns.substring(from: window)
        guard BlockKind.parse(line: candidate).kind != .paragraph else { return line }
        return candidate
    }

    /// The line indices a selection touches, counted by newlines alone.
    ///
    /// Deliberately *not* `MarkupDocument`: this runs on every keystroke and every caret move, and it
    /// only needs to know **where** the selection is, not what any line means. Matches
    /// `MarkupDocument.lineIndex(containingSource:)` at the edges — a caret on a line's trailing
    /// newline belongs to that line, not the next one.
    static func lineIndices(touchedBy selection: NSRange, in text: NSString) -> ClosedRange<Int> {
        let first = lineIndex(of: selection.location, in: text)
        let probe = selection.location + max(0, selection.length - 1)
        return first...max(first, lineIndex(of: probe, in: text))
    }

    static func lineIndex(of offset: Int, in text: NSString) -> Int {
        let clamped = max(0, min(offset, text.length))
        var count = 0
        var index = 0
        while index < clamped {
            if text.character(at: index) == unichar(10) { count += 1 }
            index += 1
        }
        return count
    }

    /// The character range a run of lines spans, counted by newlines alone.
    ///
    /// Card positioning needs to know where a block's lines *are*, not what they mean, and it runs on
    /// every layout pass — so it must not pay for a full `MarkupDocument` parse to find out.
    static func characterRange(ofLines lines: ClosedRange<Int>, in text: NSString) -> NSRange? {
        var start = -1
        var end = -1
        var line = 0
        var index = 0

        if lines.lowerBound == 0 { start = 0 }
        while index <= text.length {
            if index == text.length || text.character(at: index) == unichar(10) {
                if line == lines.upperBound { end = index; break }
                line += 1
                if line == lines.lowerBound { start = index + 1 }
                if index == text.length { break }
            }
            index += 1
        }
        guard start >= 0, end >= start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    static func canonicalized(_ source: String) -> String {
        guard source.contains("- [X] ") else { return source }
        // `- [X] ` inside a fence is a line of code that happens to look like a checklist. Rewriting
        // it would edit someone's code on save (RULES.md §7, code blocks are literal).
        let literal = source.contains(CodeBlock.fence)
            ? CodeBlock.literalLineIndices(in: source) : []
        return source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, line -> Substring in
                guard !literal.contains(index) else { return line }
                return line.hasPrefix("- [X] ") ? Substring("- [x] " + line.dropFirst(6)) : line
            }
            .joined(separator: "\n")
    }
}

/// A parsed, read-only view of a note body: its lines and the mapping between source offsets (with
/// markers and link syntax) and visible offsets (both hidden).
struct MarkupDocument {
    struct Line: Equatable {
        let kind: BlockKind
        /// Range of the whole line in the source string, excluding the trailing "\n".
        let sourceRange: NSRange
        /// UTF-16 length of this line's marker prefix.
        let markerLength: Int
        /// Whether these characters are code inside a fence. A literal line has no marker and no
        /// links: its `#` is a comment and its `- ` is a YAML item, not structure (`CodeBlock`).
        let isLiteral: Bool
        /// The links in this line's content, each carrying the runs of syntax that stay hidden.
        let links: [LinkSpan]

        init(kind: BlockKind, sourceRange: NSRange, markerLength: Int,
             isLiteral: Bool = false, links: [LinkSpan] = []) {
            self.kind = kind
            self.sourceRange = sourceRange
            self.markerLength = markerLength
            self.isLiteral = isLiteral
            self.links = links
        }

        var contentLength: Int { sourceRange.length - markerLength }
        var contentStart: Int { sourceRange.location + markerLength }

        /// Runs inside this line whose glyphs are hidden *beyond* the marker prefix — today, exactly
        /// the bracket-and-destination syntax of a labelled link. Empty on almost every line, and the
        /// emptiness is what keeps the offset arithmetic below identical to what it was before links
        /// existed.
        var hiddenRuns: [NSRange] { links.flatMap(\.hiddenRuns) }
        var hiddenLength: Int { hiddenRuns.reduce(0) { $0 + $1.length } }
        /// How many characters of this line the reader actually sees.
        var visibleLength: Int { contentLength - hiddenLength }

        /// How many hidden characters sit strictly before `sourceOffset` on this line.
        func hiddenLength(before sourceOffset: Int) -> Int {
            hiddenRuns.reduce(0) { $0 + max(0, min($1.length, sourceOffset - $1.location)) }
        }

        /// The hidden run a caret at `sourceOffset` would be sitting *inside*. A caret at a run's
        /// leading edge is not inside it — it is at the end of the words before it, which is a place
        /// a writer is allowed to be.
        func hiddenRun(containing sourceOffset: Int) -> NSRange? {
            hiddenRuns.first { sourceOffset > $0.location && sourceOffset < $0.location + $0.length }
        }
    }

    let source: String
    let lines: [Line]

    init(_ source: String) {
        self.source = source
        let ns = source as NSString

        // Two fast paths, and they are a contract rather than an optimization: a note holding no
        // fence and no link runs exactly the arithmetic it ran before either existed.
        let literal = source.contains(CodeBlock.fence)
            ? CodeBlock.literalLineIndices(in: source) : []
        // `range(of:options:)` rather than a localized contains: this runs once per note on Home and
        // in search, and locale-aware comparison is the expensive kind.
        let mayHoldLinks = source.contains("[")
            || source.range(of: "http", options: .caseInsensitive) != nil

        var lines: [Line] = []
        var start = 0
        var idx = 0
        let newline = unichar(10)
        while idx <= ns.length {
            if idx == ns.length || ns.character(at: idx) == newline {
                let lineRange = NSRange(location: start, length: idx - start)
                let lineStr = ns.substring(with: lineRange)

                if literal.contains(lines.count) {
                    lines.append(Line(kind: .paragraph, sourceRange: lineRange,
                                      markerLength: 0, isLiteral: true))
                } else {
                    let (kind, markerLen) = BlockKind.parse(line: lineStr)
                    var links: [LinkSpan] = []
                    if mayHoldLinks {
                        links = LinkSpan.links(inLineContent: (lineStr as NSString).substring(from: markerLen),
                                               offset: start + markerLen)
                    }
                    lines.append(Line(kind: kind, sourceRange: lineRange,
                                      markerLength: markerLen, links: links))
                }
                start = idx + 1
                if idx == ns.length { break }
            }
            idx += 1
        }
        self.lines = lines
    }

    /// Every link in the note, in source order.
    var links: [LinkSpan] { lines.flatMap(\.links) }

    /// The link a source offset falls inside — what a tap resolves to.
    func link(atSource offset: Int) -> LinkSpan? {
        links.first { offset >= $0.sourceRange.location
            && offset < $0.sourceRange.location + $0.sourceRange.length }
    }

    /// Whether a caret sits in code, where the Style menu MUST NOT write a marker (RULES.md §7).
    func isLiteral(atSource offset: Int) -> Bool {
        guard !lines.isEmpty else { return false }
        return lines[lineIndex(containingSource: offset)].isLiteral
    }

    /// The text the user actually sees: every line with its marker and link syntax removed, rejoined
    /// with "\n".
    func visibleText() -> String {
        lines.map(visibleText(of:)).joined(separator: "\n")
    }

    /// One line as the reader sees it.
    func visibleText(of line: Line) -> String {
        let ns = source as NSString
        let content = NSRange(location: line.contentStart, length: line.contentLength)
        guard !line.hiddenRuns.isEmpty else { return ns.substring(with: content) }

        var out = ""
        var cursor = line.contentStart
        let end = line.contentStart + line.contentLength
        for run in line.hiddenRuns.sorted(by: { $0.location < $1.location }) {
            if run.location > cursor {
                out += ns.substring(with: NSRange(location: cursor, length: run.location - cursor))
            }
            cursor = max(cursor, run.location + run.length)
        }
        if end > cursor { out += ns.substring(with: NSRange(location: cursor, length: end - cursor)) }
        return out
    }

    /// Maps a source (with-marker) UTF-16 offset to the corresponding visible offset. An offset that
    /// lands inside a hidden marker clamps to that line's visible content start; one that lands
    /// inside hidden link syntax clamps to the end of the words before it.
    func visibleOffset(forSource sourceOffset: Int) -> Int {
        var visibleBase = 0
        for line in lines {
            let lineEnd = line.sourceRange.location + line.sourceRange.length
            if sourceOffset <= lineEnd {
                let withinContent = max(0, sourceOffset - line.contentStart)
                let visible = withinContent - line.hiddenLength(before: sourceOffset)
                return visibleBase + min(max(0, visible), line.visibleLength)
            }
            visibleBase += line.visibleLength + 1   // + the newline separator
        }
        return visibleBase
    }

    /// Maps a visible UTF-16 offset to the corresponding source offset (landing at content, never
    /// inside a hidden marker and never inside hidden link syntax).
    func sourceOffset(forVisible visibleOffset: Int) -> Int {
        var visibleBase = 0
        for line in lines {
            if visibleOffset <= visibleBase + line.visibleLength {
                return sourceOffset(in: line, visibleWithinLine: visibleOffset - visibleBase)
            }
            visibleBase += line.visibleLength + 1
        }
        return (source as NSString).length
    }

    /// Walks a line's content, stepping over hidden runs rather than through them, so a visible
    /// offset always lands on a character the reader can see.
    private func sourceOffset(in line: Line, visibleWithinLine target: Int) -> Int {
        guard !line.hiddenRuns.isEmpty else { return line.contentStart + target }
        let runs = line.hiddenRuns.sorted { $0.location < $1.location }
        let end = line.contentStart + line.contentLength
        var offset = line.contentStart
        var seen = 0

        while offset < end, seen < target {
            if let run = runs.first(where: { offset >= $0.location && offset < $0.location + $0.length }) {
                offset = run.location + run.length
                continue
            }
            offset += 1
            seen += 1
        }
        return min(offset, end)
    }

    /// The index of the line containing a source caret offset (a caret at a line's start belongs to
    /// that line; a caret at the trailing newline belongs to the preceding line).
    func lineIndex(containingSource offset: Int) -> Int {
        for (index, line) in lines.enumerated() {
            if offset <= line.sourceRange.location + line.sourceRange.length { return index }
        }
        return max(0, lines.count - 1)
    }

    /// The line containing a source caret offset. See `lineIndex(containingSource:)`.
    func line(containingSource offset: Int) -> Line {
        guard !lines.isEmpty else {
            return Line(kind: .paragraph, sourceRange: NSRange(location: 0, length: 0), markerLength: 0)
        }
        return lines[lineIndex(containingSource: offset)]
    }

    /// Where a caret sitting **inside** hidden link syntax has to go, or `nil` when it is already
    /// somewhere the reader can see.
    ///
    /// The same rule a hidden block marker has always had, generalised to the syntax links introduced:
    /// a run with no glyphs is not a place. Every offset inside `](https://…)` draws at the same point
    /// on screen, so a caret left there is invisible — and the next character to arrive lands in the
    /// middle of the destination, which silently turns a link into the literal brackets it was written
    /// with and loses where it went (RULES.md §4).
    ///
    /// A caret at a run's edge is *not* inside it: those are the end of the words before the link and
    /// the start of whatever follows it, and both are places a writer is allowed to be.
    ///
    /// - Parameter movingForward: which way the caret was travelling, so it leaves the way it came in.
    func caretEscapingHiddenSyntax(from offset: Int, movingForward: Bool) -> Int? {
        guard !lines.isEmpty else { return nil }
        guard let run = lines[lineIndex(containingSource: offset)].hiddenRun(containing: offset)
        else { return nil }
        return movingForward ? run.location + run.length : run.location
    }

    /// The indices of every line the selection touches — the range a block-kind change applies to.
    ///
    /// A selection that ends exactly at a line's start has taken the preceding newline and nothing
    /// else of that line, so the line is not included: "select the first two lines" in a text view
    /// commonly means a range ending at the third line's offset, and converting three lines there
    /// would style one the user never touched.
    func lineIndices(touchedBy selection: NSRange) -> ClosedRange<Int> {
        let first = lineIndex(containingSource: selection.location)
        let lastProbe = selection.location + max(0, selection.length - 1)
        let last = max(first, lineIndex(containingSource: lastProbe))
        return first...last
    }
}

/// A single minimal text edit: the source range to replace, what to put there, and where the caret ends
/// up. The editor applies these through the text view's own edit primitive, so one user action registers
/// exactly one undo step; voice applies them to a plain string. Offsets are UTF-16, source coordinates.
struct TextEdit: Equatable {
    var range: NSRange
    var string: String
    var selection: NSRange

    func applied(to text: String) -> (text: String, selection: NSRange) {
        ((text as NSString).replacingCharacters(in: range, with: string), selection)
    }

    /// The edit that puts the text back exactly as it was, with the caret where the user left it. The
    /// editor registers this with the undo manager so one user action is one undo step.
    func inverse(in text: String, caret: NSRange) -> TextEdit {
        TextEdit(range: NSRange(location: range.location, length: (string as NSString).length),
                 string: (text as NSString).substring(with: range),
                 selection: caret)
    }

    /// The minimal single-range edit turning `old` into `new`, for changes that arrive as a whole new
    /// string (a voice transcript). Applying the difference rather than reassigning keeps the change one
    /// undoable step. Boundaries never split a surrogate pair.
    static func diff(from old: String, to new: String, caret: NSRange) -> TextEdit {
        let oldText = old as NSString
        let newText = new as NSString

        var prefix = 0
        let shortest = min(oldText.length, newText.length)
        while prefix < shortest, oldText.character(at: prefix) == newText.character(at: prefix) { prefix += 1 }

        var suffix = 0
        while suffix < shortest - prefix,
              oldText.character(at: oldText.length - 1 - suffix) == newText.character(at: newText.length - 1 - suffix) {
            suffix += 1
        }

        // Both ends must sit on a character boundary in both strings: a UTF-16 offset inside a surrogate
        // pair or a combining sequence is not a position the text view can be asked to replace.
        while prefix > 0, !(isCharacterBoundary(prefix, in: old) && isCharacterBoundary(prefix, in: new)) {
            prefix -= 1
        }
        while suffix > 0,
              !(isCharacterBoundary(oldText.length - suffix, in: old)
                && isCharacterBoundary(newText.length - suffix, in: new)) {
            suffix -= 1
        }

        let range = NSRange(location: prefix, length: oldText.length - prefix - suffix)
        let inserted = newText.substring(with: NSRange(location: prefix, length: newText.length - prefix - suffix))
        return TextEdit(range: range, string: inserted, selection: caret)
    }

    private static func isCharacterBoundary(_ utf16Offset: Int, in text: String) -> Bool {
        let units = text.utf16
        guard let index = units.index(units.startIndex, offsetBy: utf16Offset, limitedBy: units.endIndex)
        else { return false }
        return index.samePosition(in: text) != nil
    }
}

/// Pure editing operations shared by typing and voice. Each is expressed as the one `TextEdit` it
/// performs; the whole-text variants below are thin wrappers for callers that build a string rather than
/// drive a text view. Selection and offsets are UTF-16, in **source** coordinates. `nil` means the caller
/// should let the default text-view behavior happen.
enum DocumentAction {

    // MARK: Edits

    /// Sets the block kind of every line the selection touches, replacing any existing markers.
    ///
    /// One `TextEdit`, always — a caret on one line produces the minimal marker-sized replacement, and
    /// a selection across four lines produces a single span covering all four. That is what makes a
    /// multi-line conversion one undo step: the editor registers exactly one inverse per edit it
    /// applies, so four lines becoming a checklist undo together, as the one thing the user did.
    ///
    /// Two per-line details are resolved here rather than by the caller, because only this function can
    /// see the lines around the selection:
    ///  - **Numbering** continues from the numbered line immediately above the selection (a paragraph
    ///    under "2." becomes "3."), and runs in sequence across the selection. Nothing outside the
    ///    selection is renumbered — a conversion must not rewrite lines the user did not select.
    ///  - **A ticked checklist item stays ticked.** Re-applying Checklist to a list half worked through
    ///    would otherwise silently clear it, and the control has to be safe to tap twice.
    static func setBlockKindEdit(_ kind: BlockKind, text: String, selection: NSRange) -> TextEdit {
        let doc = MarkupDocument(text)
        let indices = doc.lineIndices(touchedBy: selection)
        let ns = text as NSString

        // Numbering starts from the line above the selection, so converting under an existing list
        // continues it instead of restarting at 1.
        var counter = 1
        if case .numbered = kind, indices.lowerBound > 0,
           case .numbered(let above) = doc.lines[indices.lowerBound - 1].kind {
            counter = above + 1
        }

        var markers: [String] = []
        var pieces: [String] = []
        var deltas: [Int] = []
        for index in indices {
            let line = doc.lines[index]
            // Code is not structure. A selection that crosses a fence styles the prose around it and
            // leaves every code line exactly as written (RULES.md §7).
            guard !line.isLiteral else {
                markers.append("")
                pieces.append(ns.substring(with: line.sourceRange))
                deltas.append(0)
                continue
            }
            let resolved: BlockKind
            switch kind {
            case .numbered:
                resolved = .numbered(counter)
                counter += 1
            case .checklist(let checked):
                if case .checklist(let already) = line.kind {
                    resolved = .checklist(checked: already)
                } else {
                    resolved = .checklist(checked: checked)
                }
            default:
                resolved = kind
            }
            let marker = resolved.marker
            let content = ns.substring(with: NSRange(location: line.contentStart, length: line.contentLength))
            markers.append(marker)
            pieces.append(marker + content)
            deltas.append((marker as NSString).length - line.markerLength)
        }

        /// Where a source offset lands once the markers have been rewritten.
        ///
        /// `snapIntoContent` is the difference between a caret and the start of a selection. A caret
        /// must never sit inside a hidden marker, so it snaps forward to the line's first visible
        /// character. A selection that began at a line start means "this whole line", and snapping it
        /// forward would leave the new marker outside the selection it created.
        func mapped(_ offset: Int, snapIntoContent: Bool) -> Int {
            var cumulative = 0
            for (step, index) in indices.enumerated() {
                let line = doc.lines[index]
                if offset <= line.sourceRange.location + line.sourceRange.length {
                    if !snapIntoContent, offset <= line.sourceRange.location {
                        return line.sourceRange.location + cumulative
                    }
                    return max(offset, line.contentStart) + cumulative + deltas[step]
                }
                cumulative += deltas[step]
            }
            return offset + cumulative
        }

        let isCaret = selection.length == 0
        let start = mapped(selection.location, snapIntoContent: isCaret)
        let end = mapped(selection.location + selection.length, snapIntoContent: true)
        let newSelection = NSRange(location: start, length: max(0, end - start))

        // A single line changes only its marker: the smallest edit the text view can be asked to make,
        // which keeps a one-line conversion from relaying out the whole paragraph.
        if indices.count == 1 {
            let line = doc.lines[indices.lowerBound]
            return TextEdit(range: NSRange(location: line.sourceRange.location, length: line.markerLength),
                            string: markers[0],
                            selection: newSelection)
        }

        let first = doc.lines[indices.lowerBound]
        let last = doc.lines[indices.upperBound]
        let span = NSRange(location: first.sourceRange.location,
                           length: last.sourceRange.location + last.sourceRange.length - first.sourceRange.location)
        return TextEdit(range: span, string: pieces.joined(separator: "\n"), selection: newSelection)
    }

    /// Toggles a checklist item at the given source offset; `nil` if that line is not a checklist item.
    static func toggleChecklistEdit(text: String, sourceOffset: Int) -> TextEdit? {
        let line = MarkupDocument(text).line(containingSource: sourceOffset)
        guard case .checklist(let checked) = line.kind else { return nil }
        // Never inside the hidden marker, even when the caller asked from the line's start. Both
        // editor callers pass a caret of their own and never read this, but a primitive that hands
        // back the one offset the editor guarantees a caret never occupies is a trap for the next one.
        return TextEdit(range: NSRange(location: line.sourceRange.location, length: line.markerLength),
                        string: BlockKind.checklist(checked: !checked).marker,
                        selection: NSRange(location: max(sourceOffset, line.contentStart), length: 0))
    }

    /// Return: continues a list/checklist, exits an empty list item, otherwise `nil` (default behavior).
    static func returnEdit(text: String, selection: NSRange) -> TextEdit? {
        guard selection.length == 0 else { return nil }
        let line = MarkupDocument(text).line(containingSource: selection.location)

        let nextMarker: String
        switch line.kind {
        case .bullet: nextMarker = BlockKind.bullet.marker
        case .checklist: nextMarker = BlockKind.checklist(checked: false).marker
        case .numbered(let n): nextMarker = BlockKind.numbered(n + 1).marker
        case .paragraph, .heading, .subheading: return nil
        }

        // Empty item → exit the list: this line becomes a plain paragraph.
        if line.contentLength == 0 {
            return TextEdit(range: NSRange(location: line.sourceRange.location, length: line.markerLength),
                            string: "",
                            selection: NSRange(location: line.sourceRange.location, length: 0))
        }

        let insertion = "\n" + nextMarker
        return TextEdit(range: selection,
                        string: insertion,
                        selection: NSRange(location: selection.location + (insertion as NSString).length, length: 0))
    }

    /// Typing the character that completes a marker the keyboard has quietly altered fixes the
    /// altered characters in place, so `– ` becomes a bullet and `#\u{00A0}` becomes a heading.
    ///
    /// Runs only at the moment the marker is completed, on a line whose prefix is nothing but that
    /// marker. Ordinary prose never reaches it: the substitution has to resolve to a real marker at a
    /// line start, so an en dash mid-sentence — or a line that merely begins with one and goes on to
    /// be a sentence — is left exactly as written. Length-preserving, so it is one in-place edit.
    static func prefixNormalizationEdit(text: String, selection: NSRange,
                                        replacementText: String) -> TextEdit? {
        guard selection.length == 0, !replacementText.isEmpty, !replacementText.contains("\n") else {
            return nil
        }
        let line = MarkupDocument(text).line(containingSource: selection.location)
        guard line.kind == .paragraph, !line.isLiteral else { return nil }

        let ns = text as NSString
        let caretInLine = selection.location - line.sourceRange.location
        guard caretInLine >= 0, caretInLine <= line.sourceRange.length else { return nil }

        let lineText = ns.substring(with: line.sourceRange) as NSString
        let prospective = lineText.replacingCharacters(
            in: NSRange(location: caretInLine, length: 0), with: replacementText
        )
        let normalized = StructuredText.normalizedStructuralPrefix(prospective)
        guard normalized != prospective else { return nil }

        let (kind, markerLength) = BlockKind.parse(line: normalized)
        // Only at the instant the marker is completed — the caret must land exactly at its end.
        guard kind != .paragraph,
              caretInLine + (replacementText as NSString).length == markerLength else { return nil }

        // The canonical marker replaces the raw prefix *and* supplies the character just typed, so a
        // non-breaking space the writer pressed does not survive into the source.
        return TextEdit(
            range: NSRange(location: line.sourceRange.location, length: caretInLine),
            string: kind.marker,
            selection: NSRange(location: line.sourceRange.location + markerLength, length: 0)
        )
    }

    /// Typing a different complete marker on a line that holds *only* a marker replaces it, rather
    /// than becoming its content. Return leaves the caret exactly there, so this is the moment a
    /// writer changes their mind: continue a bullet, then type "1. " and get a numbered item.
    ///
    /// Deliberately narrow. The line must be structured and otherwise empty, the caret must be at its
    /// end, and what the writer typed must form a *complete* marker of a *different* kind — so a line
    /// with words is never rewritten underneath them, and a no-op swap never costs an undo step.
    /// Because "- " is a prefix of "- [ ] ", bullet-to-bullet is skipped here, which is what lets the
    /// writer keep typing and land on a checklist.
    static func markerReplacementEdit(text: String, selection: NSRange,
                                      replacementText: String) -> TextEdit? {
        guard selection.length == 0, !replacementText.isEmpty, !replacementText.contains("\n") else {
            return nil
        }
        let line = MarkupDocument(text).line(containingSource: selection.location)
        guard line.kind != .paragraph else { return nil }
        let lineEnd = line.sourceRange.location + line.sourceRange.length
        guard selection.location == lineEnd else { return nil }

        let ns = text as NSString
        let content = ns.substring(with: NSRange(location: line.contentStart, length: line.contentLength))
        let candidate = content + replacementText
        let (kind, markerLength) = BlockKind.parse(line: candidate)
        guard kind != .paragraph,
              markerLength == (candidate as NSString).length,
              kind != line.kind else { return nil }

        let marker = kind.marker
        return TextEdit(
            range: line.sourceRange,
            string: marker,
            selection: NSRange(location: line.sourceRange.location + (marker as NSString).length, length: 0)
        )
    }

    /// Backspace at the start of a structured line demotes it to a paragraph; otherwise `nil`.
    static func backspaceEdit(text: String, selection: NSRange) -> TextEdit? {
        guard selection.length == 0 else { return nil }
        let doc = MarkupDocument(text)
        let line = doc.line(containingSource: selection.location)

        // Backspace at the start of the first row of a table joins it to the **header**, taking the
        // hidden delimiter row with it. Without this it would join the row to a line the writer cannot
        // see, leaving `| --- | --- || 20×30 |` — a delimiter with data welded onto it, which stops
        // being a delimiter and takes the table with it. The remaining rows still read as a table:
        // `TableBlock` accepts two pipe rows without a rule (RULES.md §7).
        if selection.location == line.sourceRange.location, line.sourceRange.location > 0 {
            let index = doc.lineIndex(containingSource: selection.location)
            if index > 0, TableBlock.isHiddenDelimiter(in: text, atLine: index - 1),
               let delimiter = StructuredText.characterRange(ofLines: (index - 1)...(index - 1),
                                                             in: text as NSString) {
                // From the end of the header line through the delimiter's own trailing newline.
                let start = delimiter.location - 1
                let length = selection.location - start
                return TextEdit(range: NSRange(location: start, length: length),
                                string: "",
                                selection: NSRange(location: start, length: 0))
            }
        }

        guard line.kind != .paragraph, selection.location == line.contentStart else { return nil }
        return TextEdit(range: NSRange(location: line.sourceRange.location, length: line.markerLength),
                        string: "",
                        selection: NSRange(location: line.sourceRange.location, length: 0))
    }

    /// The edit a paste performs. Pasted As Told text carries source markers, so this decides whether the
    /// pasted structure owns the caret's line — it may only when nothing of that line survives the paste.
    /// Otherwise the first pasted line joins as words with its marker dropped: a marker must never land
    /// mid-line, where it would be read as literal text.
    static func pasteEdit(_ pasted: String, text: String, selection: NSRange) -> TextEdit {
        let firstLine = String(pasted.prefix(while: { $0 != "\n" }))
        let (_, pastedMarkerLength) = BlockKind.parse(line: firstLine)
        guard pastedMarkerLength > 0 else { return edit(replacing: selection, with: pasted) }

        let line = MarkupDocument(text).line(containingSource: selection.location)
        let selectionEnd = selection.location + selection.length
        let lineEnd = line.sourceRange.location + line.sourceRange.length
        let lineIsEmptied = selection.location <= line.contentStart && selectionEnd >= lineEnd

        guard lineIsEmptied else {
            let stripped = (pasted as NSString)
                .replacingCharacters(in: NSRange(location: 0, length: pastedMarkerLength), with: "")
            return edit(replacing: selection, with: stripped)
        }

        let replaced = NSRange(location: line.sourceRange.location,
                               length: selectionEnd - line.sourceRange.location)
        return edit(replacing: replaced, with: pasted)
    }

    /// The edit **Paste as Code** performs: the clipboard's characters, fenced, as their own block.
    ///
    /// This exists because of a real clipboard. A "Copy code" button in a chat app or a docs site
    /// frequently puts nothing but `public.utf8-plain-text` on the pasteboard — no `<pre>`, no
    /// `language-…` class, no fences — so the code's *code-ness* was discarded before As Told ever saw
    /// it, and there is nothing to preserve. The importer is right to leave that text alone (§2, §4);
    /// what was missing was a way for the person who knows to say so.
    ///
    /// So it is explicit, and it is the writer's word, not a guess: nothing here reads the text to
    /// decide whether it looks like code. The characters are inserted exactly as they arrived, between
    /// fences that are ordinary characters in `body` like every other structure As Told holds (§5).
    ///
    /// - Note: no language is written. The clipboard did not state one, and inventing `sql` from the
    ///   presence of the word `SELECT` is the guess this whole path exists to avoid — so the block
    ///   renders as a card with no label and no syntax colour, which is the honest rendering of what
    ///   is known about it.
    /// - Parameter language: the language to write on the opening fence. `nil` for **Paste as Code**,
    ///   which states none because the writer stated none; a detected language for an automatic fence
    ///   (`CodeDetection`), where the block was recognised *as* that language and the card can label
    ///   and colour it.
    static func pasteAsCodeEdit(_ pasted: String, language: String? = nil,
                                text: String, selection: NSRange) -> TextEdit? {
        guard !pasted.isEmpty else { return nil }

        // Anything that already carries a fence line is inserted **as it stands**, never wrapped.
        //
        // Two different cases, one answer, and the answer is the storage format's rather than a
        // preference. `CodeBlock` closes a block at the first bare ` ``` `, so a fence placed around
        // text that contains one is closed by *that* line instead of by its own — the block breaks in
        // half and the tail becomes loose text. There is no longer fence to escape with: the parser
        // recognises exactly three backticks (nested fences are out of scope, `CodeBlock`).
        //
        //  - A **complete** fenced block — the clipboard stated its own structure, language included —
        //    is what a writer means by "already code", and it keeps everything it declared.
        //  - A **stray** fence, or a fence with prose around it, cannot be represented wrapped. Every
        //    character still lands in `body` exactly as copied; what it renders as is then whatever
        //    those characters honestly are, which is what normal Paste would have produced.
        let lines = pasted.components(separatedBy: "\n")
        let wholeThing = 0...(lines.count - 1)
        let isOneCompleteBlock = CodeBlock.blocks(in: pasted).first?.lineRange == wholeThing
        let carriesAFenceLine = lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix(CodeBlock.fence) }
        let body = isOneCompleteBlock || carriesAFenceLine
            ? pasted
            : CodeBlock.source(code: pasted, language: language)

        // A fence has to start its own line, and the closing fence has to be followed by one —
        // otherwise the fence is mid-sentence and is not a fence at all. Both boundaries are supplied
        // only when the text does not already have them: the newline the caret was sitting in front of
        // is the block's closing boundary, and adding a second one leaves an empty paragraph behind.
        let ns = text as NSString
        let line = MarkupDocument(text).line(containingSource: selection.location)
        let selectionEnd = selection.location + selection.length
        let atLineStart = selection.location <= line.sourceRange.location
        let followedByNewline = selectionEnd < ns.length && ns.character(at: selectionEnd) == unichar(10)

        var inserted = body
        if !atLineStart { inserted = "\n" + inserted }
        if !followedByNewline { inserted += "\n" }

        // The caret lands on the line *after* the block. The writer asked for a block of code, not for
        // the caret to be inside one — and a caret in the fence would put the card back into source the
        // moment it arrived, which is why the closing boundary above is written even at the end of the
        // note: without a line after the block there is nowhere outside it for the caret to be.
        let caret = selection.location + (inserted as NSString).length + (followedByNewline ? 1 : 0)
        return TextEdit(range: selection, string: inserted,
                        selection: NSRange(location: caret, length: 0))
    }

    /// The edit **Paste as Preformatted** performs: the clipboard's characters, fenced as plain text,
    /// as their own block.
    ///
    /// The sibling of `pasteAsCodeEdit` and the same argument. An ASCII diagram, a directory tree, or a
    /// column of aligned figures arrives on the pasteboard as nothing but `public.utf8-plain-text`, and
    /// its alignment — which is the entire content — has no way to say so. As Told will not read the
    /// characters and decide they are a diagram; that inference does not exist and is not wanted
    /// (RULES.md §4, and `CodeDetection` for why the one amendment is narrow). This is the writer
    /// saying it, and every character is inserted exactly as it arrived.
    ///
    /// The only difference from **Paste as Code** is the word on the fence: `text` rather than nothing,
    /// so the card's header can say **Plain text** and no syntax colour is looked for.
    static func pasteAsPreformattedEdit(_ pasted: String,
                                        text: String, selection: NSRange) -> TextEdit? {
        pasteAsCodeEdit(pasted, language: CodeBlock.preformattedLanguage,
                        text: text, selection: selection)
    }

    /// Inserts text at the selection, replacing any selected range.
    static func insertEdit(_ string: String, selection: NSRange) -> TextEdit {
        edit(replacing: selection, with: string)
    }

    /// Opens an ordinary paragraph after a note that **ends inside a rendered block**, or `nil` when
    /// there is already somewhere to write.
    ///
    /// A code fence, a preformatted fence and a table are all drawn as a card over source the reader
    /// never sees, and when one of them is the last thing in `body` there is no line after it to put a
    /// caret on. `CodeBlock.caretEscape` will not leave a caret on a fence — rightly, since the next
    /// keystroke would land inside ```` ```sql ```` and break the block back into prose — and with the
    /// closing fence as the last line there is nothing to escape *to*, so every tap under the card was
    /// pushed back inside the code. A block was a dead end, which is not a thing a writing app may
    /// have (fixed 2026-08-28).
    ///
    /// One newline, and only when it is asked for. Nothing appends a paragraph to a block in advance:
    /// a note that ends in a block is a perfectly good note until somebody wants to write past it, and
    /// a blank line nobody typed would be in `body`, in Share, and in every copy of it (RULES.md §5 —
    /// the note is the string, and nothing writes into it that the writer did not).
    static func continuePastTerminalBlockEdit(text: String) -> TextEdit? {
        // Asked on every tap, so the overwhelmingly common answer is reached without parsing anything:
        // a note holding neither a fence nor a pipe cannot end in a block.
        guard text.contains(CodeBlock.fence) || text.contains("|") else { return nil }
        let ns = text as NSString
        guard ns.length > 0 else { return nil }
        let last = StructuredText.lineIndex(of: ns.length, in: ns)
        let endsInsideABlock = CodeBlock.blocks(in: text).contains { $0.lineRange.upperBound == last }
            || TableBlock.tables(in: text).contains { $0.lineRange.upperBound == last }
        guard endsInsideABlock else { return nil }
        return edit(replacing: NSRange(location: ns.length, length: 0), with: "\n")
    }

    private static func edit(replacing range: NSRange, with string: String) -> TextEdit {
        TextEdit(range: range,
                 string: string,
                 selection: NSRange(location: range.location + (string as NSString).length, length: 0))
    }

    // MARK: Whole-text wrappers (voice and other non-interactive callers)

    static func setBlockKind(_ kind: BlockKind, text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        setBlockKindEdit(kind, text: text, selection: selection).applied(to: text)
    }

    static func toggleChecklist(text: String, sourceOffset: Int) -> (text: String, selection: NSRange)? {
        toggleChecklistEdit(text: text, sourceOffset: sourceOffset)?.applied(to: text)
    }

    static func handleReturn(text: String, selection: NSRange) -> (text: String, selection: NSRange)? {
        returnEdit(text: text, selection: selection)?.applied(to: text)
    }

    static func handleBackspace(text: String, selection: NSRange) -> (text: String, selection: NSRange)? {
        backspaceEdit(text: text, selection: selection)?.applied(to: text)
    }

    static func pasteStructured(_ pasted: String, text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        pasteEdit(pasted, text: text, selection: selection).applied(to: text)
    }

    static func insertText(_ string: String, text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        insertEdit(string, selection: selection).applied(to: text)
    }
}
