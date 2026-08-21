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

    /// What VoiceOver is told sits in front of a line.
    ///
    /// A glyph is not an announcement. `☐` and `☑` are the entire difference between an item still to
    /// do and one already done, and read as characters they are either silence or noise — so the box
    /// is spoken as the state it draws. A number reads as itself; a heading is announced by nothing,
    /// because its words are the announcement and inventing one would put text in the note's mouth.
    var spokenMarker: String {
        switch self {
        case .paragraph, .heading, .subheading: return ""
        case .bullet: return "Bullet, "
        case .numbered(let n): return "\(n). "
        case .checklist(let checked): return checked ? "Checked, " : "Unchecked, "
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

    /// The whole note as the pasteboard receives it. Markers become their visible glyphs; a table keeps
    /// its source, which is the documented contract for copying one out (docs/02-features.md).
    static func plainText(_ source: String) -> String {
        plainText(from: source, range: NSRange(location: 0, length: (source as NSString).length))
    }

    // MARK: Reading surfaces
    //
    // A note page draws its tables — `TableCardView` is a real view, and not one pipe reaches the
    // screen. Every *other* surface that shows a note as text was handed the canonical source instead,
    // so a Home row read `| Day | Date | Schedule |` and VoiceOver said it out loud. How a table is
    // stored is implementation, and a reader never decodes implementation (RULES.md §4).
    //
    // Two spellings, because the two audiences are different. The eye wants the glyphs it would have
    // seen on the page; the ear wants the words that glyph stands for, since a drawn box conveys
    // nothing at all to someone who cannot see it (docs/03-design-system.md — state is never carried
    // by a mark alone).

    /// The note as a reading surface shows it: visible markers, and a table as its cells.
    static func previewText(_ source: String) -> String {
        rendered(source, marker: \.visibleMarker, cellSeparator: " · ")
    }

    /// The note as VoiceOver should hear it: each list item named, and a table as its cells.
    static func spokenText(_ source: String) -> String {
        rendered(source, marker: \.spokenMarker, cellSeparator: ", ")
    }

    /// One walk over the note, with the two things that differ passed in.
    ///
    /// A table's rows come from `TableBlock`, which already drops the delimiter row and pads every row
    /// to the table's width — so the rule under the headings never reaches a reader, and an empty cell
    /// contributes nothing rather than a stray separator. Anything that is not a table is its line.
    private static func rendered(_ source: String,
                                 marker: (BlockKind) -> String,
                                 cellSeparator: String) -> String {
        let doc = MarkupDocument(source)
        let ns = source as NSString
        // Home renders a row per note and recomputes this each time, so the overwhelmingly common
        // case — a note with no table in it — is answered without scanning for one.
        let tables = source.contains("|") ? TableBlock.tables(in: source) : []
        var out: [String] = []
        var index = 0

        while index < doc.lines.count {
            if let table = tables.first(where: { $0.lineRange.contains(index) }) {
                for row in table.rows {
                    let cells = row.filter { !$0.isEmpty }
                    if !cells.isEmpty { out.append(cells.joined(separator: cellSeparator)) }
                }
                index = table.lineRange.upperBound + 1
                continue
            }
            let line = doc.lines[index]
            let content = ns.substring(with: NSRange(location: line.contentStart, length: line.contentLength))
            out.append(marker(line.kind) + content)
            index += 1
        }
        return out.joined(separator: "\n")
    }

    /// A row of notes as VoiceOver should hear it: the title, then the note in the ear's spelling.
    ///
    /// Home and Search both draw a note as *text* — a preview under a title, an excerpt in a result —
    /// and both were labelling themselves with `previewText`, the spelling written for the eye. A
    /// reader who cannot see the page was handed `☐ Call Ravi`: the box drawn as a character, which is
    /// state carried by a mark alone and nothing else (RULES.md §4, docs/03-design-system.md).
    ///
    /// One function rather than two properties, because two rows spelling the same note differently is
    /// exactly the bug this replaces. Leading blank lines go, as they do on screen, so a note that
    /// begins with a newline still announces its first real words.
    static func spokenRow(title: String?, body: String) -> String {
        let spoken = String(spokenText(body).drop(while: { $0 == "\n" || $0 == "\r" }))
        guard let title, !title.isEmpty else { return spoken }
        return spoken.isEmpty ? title : "\(title). \(spoken)"
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
