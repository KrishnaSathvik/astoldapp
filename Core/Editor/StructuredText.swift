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
        if line.hasPrefix("- [x] ") { return (.checklist(checked: true), 6) }
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

    /// The line containing a source caret offset (a caret at a line's start belongs to that line; a
    /// caret at the trailing newline belongs to the preceding line).
    func line(containingSource offset: Int) -> Line {
        for line in lines {
            if offset <= line.sourceRange.location + line.sourceRange.length { return line }
        }
        return lines.last ?? Line(kind: .paragraph, sourceRange: NSRange(location: 0, length: 0), markerLength: 0)
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

    /// Sets the block kind of the line containing the caret, replacing any existing marker.
    static func setBlockKindEdit(_ kind: BlockKind, text: String, selection: NSRange) -> TextEdit {
        let line = MarkupDocument(text).line(containingSource: selection.location)
        let newMarker = kind.marker
        let newMarkerLength = (newMarker as NSString).length

        let caret: Int
        if selection.location >= line.contentStart {
            caret = selection.location + (newMarkerLength - line.markerLength)
        } else {
            caret = line.sourceRange.location + newMarkerLength
        }
        return TextEdit(range: NSRange(location: line.sourceRange.location, length: line.markerLength),
                        string: newMarker,
                        selection: NSRange(location: caret, length: 0))
    }

    /// Toggles a checklist item at the given source offset; `nil` if that line is not a checklist item.
    static func toggleChecklistEdit(text: String, sourceOffset: Int) -> TextEdit? {
        let line = MarkupDocument(text).line(containingSource: sourceOffset)
        guard case .checklist(let checked) = line.kind else { return nil }
        return TextEdit(range: NSRange(location: line.sourceRange.location, length: line.markerLength),
                        string: BlockKind.checklist(checked: !checked).marker,
                        selection: NSRange(location: sourceOffset, length: 0))
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
