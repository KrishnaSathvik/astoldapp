import Foundation

// Paste from another app, part one: HTML.
//
// Most apps a note gets pasted from — a browser, Notes, Google Docs, a chat client, an AI assistant —
// put an HTML flavor on the pasteboard alongside the plain text. That flavor says, in the source's own
// words, which lines were headings and which were list items. Reading it lets As Told keep structure it
// already supports instead of flattening the paste to a wall of text.
//
// The contract is narrow on purpose (RULES.md §2 — "preserve the words"):
//
//  - Every character of a line's text is preserved exactly. Nothing is corrected, reordered, or reworded.
//  - Structure is only ever *translated*, never guessed from prose: an <h2> becomes a subheading because
//    the source said it was a heading. A short line is just a short line.
//  - Inline styling As Told does not have (bold, italic, links) loses the styling and keeps the text.
//  - One narrow exception, and only inside a list the source itself declared: a checkbox glyph is a
//    checkbox (see `promoted(kind:text:)`).
//  - Tables are not a structure As Told can edit, so they leave here intact and `RichPasteDocument`
//    decides how to write them down.
//
// This is a deliberately small tag-level parser rather than `NSAttributedString(documentType: .html)`:
// that importer needs WebKit and the main thread, and it resolves headings down to font sizes, which
// would leave us inferring structure from type size — exactly what must not happen.

enum RichPasteHTML {
    /// Converts an HTML flavor of the pasteboard into canonical As Told source, or `nil` when it holds
    /// no structure As Told supports (in which case the plain text already says everything).
    static func source(from html: String) -> String? {
        RichPasteDocument.canonicalSource(document(from: html))
    }

    /// The same reading, stopped one step short of `body` — what the source stated, before any decision
    /// about how it is written down.
    static func document(from html: String) -> [ImportedBlock] {
        var parser = Parser()
        parser.run(html)
        return parser.finish()
    }
}

// MARK: - Parser

extension RichPasteHTML {

    fileprivate struct ListContext {
        var ordered: Bool
        var checklist: Bool
        var counter: Int
    }

