import Foundation

// Paste from another app, part four: Markdown that says it is Markdown.
//
// An assistant's answer is written in Markdown, and some apps put it on the pasteboard as Markdown —
// under a type that declares the format outright. That declaration is the whole justification for this
// file: `# Overview` is a heading here for exactly the reason `<h1>Overview</h1>` is one in HTML, which
// is that the source said so in a format it named.
//
// This is never run over `public.plain-text` (RULES.md §4). Text that merely looks like Markdown is
// text: a line beginning with a dash is a line beginning with a dash, and As Told does not get to
// decide otherwise on a clipboard that never claimed a format. `RichPasteImport` reaches this reader
// only through a declared Markdown flavor.
//
// Markup As Told has no structure for loses the markup and keeps every word: `**bold**` becomes bold's
// text, `[Major Marine](https://…)` becomes `Major Marine`. The URL goes with the styling — putting it
// into the note as words would be writing text the source never showed.

enum RichPasteMarkdown {

    static func source(from markdown: String) -> String? {
        RichPasteDocument.canonicalSource(document(from: markdown))
    }

    static func document(from markdown: String) -> [ImportedBlock] {
        var blocks: [ImportedBlock] = []
        var lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet(charactersIn: "\n\u{2028}\u{2029}"))[...]
        var counters: [Int] = []
        var previousWasListItem = false

        while let raw = lines.first {
            lines = lines.dropFirst()

            if let fence = fenceMarker(raw) {
                // Everything to the closing fence is the writer's own characters, indentation included
                // — and it arrives as a **code block**, so those characters stay literal. This is what
                // retires the V1 limitation recorded here: a fenced line beginning with `# ` used to
                // land in `body` as a heading, because `body` had no way to say "this is code". A
                // fence is that way (RULES.md §7).
                let info = raw.trimmingCharacters(in: .whitespaces)
                    .dropFirst(fence.count).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                while let next = lines.first, fenceMarker(next) != fence {
                    lines = lines.dropFirst()
                    code.append(next)
                }
                if lines.first != nil { lines = lines.dropFirst() }
                if !code.isEmpty {
                    blocks.append(.codeBlock(ImportedCode(
                        code: code.joined(separator: "\n"),
                        language: info.split(separator: " ").first.map(String.init)
                    )))
                }
                counters = []
                previousWasListItem = false
                continue
            }

            if let cells = tableRow(raw) {
                // Already inside a table: every pipe row under the delimiter is one of its rows.
                if case .table(var table)? = blocks.last {
                    table.rows.append(cells)
                    blocks[blocks.count - 1] = .table(table)
                    previousWasListItem = false
                    continue
                }
                // A table *opens* where Markdown says one opens: a header row with the delimiter row
                // directly under it. Without that rule any line holding a pipe became a grid — and
                // then `RichPasteDocument` wrote the delimiter row into the note, so `Option A |
                // Option B` came back as a two-cell table with a rule the writer never typed. Paste
                // translates the structure a source states and deduces none (RULES.md §4), and one
                // pipe states nothing. A line that opens no table is not consumed here: it falls
                // through and is read as the prose, heading, or list item it is.
                if let next = lines.first, isTableDelimiter(next) {
                    lines = lines.dropFirst()
                    blocks.append(.table(ImportedTable(rows: [cells], headerRow: 0)))
                    previousWasListItem = false
                    continue
                }
            }

            let line = Substring(raw)
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
            if trimmed.isEmpty {
                counters = []
                previousWasListItem = false
                blocks.append(.line(ImportedLine(kind: .paragraph, text: "", startsElement: false)))
                continue
            }
            // A thematic break carries no words, so it leaves none behind — as `<hr>` does. The blank
            // line under it went with the rule, not the prose, and would otherwise double the gap.
            if isThematicBreak(trimmed) {
                if lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                    lines = lines.dropFirst()
                }
                continue
            }

            if let (level, text) = heading(trimmed) {
                counters = []
                previousWasListItem = false
                blocks.append(.line(ImportedLine(kind: level == 1 ? .heading : .subheading,
                                                 text: inlineText(text),
                                                 startsElement: true)))
                continue
            }

