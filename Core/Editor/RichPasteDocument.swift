import Foundation

// Paste from another app, part three: the one shape every source is read into.
//
// HTML, rich text, and declared Markdown all say the same small number of things — this line was a
// heading, these lines were a list, these cells were a table — in three different vocabularies. Each
// reader used to translate straight into `body`, which meant three copies of the rules about blank
// lines, numbering, and what a table becomes. They now produce `ImportedBlock`s instead, and this file
// is the single place those become As Told source.
//
// The representation exists only for the length of a paste. `ImportedBlock.table` is emphatically not
// a promise that As Told grows a table block (RULES.md §7): it is a table held intact just long enough
// to be written down in a form a phone can read.

/// A table exactly as the source stated it, before any decision about how to write it down.
struct ImportedTable: Equatable {
    var rows: [[String]]
    /// Index into `rows` of the row the source marked as headers, when it marked one.
    var headerRow: Int?
}

/// One line of the result, before markers are attached.
struct ImportedLine: Equatable {
    var kind: BlockKind
    var text: String
    /// Whether this line opens a new block element. A `<br>`, a line of `<pre>`, and every row after a
    /// record's first continue one element, and only a genuinely new element may take a blank line in
    /// front of it.
    var startsElement: Bool
}

enum ImportedBlock: Equatable {
    case line(ImportedLine)
    case table(ImportedTable)
}

enum RichPasteDocument {

    /// Converts what a source stated into canonical As Told source, or `nil` when none of it is
    /// structure As Told holds — the caller then lets the system's own plain-text paste run, which is
    /// both the shortest path and the most faithful one.
    static func canonicalSource(_ blocks: [ImportedBlock]) -> String? {
        var lines: [ImportedLine] = []
        for block in blocks {
            switch block {
            case .line(let line): lines.append(line)
            case .table(let table): lines.append(contentsOf: written(table))
            }
        }

        while lines.first?.text.isEmpty == true { lines.removeFirst() }
        while lines.last?.text.isEmpty == true { lines.removeLast() }
        guard lines.contains(where: { $0.kind != .paragraph }) || carriedATable(blocks),
              !lines.isEmpty
        else { return nil }

        var out: [String] = []
        var previous: ImportedLine?
        for line in lines {
            // Two paragraphs that were separate elements read as separate paragraphs — which in a note
            // body means the blank line between them. Headings bring their own space, and list items
            // are meant to sit together, so neither takes one.
            if let previous, line.startsElement, line.kind == .paragraph,
               !line.text.isEmpty, !previous.text.isEmpty,
               previous.kind == .paragraph || previous.kind.isList {
                out.append("")
            }
            out.append(line.kind.marker + line.text)
            previous = line
        }
        return out.joined(separator: "\n")
    }

    private static func carriedATable(_ blocks: [ImportedBlock]) -> Bool {
        blocks.contains { if case .table = $0 { return true } else { return false } }
    }

    // MARK: Tables

    /// A table is preserved **as a table**: canonical Markdown pipe rows, in `body`, where they stay
    /// ordinary text that can be read, edited, searched, and copied like any other line.
    ///
    /// This replaced the row-record fallback on 2026-08-21. Records preserved every cell but destroyed
    /// the reason the author reached for a table — a table is a claim that these values belong to each
    /// other, and reading `Park: Kenai Fjords` twelve times does not restore it. What reads the rows
    /// back as a grid is `TableBlock`; what this owes it is a shape it can recognize without guessing,
    /// which is why the delimiter row is written even when the source marked no header.
    ///
    /// One limitation, and it is the line-based storage format's rather than this method's: a cell
    /// whose source held several lines arrives here as one line of words (the reader joined them with
    /// spaces). Every word survives; the line breaks inside that cell do not, because a row is a line
    /// and a line cannot contain one.
    private static func written(_ table: ImportedTable) -> [ImportedLine] {
        let width = table.rows.map(\.count).max() ?? 0
        guard width > 0 else { return [] }
        let padded = table.rows.map { row -> [String] in
            row + Array(repeating: "", count: width - row.count)
        }

        // One column is a list of values, not a grid, and pipes around it would be furniture.
        if width == 1 {
            return padded.enumerated().compactMap { index, row in
                row[0].isEmpty ? nil : ImportedLine(kind: .paragraph, text: row[0], startsElement: index == 0)
            }
        }

        var lines: [ImportedLine] = []
        for (index, row) in padded.enumerated() {
            lines.append(ImportedLine(kind: .paragraph,
                                      text: TableBlock.row(row),
                                      startsElement: index == 0))
            // The rule under the headings. A source that named no header row still gets one after the
            // first line: it is what makes the block a table rather than lines that contain pipes.
            if index == (table.headerRow ?? 0) {
                lines.append(ImportedLine(kind: .paragraph,
                                          text: TableBlock.delimiter(width: width),
                                          startsElement: false))
            }
        }
        return lines
    }
}

// MARK: - Checkbox glyphs

extension RichPasteDocument {

    /// The boxes a source draws when it has no checkbox of its own to give us — the glyphs As Told
    /// itself writes when a checklist is copied out (`StructuredTextExport`), and the ones other apps
    /// write for the same reason.
    ///
    /// Only ever consulted for a line the source already declared a *list item* — an HTML `<li>`, a
    /// rich-text `NSTextList` row. There, the glyph in front of the words is the item's marker, the same
    /// way `•` is, and reading it as the checkbox it draws keeps a meaning that would otherwise be lost
    /// to a format with no checkbox in it. The identical glyph in a paragraph, or anywhere in plain
    /// text, is a character the writer typed and stays one (RULES.md §4).
    static func checkbox(startingLine line: String) -> (checked: Bool, rest: String)? {
        var rest = Substring(line)
        while let first = rest.first, first == " " || first == "\t" || first == "\u{00A0}" {
            rest = rest.dropFirst()
        }
        // A glyph may sit behind the list marker the source also drew ("- ☐ Passport").
        for marker in ["- ", "* ", "• ", "– "] where rest.hasPrefix(marker) {
            rest = rest.dropFirst(marker.count)
            break
        }
        guard let glyph = rest.first, let checked = checkedState(glyph) else { return nil }

        var text = rest.dropFirst()
        guard text.isEmpty || text.first == " " || text.first == "\t" || text.first == "\u{00A0}"
        else { return nil }
        text = text.drop(while: { $0 == " " || $0 == "\t" || $0 == "\u{00A0}" })
        return (checked, String(text))
    }

    static func checkedState(_ glyph: Character) -> Bool? {
        switch glyph {
        case "☐", "□", "▢", "❏": return false
        case "☑", "☒", "✅": return true
        default: return nil
        }
    }
}

extension BlockKind {
    var isList: Bool {
        switch self {
        case .bullet, .numbered, .checklist: return true
        case .paragraph, .heading, .subheading: return false
        }
    }
}