    fileprivate struct Parser {
        private var blocks: [ImportedBlock] = []
        private var buffer = ""
        private var pendingKind: BlockKind = .paragraph
        /// What the open `<li>` is, kept separately because a `<p>` or `<div>` *inside* that item ends a
        /// line without ending the item. Without this, `<li><p>Eggs</p></li>` — which is what Docs,
        /// Notion, and GitHub all write — lost its bullet to the block tag nested in it.
        private var itemKind: BlockKind?
        private var startsElement = true
        private var lists: [ListContext] = []
        private var preDepth = 0
        private var skipping: String?
        /// The open `<a href>`, and how much of `buffer` was already there when it opened — the label
        /// is whatever text arrives between the two.
        private var link: (href: String, mark: Int)?
        /// Whether the last thing to end a line of code was an element boundary rather than text.
        /// A `<br>` immediately after one is the same break stated twice — `<div><br><br></div>` between
        /// two lines is one blank line, not two — so the first one is absorbed and the rest count.
        private var preBoundaryEndedLine = false
        /// The language a `<code class="language-…">` named inside the open `<pre>`.
        private var codeLanguage: String?
        /// Whether a `<code>` was seen inside the open `<pre>` at all.
        ///
        /// This is the whole difference between a diagram and a program, and HTML states it outright:
        /// `<pre>` says "these characters are preformatted", `<code>` says "these characters are code".
        /// A `<pre>` with no `<code>` in it declared the first and not the second, so it lands as a
        /// plain-text block rather than an unlabelled code one (added 2026-08-25). Nothing reads the
        /// characters to decide — as everywhere else here, a claim is translated, never made.
        private var preHeldCode = false

        // A table is collected whole and emitted at </table>.
        private var tableDepth = 0
        private var cells: [String] = []
        private var rows: [[String]] = []
        private var rowIsHeader = false
        private var headerRow: Int?
        private var inCell = false

        /// Elements whose content is not the document's text.
        private static let skipTags: Set<String> = [
            "script", "style", "head", "title", "noscript", "svg", "template", "iframe", "object"
        ]

        /// Elements that end a line **inside a `<pre>`** — the block tags, plus the few tags that end
        /// a line without being block tags out here. A highlighter may reach for any of them to mark up
        /// one line of code, and all that matters inside a `<pre>` is where the lines are.
        private static var endsLineInsidePre: Set<String> {
            blockTags.union(["h1", "h2", "h3", "h4", "h5", "h6", "li", "tr", "ul", "ol", "table"])
        }

        /// Elements that end the line they are on. Anything not listed is inline: its text joins the
        /// line being built, with the styling dropped.
        private static let blockTags: Set<String> = [
            "p", "div", "body", "html", "section", "article", "header", "footer", "main", "aside",
            "nav", "figure", "figcaption", "blockquote", "address", "form", "fieldset", "details",
            "summary", "center", "dl", "dt", "dd", "colgroup", "thead", "tbody", "tfoot"
        ]

        // MARK: Scanning

        mutating func run(_ html: String) {
            let chars = Array(html)
            var index = 0
            var textStart = 0
            while index < chars.count {
                guard chars[index] == "<" else { index += 1; continue }
                if index > textStart { appendText(String(chars[textStart..<index])) }
                index = consumeMarkup(chars, from: index)
                textStart = index
            }
            if textStart < chars.count { appendText(String(chars[textStart...])) }
        }

        /// Consumes one tag, comment, or declaration starting at `start`, and returns the index just
        /// past it. A `<` that begins none of those is text.
        private mutating func consumeMarkup(_ chars: [Character], from start: Int) -> Int {
            if chars[start...].starts(with: "<!--") {
                var index = start + 4
                while index + 2 < chars.count {
                    if chars[index] == "-", chars[index + 1] == "-", chars[index + 2] == ">" {
                        return index + 3
                    }
                    index += 1
                }
                return chars.count
            }
            if start + 1 < chars.count, chars[start + 1] == "!" || chars[start + 1] == "?" {
                var index = start + 1
                while index < chars.count, chars[index] != ">" { index += 1 }
                return min(index + 1, chars.count)
            }

            var index = start + 1
            var isEnd = false
            if index < chars.count, chars[index] == "/" { isEnd = true; index += 1 }
            guard index < chars.count, chars[index].isLetter else {
                appendText("<")
                return start + 1
            }

            var name = ""
            while index < chars.count,
                  chars[index].isLetter || chars[index].isNumber || chars[index] == "-" || chars[index] == ":" {
                name.append(chars[index])
                index += 1
            }

            var attributes: [String: String] = [:]
            while index < chars.count, chars[index] != ">" {
                if chars[index].isWhitespace || chars[index] == "/" { index += 1; continue }
                var attribute = ""
                while index < chars.count, !chars[index].isWhitespace,
                      chars[index] != "=", chars[index] != ">", chars[index] != "/" {
                    attribute.append(chars[index])
                    index += 1
                }
                while index < chars.count, chars[index].isWhitespace { index += 1 }
                var value = ""
                if index < chars.count, chars[index] == "=" {
                    index += 1
                    while index < chars.count, chars[index].isWhitespace { index += 1 }
                    if index < chars.count, chars[index] == "\"" || chars[index] == "'" {
                        let quote = chars[index]
                        index += 1
                        while index < chars.count, chars[index] != quote { value.append(chars[index]); index += 1 }
                        if index < chars.count { index += 1 }
                    } else {
                        while index < chars.count, !chars[index].isWhitespace, chars[index] != ">" {
                            value.append(chars[index])
                            index += 1
                        }
                    }
                }
                if !attribute.isEmpty { attributes[attribute.lowercased()] = Entities.decode(value) }
            }

            handle(name: name.lowercased(), isEnd: isEnd, attributes: attributes)
            return min(index + 1, chars.count)
        }

        // MARK: Tags

        private mutating func handle(name: String, isEnd: Bool, attributes: [String: String]) {
            if let open = skipping {
                if isEnd, name == open { skipping = nil }
                return
            }
            if !isEnd, Self.skipTags.contains(name) {
                flushBlock()
                skipping = name
                return
            }

            // Inside a `<pre>`, the only structure is lines.
            //
            // Every syntax highlighter on the web wraps each line of code in its own element and each
            // token in a `<span>`, so the copy that arrives from a docs site, a code host, or an answer
            // in a chat is `<pre><code><div>…</div><div>…</div></code></pre>` — not the literal
            // newlines a hand-written page has. Letting those tags run through the switch below sent a
            // `<div>` to `flushBlock`, which emptied the code buffer into ordinary paragraphs on its way
            // past; by the time `</pre>` closed there was nothing left and no code block was ever
            // emitted. The `<pre>` had *stated* that these characters are literal, and the paste threw
            // that statement away (RULES.md §7).
            //
            // So while a `<pre>` is open, a tag that would end a line ends a **line of the code**, and
            // everything else is markup around the words — dropped, exactly as styling always is. Only
            // `pre` and `code` still mean what they mean, because they open and close the block itself.
            if preDepth > 0, name != "pre", name != "code" {
                if name == "br" {
                    // An explicit break is a break — two of them are the blank line the author left —
                    // unless an element boundary has just ended this line already.
                    if !isEnd {
                        if preBoundaryEndedLine { preBoundaryEndedLine = false } else { lineBreak() }
                    }
                } else if Self.endsLineInsidePre.contains(name) {
                    // An element boundary is one boundary between two lines, and a line that has
                    // already ended does not end twice: `<div>a</div><div>b</div>` is two lines of
                    // code, not two lines with a gap between them.
                    if !buffer.isEmpty, !buffer.hasSuffix("\n") { buffer += "\n" }
                    preBoundaryEndedLine = !buffer.isEmpty
                }
                return
            }

            switch name {
            case "br":
                if !isEnd { lineBreak() }

            case "hr":
                // A rule carries no words. There is nothing to preserve, and writing a separator
                // character of our own would be putting text in the note the user never typed.
                if !isEnd { flushBlock() }

            case "ul", "ol", "menu":
                flushBlock()
                if isEnd {
                    if !lists.isEmpty { lists.removeLast() }
                } else {
                    let classes = classTokens(attributes)
                    lists.append(ListContext(
                        ordered: name == "ol",
                        checklist: classes.contains { $0.contains("task-list") || $0.contains("checklist") },
                        counter: attributes["start"].flatMap { Int($0) } ?? 1
                    ))
                }
                itemKind = nil
                pendingKind = .paragraph

            case "li":
                flushBlock()
                itemKind = nil
                if isEnd {
                    pendingKind = .paragraph
                } else {
                    beginListItem(attributes)
                }

            case "input":
                guard !isEnd, attributes["type"]?.lowercased() == "checkbox" else { return }
                checkbox(checked: attributes["checked"] != nil)

            case "table":
                if isEnd {
                    endTable()
                } else {
                    flushBlock()
                    tableDepth += 1
                }

            case "tr":
                guard tableDepth > 0 else { return }
                if isEnd { endRow() } else { endRow(); cells = []; rowIsHeader = false }

            case "caption":
                // A caption's words are the table's words. It becomes the row above it rather than
                // being dropped for having no cell of its own.
                guard tableDepth > 0 else { flushBlock(); return }
                if isEnd {
                    endRow()
                } else {
                    endCell()
                    inCell = true
                    buffer = ""
                }

            case "td", "th":
                guard tableDepth > 0 else { return }
                if isEnd {
                    endCell()
                } else {
                    endCell()
                    inCell = true
                    buffer = ""
                    if name == "th" { rowIsHeader = true }
                }

            case "a":
                // A link inside code is code, and a link inside a table cell would put its syntax in a
                // rendered cell — both keep the words and drop the destination, which is what the
                // paste rule has always done with styling As Told does not hold.
                guard preDepth == 0, !inCell else { return }
                if isEnd {
                    closeLink()
                } else if let href = attributes["href"], LinkSpan.isAbsoluteWebURL(href) {
                    link = (href, (buffer as NSString).length)
                }

            case "code":
                // Only meaningful inside a `<pre>`: that is where a language name is stated. Inline
                // `<code>` is a styling As Told does not have, and keeps its characters as words.
                guard !isEnd, preDepth > 0 else { return }
                preHeldCode = true
                codeLanguage = codeLanguage ?? language(from: attributes)

            case "pre":
                if isEnd {
                    preDepth = max(0, preDepth - 1)
                    if preDepth == 0 { flushCode() }
                } else {
                    flushBlock()
                    preDepth += 1
                    buffer = ""
                    codeLanguage = nil
                    preHeldCode = false
                }

            case "h1":
                flushBlock()
                if !isEnd { pendingKind = .heading }

            case "h2", "h3", "h4", "h5", "h6":
                // As Told has two heading levels. Everything below the first maps to Subheading: the
                // line was a heading in the source and stays one here, at the depth this app has.
                flushBlock()
                if !isEnd { pendingKind = .subheading }

            default:
                if Self.blockTags.contains(name) { flushBlock() }
            }
        }

        private func classTokens(_ attributes: [String: String]) -> [String] {
            (attributes["class"]?.lowercased() ?? "").split(whereSeparator: \.isWhitespace).map(String.init)
        }

        private mutating func beginListItem(_ attributes: [String: String]) {
            let classes = classTokens(attributes)
            if let value = attributes["value"].flatMap({ Int($0) }), let last = lists.indices.last,
               lists[last].ordered {
                lists[last].counter = value
            }

            if lists.last?.checklist == true || classes.contains("task-list-item") {
                itemKind = .checklist(checked: classes.contains("checked")
                                      || attributes["data-checked"] == "true")
            } else if lists.last?.ordered == true {
                // Resolved to its ordinal when the line is emitted, so an empty item costs no number
                // and the list never shows a gap.
                itemKind = .numbered(0)
            } else {
                itemKind = .bullet
            }
            pendingKind = itemKind ?? .paragraph
        }

        /// A checkbox control inside a list item is what makes that item a checklist item; a checkbox
        /// anywhere else is a form control, and changes nothing.
        private mutating func checkbox(checked: Bool) {
            switch pendingKind {
            case .bullet, .numbered, .checklist:
                pendingKind = .checklist(checked: checked)
                if itemKind != nil { itemKind = pendingKind }
            case .paragraph, .heading, .subheading:
                break
            }
        }

        // MARK: Tables

        private mutating func endCell() {
            guard inCell else { return }
            cells.append(buffer.trimmingCharacters(in: .whitespacesAndNewlines))
            buffer = ""
            inCell = false
        }

        private mutating func endRow() {
            endCell()
            guard !cells.isEmpty else { return }
            if rowIsHeader, headerRow == nil { headerRow = rows.count }
            rows.append(cells)
            cells = []
            rowIsHeader = false
        }

        /// A table leaves the parser as the table it was. What it becomes on the page is one decision,
        /// made once, in `RichPasteDocument` — where the width of a phone can be taken into account.
        private mutating func endTable() {
            endRow()
            tableDepth = max(0, tableDepth - 1)
            guard tableDepth == 0, !rows.isEmpty else { return }
            blocks.append(.table(ImportedTable(rows: rows, headerRow: headerRow)))
            rows = []
            headerRow = nil
        }

        // MARK: Links and code

        /// Closes the open `<a>`, turning the words it wrapped into a link.
        ///
        /// An anchor with no words of its own contributes nothing: there is no text to preserve, and
        /// writing the bare href would put a URL in the note that the source never showed.
        private mutating func closeLink() {
            guard let link else { return }
            self.link = nil
            let ns = buffer as NSString
            guard link.mark <= ns.length else { return }
            let label = ns.substring(from: link.mark)
            guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            buffer = ns.substring(to: link.mark) + LinkSpan.source(label: label, destination: link.href)
        }

        /// `class="language-python"` / `class="lang-python"` → `"python"`.
        private func language(from attributes: [String: String]) -> String? {
            for token in classTokens(attributes) {
                for prefix in ["language-", "lang-"] where token.hasPrefix(prefix) {
                    let name = String(token.dropFirst(prefix.count))
                    if !name.isEmpty { return name }
                }
            }
            return nil
        }

        /// Emits everything the closed `<pre>` held as one code block, indentation and blank lines
        /// intact. `<pre>` is the one place HTML says outright "these characters are literal", which is
        /// exactly what a fence says (RULES.md §7 — preserve declared structure, never guess it).
        private mutating func flushCode() {
            var lines = buffer.components(separatedBy: "\n")
            while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
            while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
            buffer = ""
            startsElement = true
            // A `<pre>` that never opened a `<code>` declared preformatted text and nothing more.
            let language = codeLanguage ?? (preHeldCode ? nil : CodeBlock.preformattedLanguage)
            codeLanguage = nil
            preHeldCode = false
            guard !lines.isEmpty else { return }
            blocks.append(.codeBlock(ImportedCode(code: lines.joined(separator: "\n"),
                                                  language: language)))
        }

        // MARK: Text

        private mutating func appendText(_ raw: String) {
            guard skipping == nil else { return }
            guard tableDepth == 0 || inCell else { return }   // whitespace between cells is layout

            let decoded = Entities.decode(raw)
            if preDepth > 0, !inCell {
                buffer += decoded
                preBoundaryEndedLine = false
                return
            }

            let collapsed = Self.collapsingWhitespace(decoded)
            guard !collapsed.isEmpty else { return }
            if collapsed == " ", buffer.isEmpty || buffer.hasSuffix(" ") { return }
            if buffer.hasSuffix(" "), collapsed.hasPrefix(" ") {
                buffer += collapsed.dropFirst()
            } else {
                buffer += collapsed
            }
        }

        /// HTML whitespace: a run of spaces, tabs, and newlines is one space. Non-breaking spaces are
        /// characters the writer put there and survive untouched.
        private static func collapsingWhitespace(_ text: String) -> String {
            var out = ""
            var previousWasSpace = false
            for character in text.unicodeScalars {
                let isSpace = character == " " || character == "\t" || character == "\n"
                    || character == "\r" || character == "\u{0B}" || character == "\u{0C}"
                if isSpace {
                    if !previousWasSpace { out.append(" ") }
                    previousWasSpace = true
                } else {
                    out.unicodeScalars.append(character)
                    previousWasSpace = false
                }
            }
            return out
        }

        private mutating func lineBreak() {
            if tableDepth > 0 {
                if inCell, !buffer.isEmpty, !buffer.hasSuffix(" ") { buffer += " " }
                return
            }
            if preDepth > 0 {
                buffer += "\n"
                return
            }

            let kind = pendingKind
            if buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !blocks.isEmpty {
                // Consecutive breaks are a blank line the writer left, and it stays one.
                blocks.append(.line(ImportedLine(kind: .paragraph, text: "", startsElement: false)))
                buffer = ""
            } else {
                flushBlock()
            }

            // A `<br>` is one break inside one element. Continuing a list item as a *second* item would
            // invent structure, so a broken item continues as a plain line.
            switch kind {
            case .heading, .subheading, .paragraph: pendingKind = kind
            case .bullet, .numbered, .checklist: pendingKind = .paragraph
            }
            itemKind = nil
            startsElement = false
        }

        private mutating func flushBlock() {
            if tableDepth > 0 {
                // A block boundary inside a cell keeps that cell's words apart; the row stays one line.
                if inCell, !buffer.isEmpty, !buffer.hasSuffix(" ") { buffer += " " }
                return
            }

            closeLink()
            let raw = buffer
            let kind = pendingKind
            let newElement = startsElement
            buffer = ""
            startsElement = true
            // An element inside the open list item ends a line, not the item.
            defer { pendingKind = itemKind ?? .paragraph }

            // Preformatted text: every line the source had is a line of the note, indentation included.
            if raw.contains("\n") {
                var lines = raw.components(separatedBy: "\n")
                while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
                while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
                for (index, line) in lines.enumerated() {
                    append(kind: index == 0 ? kind : .paragraph,
                           text: line,
                           startsElement: index == 0 ? newElement : false)
                }
                return
            }

            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let (resolved, content) = promoted(kind: kind, text: text)
            append(kind: resolved, text: content, startsElement: newElement)
        }

        /// A checkbox glyph inside a list the source itself declared is a checkbox.
        ///
        /// `<li>☐ Passport</li>` is what a list of tick boxes becomes when it passes through a format
        /// with no checkbox of its own — a chat app, a plain export, As Told's own copy-out. The list
        /// context is stated by the markup, so the glyph in front of the words is that item's marker
        /// rather than a word of it, exactly like the `•` a rich-text list draws. Handing back a box
        /// that cannot be ticked is the one outcome nobody is asking for.
        ///
        /// The same glyph in an ordinary paragraph, or in plain text, is left alone: without the list
        /// around it, it is a character the writer typed (RULES.md §4).
        private func promoted(kind: BlockKind, text: String) -> (BlockKind, String) {
            guard kind.isList, let box = RichPasteDocument.checkbox(startingLine: text) else {
                return (kind, text)
            }
            return (.checklist(checked: box.checked), box.rest)
        }

        private mutating func append(kind: BlockKind, text: String, startsElement: Bool) {
            var resolved = kind
            if case .numbered = kind, let last = lists.indices.last {
                resolved = .numbered(lists[last].counter)
                lists[last].counter += 1
            } else if case .numbered = kind {
                resolved = .numbered(1)
            }
            itemKind = nil
            blocks.append(.line(ImportedLine(kind: resolved, text: text, startsElement: startsElement)))
        }

        // MARK: Result

        mutating func finish() -> [ImportedBlock] {
            // A table the markup never closed still holds its cells, and cells are words.
            while tableDepth > 0 { endTable() }
            flushBlock()
            return blocks
        }
    }
}

