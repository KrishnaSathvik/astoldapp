import Foundation

// What leaves the editor. The note body carries hidden source markers ("# ", "- ", "- [ ] ") that the
// reader never sees, so anything handed to another app — the pasteboard, a Home/search preview — MUST be
// rendered the way the page reads: "Shopping", "• Eggs", "☐ Call Ravi". As Told additionally writes a
// private pasteboard representation holding the raw source, so an internal copy/paste keeps its structure.
// See docs/02-features.md (Milestone A) and RULES.md §1. Offsets are UTF-16, in source coordinates.

extension BlockKind {
    /// The marker the reader actually sees in front of a line ("" when the line is styled instead of
    /// prefixed, as headings are). This is what other apps receive.
    var visibleMarker: String {
        switch self {
        case .paragraph, .heading, .subheading: return ""
        case .bullet: return "• "
        case .numbered(let n): return "\(n). "
        case .checklist(let checked): return checked ? "☑ " : "☐ "
        }
    }
}

enum StructuredTextExport {
    /// Private pasteboard type carrying the raw source, so As Told → As Told keeps structure. Never
    /// registered as a public/exported UTI: no other app is meant to understand it.
    static let pasteboardType = "com.astold.structured-text"

    /// Expands a selection to cover the hidden marker of the line it starts on, so copying a visibly
    /// complete list item copies the item — not its text with the structure sheared off.
    static func copyRange(in source: String, selection: NSRange) -> NSRange {
        let clamped = clamp(selection, to: (source as NSString).length)
        guard clamped.length > 0 else { return clamped }
        let line = MarkupDocument(source).line(containingSource: clamped.location)
        guard line.markerLength > 0,
              clamped.location > line.sourceRange.location,
              clamped.location <= line.contentStart
        else { return clamped }
        let start = line.sourceRange.location
        return NSRange(location: start, length: clamped.length + (clamped.location - start))
    }

    /// The plain text other apps receive for a selection: hidden markers replaced by visible ones.
    static func plainText(from source: String, range: NSRange) -> String {
        let ns = source as NSString
        let range = copyRange(in: source, selection: range)
        guard range.length > 0 else { return "" }
        let end = range.location + range.length

        var out: [String] = []
        for line in MarkupDocument(source).lines {
            let lineEnd = line.sourceRange.location + line.sourceRange.length
            guard lineEnd >= range.location, line.sourceRange.location <= end else { continue }

            let from = max(range.location, line.contentStart)
            let to = min(end, lineEnd)
            let content = to > from ? ns.substring(with: NSRange(location: from, length: to - from)) : ""
            // A line only shows its marker when the selection reached its start; a fragment is words.
            let marker = range.location <= line.contentStart ? line.kind.visibleMarker : ""
            out.append(marker + content)
        }
        return out.joined(separator: "\n")
    }

    /// The whole note as the reader sees it — for Home/search previews and any other read-only surface.
    static func plainText(_ source: String) -> String {
        plainText(from: source, range: NSRange(location: 0, length: (source as NSString).length))
    }

    /// The private representation for a selection: the raw source, or `nil` when the selection carries no
    /// structure and the plain text already says everything.
    static func structuredText(from source: String, range: NSRange) -> String? {
        let range = copyRange(in: source, selection: range)
        guard range.length > 0 else { return nil }
        let substring = (source as NSString).substring(with: range)
        guard MarkupDocument(substring).lines.contains(where: { $0.markerLength > 0 }) else { return nil }
        return substring
    }

    private static func clamp(_ range: NSRange, to length: Int) -> NSRange {
        let location = max(0, min(range.location, length))
        return NSRange(location: location, length: max(0, min(range.length, length - location)))
    }
}