            if let item = listItem(trimmed) {
                // Nesting is flattened: As Told has one level of list, and every word survives at it.
                if !previousWasListItem { counters = [] }
                var kind = item.kind
                if case .numbered = kind {
                    if counters.isEmpty { counters = [item.number ?? 1] } else { counters[0] += 1 }
                    kind = .numbered(counters[0])
                } else {
                    counters = []
                }
                previousWasListItem = true
                blocks.append(.line(ImportedLine(kind: kind,
                                                 text: inlineText(item.text),
                                                 startsElement: true)))
                continue
            }

            counters = []
            previousWasListItem = false
            blocks.append(.line(ImportedLine(kind: .paragraph,
                                             text: inlineText(quoteStripped(trimmed)),
                                             startsElement: true)))
        }
        return blocks
    }

    // MARK: Lines

    private static func fenceMarker(_ line: String) -> String? {
        let trimmed = line.drop(while: { $0 == " " })
        guard trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") else { return nil }
        return String(trimmed.prefix(3))
    }

    private static func isThematicBreak(_ line: Substring) -> Bool {
        let stripped = line.filter { $0 != " " }
        guard stripped.count >= 3 else { return false }
        return stripped.allSatisfy { $0 == "-" } || stripped.allSatisfy { $0 == "*" }
            || stripped.allSatisfy { $0 == "_" }
    }

    private static func heading(_ line: Substring) -> (level: Int, text: Substring)? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " || rest.isEmpty else { return nil }
        // Trailing hashes close an ATX heading; they are punctuation of the format, not words.
        var text = rest.drop(while: { $0 == " " })
        while text.last == "#" { text = text.dropLast() }
        while text.last == " " { text = text.dropLast() }
        return (hashes.count, text)
    }

    private static func quoteStripped(_ line: Substring) -> Substring {
        guard line.hasPrefix(">") else { return line }
        return line.dropFirst().drop(while: { $0 == " " })
    }

    private struct MarkdownItem {
        var kind: BlockKind
        var number: Int?
        var text: Substring
    }

    private static func listItem(_ line: Substring) -> MarkdownItem? {
        var rest = line
        var number: Int?

        if let bullet = rest.first, bullet == "-" || bullet == "*" || bullet == "+" {
            rest = rest.dropFirst()
        } else {
            let digits = rest.prefix(while: { $0.isASCII && $0.isNumber })
            guard !digits.isEmpty, digits.count <= 9,
                  let terminator = rest.dropFirst(digits.count).first,
                  terminator == "." || terminator == ")"
            else { return nil }
            number = Int(digits)
            rest = rest.dropFirst(digits.count + 1)
        }
        guard rest.first == " " || rest.first == "\t" else { return nil }
        rest = rest.drop(while: { $0 == " " || $0 == "\t" })

        // `- [ ] Passport`: the task-list spelling, and the one As Told already stores.
        if rest.hasPrefix("["), rest.count >= 3 {
            let mark = rest[rest.index(after: rest.startIndex)]
            let closing = rest.index(rest.startIndex, offsetBy: 2)
            if rest[closing] == "]", mark == " " || mark == "x" || mark == "X" {
                let text = rest.dropFirst(3).drop(while: { $0 == " " })
                return MarkdownItem(kind: .checklist(checked: mark != " "), number: number, text: text)
            }
        }
        if let box = RichPasteDocument.checkbox(startingLine: String(rest)) {
            return MarkdownItem(kind: .checklist(checked: box.checked), number: number, text: box.rest[...])
        }
        return MarkdownItem(kind: number == nil ? .bullet : .numbered(number ?? 1),
                            number: number,
                            text: rest)
    }

    // MARK: Tables

    private static func tableRow(_ line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|"), trimmed.hasPrefix("|") || trimmed.contains(" | ") else { return nil }
        var body = trimmed[...]
        if body.hasPrefix("|") { body = body.dropFirst() }
        if body.hasSuffix("|") { body = body.dropLast() }
        let cells = body.components(separatedBy: "|").map {
            inlineText($0.trimmingCharacters(in: .whitespaces)[...])
        }
        return cells.isEmpty ? nil : cells
    }

    /// `| --- | :-: |` — the rule under a table's headings. It says which row was the header, and holds
    /// no words of its own.
    private static func isTableDelimiter(_ line: String) -> Bool {
        guard let cells = tableRow(line), !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " } && cell.contains("-")
        }
    }

    // MARK: Inline

    /// Drops the markup around words and keeps the words: `**bold**`, `*italic*`, `` `code` ``,
    /// `[text](url)`. A delimiter with no partner on the line is a character the writer typed — an
    /// asterisk in `2 * 3`, an underscore in a file name — and is left exactly where it is.
    static func inlineText(_ text: Substring) -> String {
        var out = ""
        var index = text.startIndex
        outer: while index < text.endIndex {
            let character = text[index]

            if character == "\\", text.index(after: index) < text.endIndex {
                let next = text[text.index(after: index)]
                if "\\`*_{}[]()#+-.!|>~".contains(next) {
                    out.append(next)
                    index = text.index(index, offsetBy: 2)
                    continue
                }
            }

            // `[Major Marine](https://…)` keeps **both halves** now that As Told holds links: the
            // words the source showed, and the destination it stated. `![alt](…)` still keeps only its
            // words — As Told has no images, and an image's address is not something a reader can use.
            if character == "!" || character == "[" {
                let isImage = character == "!"
                let opening = isImage ? text.index(after: index) : index
                if opening < text.endIndex, text[opening] == "[",
                   let label = matching("]", from: text.index(after: opening), in: text) {
                    let after = text.index(after: label)
                    if after < text.endIndex, text[after] == "(",
                       let close = matching(")", from: text.index(after: after), in: text) {
                        let words = inlineText(text[text.index(after: opening)..<label])
                        let destination = markdownDestination(text[text.index(after: after)..<close])
                        // `LinkSpan.source` hands back the words untouched when the destination is not
                        // an absolute http(s) URL, so a relative or `mailto:` link keeps its text and
                        // loses nothing else.
                        out += isImage ? words : LinkSpan.source(label: words, destination: destination)
                        index = text.index(after: close)
                        continue outer
                    }
                }
            }

            for delimiter in ["**", "__", "*", "_", "`"] where text[index...].hasPrefix(delimiter) {
                let contentStart = text.index(index, offsetBy: delimiter.count)
                guard contentStart < text.endIndex,
                      let close = range(of: delimiter, from: contentStart, in: text)
                else { continue }
                out += delimiter == "`"
                    ? String(text[contentStart..<close])   // code spans are literal, markup included
                    : inlineText(text[contentStart..<close])
                index = text.index(close, offsetBy: delimiter.count)
                continue outer
            }

            out.append(character)
            index = text.index(after: index)
        }
        return out
    }

    static func inlineText(_ text: String) -> String { inlineText(text[...]) }

    /// The address out of a Markdown destination: `<https://x>` loses its brackets, and
    /// `https://x "Title"` loses the title, which is a tooltip As Told has nowhere to show.
    private static func markdownDestination(_ raw: Substring) -> String {
        var text = raw.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("<"), text.hasSuffix(">"), text.count >= 2 {
            text = String(text.dropFirst().dropLast())
        }
        return text.split(separator: " ").first.map(String.init) ?? text
    }

    private static func matching(_ character: Character, from start: Substring.Index,
                                 in text: Substring) -> Substring.Index? {
        var index = start
        while index < text.endIndex {
            if text[index] == "\\" { index = text.index(index, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex; continue }
            if text[index] == character { return index }
            index = text.index(after: index)
        }
        return nil
    }

    private static func range(of delimiter: String, from start: Substring.Index,
                              in text: Substring) -> Substring.Index? {
        var index = start
        while index < text.endIndex {
            if text[index...].hasPrefix(delimiter) { return index }
            index = text.index(after: index)
        }
        return nil
    }
}