// MARK: - Entities

extension RichPasteHTML {
    /// Character references back to the characters they stand for. An unknown reference is left exactly
    /// as written rather than guessed at — it is text either way, and the words must survive.
    enum Entities {
        static func decode(_ text: String) -> String {
            guard text.contains("&") else { return text }
            var out = ""
            var index = text.startIndex
            while index < text.endIndex {
                guard text[index] == "&" else {
                    out.append(text[index])
                    index = text.index(after: index)
                    continue
                }
                guard let semicolon = text[index...].firstIndex(of: ";"),
                      text.distance(from: index, to: semicolon) <= 12,
                      let replacement = replacement(for: String(text[text.index(after: index)..<semicolon]))
                else {
                    out.append(text[index])
                    index = text.index(after: index)
                    continue
                }
                out.append(replacement)
                index = text.index(after: semicolon)
            }
            return out
        }

        private static func replacement(for body: String) -> String? {
            guard !body.isEmpty else { return nil }
            if body.hasPrefix("#") {
                let digits = body.dropFirst()
                let value: UInt32?
                if digits.hasPrefix("x") || digits.hasPrefix("X") {
                    value = UInt32(digits.dropFirst(), radix: 16)
                } else {
                    value = UInt32(digits, radix: 10)
                }
                guard let value, let scalar = Unicode.Scalar(value) else { return nil }
                return String(Character(scalar))
            }
            return named[body]
        }

        private static let named: [String: String] = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
            "nbsp": "\u{00A0}", "ensp": "\u{2002}", "emsp": "\u{2003}", "thinsp": "\u{2009}",
            "shy": "\u{00AD}", "zwnj": "\u{200C}", "zwj": "\u{200D}",
            "ndash": "–", "mdash": "—", "hellip": "…", "bull": "•", "middot": "·",
            "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "sbquo": "‚", "bdquo": "„",
            "laquo": "«", "raquo": "»", "prime": "′", "Prime": "″",
            "dagger": "†", "Dagger": "‡", "sect": "§", "para": "¶",
            "copy": "©", "reg": "®", "trade": "™", "deg": "°", "plusmn": "±",
            "times": "×", "divide": "÷", "frac12": "½", "frac14": "¼", "frac34": "¾",
            "euro": "€", "pound": "£", "yen": "¥", "cent": "¢",
            "larr": "←", "rarr": "→", "harr": "↔", "check": "✓"
        ]
    }
}
