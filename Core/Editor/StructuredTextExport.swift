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

    /// The plain text other apps receive for a selection: hidden markers replaced by visible ones,
    /// link syntax gone, and a code block's fences dropped.
    ///
    /// A labelled link keeps **both halves**. "The page as it reads" would send `Open reservation` and
    /// silently destroy the destination the note was carrying — and a person copying their own words
    /// out of their own app must not lose what they put there (RULES.md §3). Apps that understand rich
    /// text get a real hyperlink instead, from `html(from:range:)`; this is the fallback for the ones
    /// that do not.
    static func plainText(from source: String, range: NSRange) -> String {
        let ns = source as NSString
        let range = copyRange(in: source, selection: range)
        guard range.length > 0 else { return "" }
        let end = range.location + range.length
        let doc = MarkupDocument(source)
        let fences = source.contains(CodeBlock.fence) ? CodeBlock.blocks(in: source) : []

        var out: [String] = []
        for (index, line) in doc.lines.enumerated() {
            let lineEnd = line.sourceRange.location + line.sourceRange.length
            guard lineEnd >= range.location, line.sourceRange.location <= end else { continue }

            // A fence is how the note stores code, not part of the code. Someone pasting this into a
            // terminal wants what they saw, and what they saw was the code.
            if let block = fences.first(where: { $0.lineRange.contains(index) }) {
                if index == block.lineRange.lowerBound || index == block.lineRange.upperBound { continue }
                let from = max(range.location, line.sourceRange.location)
                let to = min(end, lineEnd)
                out.append(to > from ? ns.substring(with: NSRange(location: from, length: to - from)) : "")
                continue
            }

            let from = max(range.location, line.contentStart)
            let to = min(end, lineEnd)
            let content = to > from
                ? visible(NSRange(location: from, length: to - from), on: line, in: ns,
                          render: { link, label in
                              link.isLabelled ? "\(label) — \(link.destination)" : label
                          })
                : ""
            // A line only shows its marker when the selection reached its start; a fragment is words.
            let marker = range.location <= line.contentStart ? line.kind.visibleMarker : ""
            out.append(marker + content)
        }
        return out.joined(separator: "\n")
    }

    /// The visible characters of `range` on one line, with each link the range covers *whole* handed to
    /// `render`. A link the selection only clipped contributes its visible words and no syntax — a
    /// fragment of a link is not a link, and a stray `](https://…` must never reach another app.
    /// - Parameter plain: applied to every character that is *not* part of a link. The HTML flavor
    ///   needs it, and needs it here rather than at the call site: the words around a link are emitted
    ///   into the same document as the link, so `if a < b && c > d` in ordinary prose would otherwise
    ///   reach a receiving app as malformed markup.
    private static func visible(_ range: NSRange, on line: MarkupDocument.Line, in source: NSString,
                                render: (LinkSpan, String) -> String,
                                plain: (String) -> String = { $0 }) -> String {
        guard !line.links.isEmpty else { return plain(source.substring(with: range)) }
        let end = NSMaxRange(range)
        var out = ""
        var index = range.location
        var pending = ""

        // Plain characters are gathered into runs before `plain` sees them, so an escaper is handed
        // whole words rather than one character at a time.
        func flush() {
            guard !pending.isEmpty else { return }
            out += plain(pending)
            pending = ""
        }

        while index < end {
            if let link = line.links.first(where: { $0.sourceRange.location == index }),
               NSMaxRange(link.sourceRange) <= end {
                flush()
                out += render(link, link.displayText(in: source as String))
                index = NSMaxRange(link.sourceRange)
                continue
            }
            if let run = line.hiddenRuns.first(where: { index >= $0.location && index < NSMaxRange($0) }) {
                index = NSMaxRange(run)
                continue
            }
            pending += source.substring(with: NSRange(location: index, length: 1))
            index += 1
        }
        flush()
        return out
    }

    /// The rich-text flavor for a selection — a real `<a href>` other apps can follow — or `nil` when
    /// the selection carries no link and the plain text already says everything.
    ///
    /// Deliberately nil in the ordinary case: a note without links copies exactly as it always has,
    /// with no new flavor on the pasteboard to change how a receiving app decides what to insert.
    /// - Parameters:
    ///   - requiringLink: whether a link is a **precondition** for producing HTML at all. True for the
    ///     pasteboard, where a second flavor is only worth carrying when plain text would lose
    ///     something — a link is the one thing it cannot express. False for the **share sheet**, where
    ///     the destination negotiates and the richer representation is simply offered alongside the
    ///     plain one (added 2026-08-26). The HTML produced is identical either way; only the gate moves.
    ///   - title: the note's title, emitted as an `<h1>` ahead of the body. Passed rather than prepended
    ///     to `source`, because a title is not a line of the note: prepending it would run it through
    ///     `MarkupDocument`, and a title beginning "- " would arrive as a bullet.
    static func html(from source: String, range: NSRange,
                     requiringLink: Bool = true, title: String? = nil) -> String? {
        let ns = source as NSString
        let range = copyRange(in: source, selection: range)
        guard range.length > 0 else { return nil }
        let end = range.location + range.length
        let doc = MarkupDocument(source)
        if requiringLink {
            guard doc.lines.contains(where: { line in
                line.links.contains { $0.sourceRange.location >= range.location
                    && NSMaxRange($0.sourceRange) <= end }
            }) else { return nil }
        }

        let fences = source.contains(CodeBlock.fence) ? CodeBlock.blocks(in: source) : []
        var rows: [(isCode: Bool, html: String)] = []
        for (index, line) in doc.lines.enumerated() {
            let lineEnd = line.sourceRange.location + line.sourceRange.length
            guard lineEnd >= range.location, line.sourceRange.location <= end else { continue }

            if let block = fences.first(where: { $0.lineRange.contains(index) }) {
                if index == block.lineRange.lowerBound || index == block.lineRange.upperBound { continue }
                let from = max(range.location, line.sourceRange.location)
                let to = min(end, lineEnd)
                rows.append((true, escapingHTML(to > from
                    ? ns.substring(with: NSRange(location: from, length: to - from)) : "")))
                continue
            }

            let from = max(range.location, line.contentStart)
            let to = min(end, lineEnd)
            let content = to > from
                ? visible(NSRange(location: from, length: to - from), on: line, in: ns,
                          render: { link, label in
                              "<a href=\"\(escapingHTML(link.destination))\">\(escapingHTML(label))</a>"
                          },
                          plain: escapingHTML)
                : ""
            let marker = range.location <= line.contentStart ? escapingHTML(line.kind.visibleMarker) : ""
            rows.append((false, marker + content))
        }

        // Code goes inside `<pre>`, because HTML collapses runs of spaces and `<br>`-separated lines
        // would arrive in Mail or Docs with their indentation gone — and indentation is most of what
        // makes code readable. Prose lines stay `<br>`-separated, which is what a note is.
        var out = ""
        var index = 0
        while index < rows.count {
            if rows[index].isCode {
                var block: [String] = []
                while index < rows.count, rows[index].isCode {
                    block.append(rows[index].html)
                    index += 1
                }
                out += "<pre>" + block.joined(separator: "\n") + "</pre>"
                continue
            }
            var prose: [String] = []
            while index < rows.count, !rows[index].isCode {
                prose.append(rows[index].html)
                index += 1
            }
            if !out.isEmpty, !out.hasSuffix("</pre>") { out += "<br>" }
            out += prose.joined(separator: "<br>")
        }
        // A charset, declared outright, and the reason is a real bug rather than tidiness. The
        // pasteboard carries this flavor as UTF-8 bytes; an app that receives HTML with no declared
        // encoding falls back to a legacy single-byte one, and every character above ASCII arrives
        // mangled — an em dash as "â€”", a curly apostrophe as "â€™", Telugu and Hindi as noise. The
        // note's words are the one thing that must survive a copy (RULES.md §2, §5), so the encoding
        // is stated rather than left to whatever the other side happens to assume.
        //
        // A complete document rather than a bare `<meta>`: a fragment parser is free to drop a stray
        // meta tag, and `<head>` is the one place every parser honours it. `RichPasteHTML` reads this
        // back unchanged — it skips `<head>` wholesale and treats `html`/`body` as block boundaries.
        let heading = title.map { "<h1>" + escapingHTML($0) + "</h1>" } ?? ""
        return "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body>"
            + heading + "<div>" + out + "</div>"
            + "</body></html>"
    }

    /// The whole note as an HTML document — title included, and produced whatever the note contains.
    ///
    /// The share sheet's richer half. Same generator as the pasteboard's, so a table, a code block, a
    /// link, and a declared charset all behave exactly as they do on a copy; there is deliberately no
    /// second HTML path to keep in step with this one.
    static func html(_ source: String, title: String? = nil) -> String? {
        html(from: source, range: NSRange(location: 0, length: (source as NSString).length),
             requiringLink: false, title: title)
    }

    /// Escapes text for HTML. `visible(_:on:in:render:)` hands the link renderer raw words, so the
    /// escaping happens here rather than being assumed of the caller.
    private static func escapingHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
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

    /// The note as a reading surface shows it: visible markers, a table as its cells, and a link as
    /// the words it shows. A Home row is the page as it reads, and the page reads `Open reservation`.
    static func previewText(_ source: String) -> String {
        rendered(source, marker: \.visibleMarker, cellSeparator: " · ") { _, label in label }
    }

    /// The note as VoiceOver should hear it: each list item named, a table as its cells, and a link
    /// **announced as a link**.
    ///
    /// The same rule that makes a checkbox say "Checked" rather than draw a glyph (RULES.md §4). A
    /// link that differs from the words around it only by colour conveys nothing at all to someone who
    /// cannot see the page, so the ear is told what the eye is shown.
    static func spokenText(_ source: String) -> String {
        rendered(source, marker: \.spokenMarker, cellSeparator: ", ") { _, label in "Link, \(label)" }
    }

    /// One walk over the note, with the two things that differ passed in.
    ///
    /// A table's rows come from `TableBlock`, which already drops the delimiter row and pads every row
    /// to the table's width — so the rule under the headings never reaches a reader, and an empty cell
    /// contributes nothing rather than a stray separator. Anything that is not a table is its line.
    private static func rendered(_ source: String,
                                 marker: (BlockKind) -> String,
                                 cellSeparator: String,
                                 link render: (LinkSpan, String) -> String) -> String {
        let doc = MarkupDocument(source)
        let ns = source as NSString
        // Home renders a row per note and recomputes this each time, so the overwhelmingly common
        // case — a note with no table and no code in it — is answered without scanning for either.
        let tables = source.contains("|") ? TableBlock.tables(in: source) : []
        let fences = source.contains(CodeBlock.fence) ? CodeBlock.blocks(in: source) : []
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
            // A fence is storage. Every other surface shows the code and not the backticks around it,
            // for the same reason none of them shows a table's pipes.
            if let block = fences.first(where: { $0.lineRange.contains(index) }) {
                out.append(contentsOf: block.codeLines)
                index = block.lineRange.upperBound + 1
                continue
            }
            let line = doc.lines[index]
            let content = visible(NSRange(location: line.contentStart, length: line.contentLength),
                                  on: line, in: ns, render: render)
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
        // Structure now includes a link's syntax and a code block's fences: an As Told → As Told paste
        // that dropped them would arrive as words that used to be a link and code that used to be code.
        let inner = MarkupDocument(substring)
        guard inner.lines.contains(where: { $0.markerLength > 0 || $0.isLiteral
                                            || $0.links.contains(where: \.isLabelled) })
        else { return nil }
        return substring
    }

    private static func clamp(_ range: NSRange, to length: Int) -> NSRange {
        let location = max(0, min(range.location, length))
        return NSRange(location: location, length: max(0, min(range.length, length - location)))
    }
}
