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

    static func canonicalized(_ source: String) -> String {
        guard source.contains("- [X] ") else { return source }
        return source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                line.hasPrefix("- [X] ") ? Substring("- [x] " + line.dropFirst(6)) : line
            }
            .joined(separator: "\n")
    }
}

/// A parsed, read-only view of a note body: its lines and the mapping between source offsets (with
/// markers) and visible offsets (markers hidden).
struct MarkupDocument {
    struct Line: Equatable {
        let kind: BlockKind
        /// Range of the whole line in the source string, excluding the trailing "\n".
        let sourceRange: NSRange
        /// UTF-16 length of this line's marker prefix.
        let markerLength: Int

        var contentLength: Int { sourceRange.length - markerLength }
        var contentStart: Int { sourceRange.location + markerLength }
    }

    let source: String
    let lines: [Line]

    init(_ source: String) {
        self.source = source
        let ns = source as NSString
        var lines: [Line] = []
        var start = 0
        var idx = 0
        let newline = unichar(10)
        while idx <= ns.length {
            if idx == ns.length || ns.character(at: idx) == newline {
                let lineRange = NSRange(location: start, length: idx - start)
                let lineStr = ns.substring(with: lineRange)
                let (kind, markerLen) = BlockKind.parse(line: lineStr)
                lines.append(Line(kind: kind, sourceRange: lineRange, markerLength: markerLen))
                start = idx + 1
                if idx == ns.length { break }
            }
            idx += 1
        }
        self.lines = lines
    }

    /// The text the user actually sees: every line with its marker removed, rejoined with "\n".
    func visibleText() -> String {
        let ns = source as NSString
        return lines.map {
            ns.substring(with: NSRange(location: $0.contentStart, length: $0.contentLength))
        }.joined(separator: "\n")
    }

    /// Maps a source (with-marker) UTF-16 offset to the corresponding visible offset. An offset that
    /// lands inside a hidden marker clamps to that line's visible content start.
    func visibleOffset(forSource sourceOffset: Int) -> Int {
        var visibleBase = 0
        for line in lines {
            let lineEnd = line.sourceRange.location + line.sourceRange.length
            if sourceOffset <= lineEnd {
                let withinContent = max(0, sourceOffset - line.contentStart)
                return visibleBase + min(withinContent, line.contentLength)
            }
            visibleBase += line.contentLength + 1   // + the newline separator
        }
        return visibleBase
    }

    /// Maps a visible UTF-16 offset to the corresponding source offset (landing at content, never
    /// inside a hidden marker).
    func sourceOffset(forVisible visibleOffset: Int) -> Int {
        var visibleBase = 0
        for line in lines {
            if visibleOffset <= visibleBase + line.contentLength {
                return line.contentStart + (visibleOffset - visibleBase)
            }
            visibleBase += line.contentLength + 1
        }
        return (source as NSString).length
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
        guard line.kind == .paragraph else { return nil }

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
        let line = MarkupDocument(text).line(containingSource: selection.location)
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

    /// Inserts text at the selection, replacing any selected range.
    static func insertEdit(_ string: String, selection: NSRange) -> TextEdit {
        edit(replacing: selection, with: string)
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
