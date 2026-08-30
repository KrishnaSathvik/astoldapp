import Foundation
import UIKit
import UniformTypeIdentifiers

// Paste from another app, part two: choosing what to read, and reading attributed text.
//
// The pasteboard usually carries the same content several times over — an HTML flavor, an RTF /
// attributed flavor, and plain text. Taking the plain text first, as the editor used to, throws away
// everything the source app already knew about which lines were headings and which were list items.
// So the flavors are inspected richest-first, and the first one that actually carries structure As Told
// supports wins:
//
//   1. `com.astold.structured-text` — As Told → As Told, the exact source. Nothing is more faithful.
//   2. `public.html`               — headings, lists, checklists, tables (`RichPasteHTML`).
//   3. `public.rtf` / flat RTFD    — list structure, from the attributed string's own text lists.
//   4. a declared Markdown type    — headings, lists, checklists, tables (`RichPasteMarkdown`).
//   5. plain text                  — pasted exactly as it arrived, with nothing inferred from it.
//
// Steps 2 through 4 *translate* structure the clipboard states outright; they never deduce it. Step 4 is
// reached only when the pasteboard declares the Markdown type by name — text that merely looks like
// Markdown is text. A plain-text clipboard reaches step 5 untouched — nothing here reads it, because a
// short line is not a heading and guessing would be rewriting the note (RULES.md §2, §4). This adds no
// formatting capability: it only lets paste reach the structures the editor already has.
//
// One accepted limitation, and it is the storage format's rather than this file's: `body` *is* the source,
// so a pasted line that already begins with `# `, `- `, `1. `, or `- [ ] ` renders as that structure. The
// characters are unchanged — nothing is inserted, removed, or reworded — but the format cannot tell a
// marker that was typed from one that was pasted without escaping or per-line metadata, which is a storage
// redesign V1 does not attempt. See RULES.md §4 and docs/02-features.md (Milestone A).

enum RichPasteImport {

    /// The As Told source a paste should insert, or `nil` when nothing on the pasteboard carries
    /// structure — the caller then lets the system's own plain-text paste run.
    static func source(from pasteboard: UIPasteboard) -> String? {
        if pasteboard.contains(pasteboardTypes: [StructuredTextExport.pasteboardType]),
           let data = pasteboard.data(forPasteboardType: StructuredTextExport.pasteboardType),
           let structured = String(data: data, encoding: .utf8), !structured.isEmpty {
            return structured
        }

        if pasteboard.contains(pasteboardTypes: [UTType.html.identifier]),
           let html = string(pasteboard.value(forPasteboardType: UTType.html.identifier)),
           let source = RichPasteHTML.source(from: html) {
            return source
        }

        for type in [UTType.rtf.identifier, UTType.flatRTFD.identifier] {
            guard pasteboard.contains(pasteboardTypes: [type]),
                  let data = pasteboard.data(forPasteboardType: type),
                  let attributed = attributedString(from: data, type: type),
                  let source = source(fromAttributed: attributed)
            else { continue }
            return source
        }

        for type in markdownTypes where pasteboard.contains(pasteboardTypes: [type]) {
            guard let markdown = string(pasteboard.value(forPasteboardType: type)),
                  let source = RichPasteMarkdown.source(from: markdown)
            else { continue }
            return source
        }

        return nil
    }

    /// The identifiers an app uses to say "this is Markdown". Only a pasteboard that names one of them
    /// reaches `RichPasteMarkdown`; `public.plain-text` never does, however much of it looks like
    /// Markdown (RULES.md §4).
    static let markdownTypes = ["net.daringfireball.markdown", "public.markdown", "text/markdown"]

    // MARK: Attributed text

    /// Converts an attributed string into As Told source, or `nil` when it holds no list structure.
    ///
    /// Rich text says far less about a document than HTML does: it has real *text lists*, which is
    /// exactly the structure As Told can keep, but a heading in RTF is only larger, bolder type. Type
    /// size is not a statement that a line is a heading, so nothing here reads one — a line that merely
    /// looks like a title stays a paragraph.
    static func source(fromAttributed attributed: NSAttributedString) -> String? {
        RichPasteDocument.canonicalSource(document(fromAttributed: attributed))
    }

    static func document(fromAttributed attributed: NSAttributedString) -> [ImportedBlock] {
        let text = attributed.string as NSString
        guard text.length > 0 else { return [] }

        var blocks: [ImportedBlock] = []
        var counter = 1
        // What the paragraph above was, so a list continues its numbering and a new one restarts it.
        // Compared by marker format rather than by object: an importer may hand every paragraph of one
        // list its own `NSTextList`, and restarting at each item would number a list "1. 1. 1.".
        var previousFormat: NSTextList.MarkerFormat?

        // A `.link` attribute is a hyperlink the source *stated* — not an appearance guessed at from
        // blue underlined type — so it is structure that travels (RULES.md §4).
        let carriesLinks = attributed.hasLink(in: NSRange(location: 0, length: text.length))

        for paragraph in paragraphRanges(in: text) {
            let content = carriesLinks
                ? linked(attributed, paragraph: paragraph, text: text)
                : text.substring(with: paragraph)
            let style = paragraph.length > 0
                ? attributed.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
                : nil

            guard let list = style?.textLists.last else {
                previousFormat = nil
                // `startsElement: false` throughout: rich text has no element boundaries to read, only
                // paragraphs, and a blank line between two of them is one the writer actually left.
                blocks.append(.line(ImportedLine(kind: .paragraph, text: content, startsElement: false)))
                continue
            }

            if previousFormat != list.markerFormat { counter = list.startingItemNumber }
            previousFormat = list.markerFormat

            let kind: BlockKind
            let item: String
            if let box = RichPasteDocument.checkbox(startingLine: content) {
                // The list drew a tick box. Reducing it to a bullet — which is what this did until
                // 2026-08-20 — threw away the one thing the writer wants back: a box they can tick.
                (kind, item) = (.checklist(checked: box.checked), box.rest)
            } else if let ticked = checklistFormat(list.markerFormat) {
                (kind, item) = (.checklist(checked: ticked), strippingListMarker(content))
            } else if isOrdered(list.markerFormat) {
                (kind, item) = (.numbered(counter), strippingListMarker(content))
                counter += 1
            } else {
                (kind, item) = (.bullet, strippingListMarker(content))
            }
            blocks.append(.line(ImportedLine(kind: kind, text: item, startsElement: false)))
        }

        return blocks
    }

    /// One paragraph's text, with every `.link` run written as canonical link source.
    private static func linked(_ attributed: NSAttributedString, paragraph: NSRange,
                               text: NSString) -> String {
        guard paragraph.length > 0 else { return "" }
        var out = ""
        var index = paragraph.location
        let end = NSMaxRange(paragraph)

        while index < end {
            var run = NSRange(location: 0, length: 0)
            let value = attributed.attribute(.link, at: index, longestEffectiveRange: &run,
                                             in: NSRange(location: index, length: end - index))
            guard run.length > 0 else { break }
            let words = text.substring(with: run)
            let destination = (value as? URL)?.absoluteString ?? (value as? String)
            out += destination.map { LinkSpan.source(label: words, destination: $0) } ?? words
            index = NSMaxRange(run)
        }
        return out
    }

    /// `NSTextList` has two marker formats that *are* checkboxes. A list that names one is stating
    /// checklist structure as plainly as an `<input type="checkbox">` does.
    private static func checklistFormat(_ format: NSTextList.MarkerFormat) -> Bool? {
        switch format {
        case .box: return false
        case .check: return true
        default: return nil
        }
    }

    private static func paragraphRanges(in text: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var start = 0
        // Paragraph separators as TextKit writes them: "\n", and the U+2028/U+2029 an RTF import can use.
        let separators = CharacterSet(charactersIn: "\n\u{2028}\u{2029}")
        while start <= text.length {
            let rest = NSRange(location: start, length: text.length - start)
            let separator = text.rangeOfCharacter(from: separators, options: [], range: rest)
            if separator.location == NSNotFound {
                ranges.append(rest)
                break
            }
            ranges.append(NSRange(location: start, length: separator.location - start))
            start = separator.location + separator.length
        }
        return ranges
    }

    /// The ordinal formats. Everything else — disc, circle, square, hyphen, box, check — is a bullet.
    private static func isOrdered(_ format: NSTextList.MarkerFormat) -> Bool {
        switch format {
        case .decimal, .octal, .lowercaseHexadecimal, .uppercaseHexadecimal,
             .lowercaseAlpha, .uppercaseAlpha, .lowercaseLatin, .uppercaseLatin,
             .lowercaseRoman, .uppercaseRoman:
            return true
        default:
            return false
        }
    }

    /// The glyphs a rich-text list draws in front of an item. Ordinals are handled separately.
    private static let bulletGlyphs: Set<Character> = ["•", "◦", "▪", "▸", "‣", "-", "–", "—",
                                                       "*", "☐", "☑", "◆", "○"]

    /// Removes the marker text a rich-text list item carries in front of its words ("\t•\t", "1.\t").
    ///
    /// Only ever applied to a paragraph the document itself declared a list item, where the marker is a
    /// duplicate of the structure being applied — never to prose, which would be reading a leading dash
    /// as a bullet. Everything before the marker's tab has to *be* a marker, so an item whose own words
    /// contain a tab keeps them.
    private static func strippingListMarker(_ line: String) -> String {
        if let tab = line.prefix(16).lastIndex(of: "\t"),
           isMarkerOnly(line[line.startIndex..<tab]) {
            return String(line[line.index(after: tab)...])
        }

        var rest = line[...].drop(while: { $0 == " " || $0 == "\u{00A0}" })
        if let first = rest.first, bulletGlyphs.contains(first) {
            rest = rest.dropFirst()
        } else {
            let digits = rest.prefix(while: { $0.isASCII && $0.isNumber })
            guard !digits.isEmpty,
                  let terminator = rest.dropFirst(digits.count).first,
                  terminator == "." || terminator == ")"
            else { return line }
            rest = rest.dropFirst(digits.count + 1)
        }
        guard let next = rest.first, next == " " || next == "\u{00A0}" || next == "\t" else { return line }
        return String(rest.drop(while: { $0 == " " || $0 == "\u{00A0}" || $0 == "\t" }))
    }

    /// Whether a run of text is nothing but a list's own marker — blank, a bullet glyph, or an ordinal.
    private static func isMarkerOnly(_ text: Substring) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        if let only = trimmed.first, trimmed.count == 1, bulletGlyphs.contains(only) { return true }
        let digits = trimmed.prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty else { return false }
        let tail = trimmed.dropFirst(digits.count)
        return tail.isEmpty || tail == "." || tail == ")"
    }

    // MARK: Pasteboard flavors

    private static func attributedString(from data: Data, type: String) -> NSAttributedString? {
        let documentType: NSAttributedString.DocumentType = type == UTType.rtf.identifier ? .rtf : .rtfd
        return try? NSAttributedString(data: data,
                                       options: [.documentType: documentType],
                                       documentAttributes: nil)
    }

    /// A pasteboard flavor arrives as either a `String` or `Data`, and a Windows-authored HTML flavor
    /// need not be UTF-8. Decoding widest-last keeps a mis-decode from turning text into mojibake.
    private static func string(_ value: Any?) -> String? {
        if let string = value as? String { return string.isEmpty ? nil : string }
        guard let data = value as? Data, !data.isEmpty else { return nil }
        for encoding: String.Encoding in [.utf8, .utf16, .windowsCP1252, .isoLatin1] {
            if let string = String(data: data, encoding: encoding), !string.isEmpty { return string }
        }
        return nil
    }
}

#if DEBUG
// MARK: - Clipboard diagnostics

extension RichPasteImport {

    /// What the pasteboard is actually offering, and which reader took it — printed only when the app
    /// is launched with `-logPasteFlavors`, and only in a debug build.
    ///
    /// This exists to answer one question we could not answer from a screenshot: when a real assistant
    /// app's answer pastes badly, *which representation did we get*? Structure only — tag and flavor
    /// counts, never a character of the note (RULES.md §3). Nothing here reads well enough to
    /// reconstruct what was copied.
    static func logFlavors(of pasteboard: UIPasteboard) {
        guard ProcessInfo.processInfo.arguments.contains("-logPasteFlavors") else { return }

        var report = ["paste — pasteboard types:"]
        for type in pasteboard.types.sorted() { report.append("  · \(type)") }

        let html = pasteboard.contains(pasteboardTypes: [UTType.html.identifier])
            ? string(pasteboard.value(forPasteboardType: UTType.html.identifier)) : nil
        if let html {
            report.append("  html: \(html.count) chars, " + tagCounts(in: html))
            report.append("  html → " + describe(RichPasteHTML.document(from: html)))
        }
        for type in markdownTypes where pasteboard.contains(pasteboardTypes: [type]) {
            guard let markdown = string(pasteboard.value(forPasteboardType: type)) else { continue }
            report.append("  \(type): \(markdown.count) chars")
            report.append("  markdown → " + describe(RichPasteMarkdown.document(from: markdown)))
        }
        report.append("  chosen: " + chosenPath(of: pasteboard))
        print(report.joined(separator: "\n"))
    }

    private static func chosenPath(of pasteboard: UIPasteboard) -> String {
        if pasteboard.contains(pasteboardTypes: [StructuredTextExport.pasteboardType]) { return "As Told source" }
        guard source(from: pasteboard) != nil else { return "plain text (nothing stated structure)" }
        if pasteboard.contains(pasteboardTypes: [UTType.html.identifier]),
           let html = string(pasteboard.value(forPasteboardType: UTType.html.identifier)),
           RichPasteHTML.source(from: html) != nil {
            return "html"
        }
        for type in [UTType.rtf.identifier, UTType.flatRTFD.identifier]
        where pasteboard.contains(pasteboardTypes: [type]) { return "rich text" }
        return "declared markdown"
    }

    /// Tag counts, plus the one measurement that decides an open product question: how many blocks this
    /// source draws as a whole line of bold instead of as a heading.
    private static func tagCounts(in html: String) -> String {
        let lowered = html.lowercased()
        let counts = ["h1", "h2", "h3", "ul", "ol", "li", "table", "tr", "strong", "b", "em", "p", "br"]
            .map { "\($0)=\(occurrences(of: "<\($0)", in: lowered, wordBoundary: true))" }
        let checkboxes = occurrences(of: "type=\"checkbox\"", in: lowered, wordBoundary: false)
            + occurrences(of: "type=checkbox", in: lowered, wordBoundary: false)
        // Bold is only sometimes a tag. Notes, Docs, and most web sources write it as CSS, so a source
        // can be full of bold section titles and still report `strong=0 b=0` — which is exactly the
        // measurement the "is a bold block a heading?" question turns on.
        let bold = [
            "checkbox-inputs=\(checkboxes)",
            "font-weight-decls=\(occurrences(of: "font-weight", in: lowered, wordBoundary: false))",
            "bold-tag-blocks=\(matches(boldTagBlock, in: html))",
            "bold-css-blocks=\(matches(boldCSSBlock, in: html) + matches(boldStyledBlock, in: html))",
            "bold-class-blocks=\(boldClassBlocks(in: html))",
            // Markdown that was pasted into the source app as text and stayed text. If these are here,
            // the "bold" in the document is a pair of asterisks, and no styling rule can find it.
            "literal-asterisk-runs=\(occurrences(of: "**", in: html, wordBoundary: false))"
        ]
        return (counts + bold).joined(separator: " ")
    }

    /// `<p><strong>Overview</strong></p>` — a block whose whole content is a bold tag.
    private static let boldTagBlock = "<(p|div|li)[^>]*>\\s*<(strong|b)[^>]*>[^<]*</(strong|b)>\\s*</(p|div|li)>"
    /// The same block written the way a real editor writes it: one span, bold by stylesheet.
    private static let boldCSSBlock =
        "<(p|div|li)[^>]*>\\s*<span[^>]*font-weight\\s*:\\s*(bold|[6-9]00)[^>]*>[^<]*</span>\\s*</(p|div|li)>"
    /// And the block styled bold directly, with no inner element at all.
    private static let boldStyledBlock =
        "<(p|div|li)[^>]*font-weight\\s*:\\s*(bold|[6-9]00)[^>]*>[^<]*</(p|div|li)>"

    /// Bold written the third way: a stylesheet class. Notes and Docs both emit `<style>` with rules
    /// like `.s2 { font-weight: bold }` and then hang that class on the block, so the block carries no
    /// `font-weight` of its own and every inline-style counter reads zero.
    private static func boldClassBlocks(in html: String) -> Int {
        let rule = "\\.([A-Za-z0-9_-]+)[^{}]*\\{[^}]*font-weight\\s*:\\s*(bold|[6-9]00)[^}]*\\}"
        guard let regex = try? NSRegularExpression(pattern: rule, options: .caseInsensitive) else { return 0 }
        let range = NSRange(html.startIndex..., in: html)
        let names = regex.matches(in: html, range: range).compactMap { match -> String? in
            guard let name = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[name])
        }
        return names.reduce(0) { total, name in
            total
                + matches("<(p|div|li)[^>]*class=\"[^\"]*\\b\(name)\\b[^\"]*\"[^>]*>", in: html)
                + matches("<(p|div|li)[^>]*>\\s*<span[^>]*class=\"[^\"]*\\b\(name)\\b[^\"]*\"[^>]*>[^<]*</span>\\s*</(p|div|li)>",
                          in: html)
        }
    }

    private static func matches(_ pattern: String, in html: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return 0 }
        return regex.numberOfMatches(in: html, range: NSRange(html.startIndex..., in: html))
    }

    private static func occurrences(of needle: String, in haystack: String, wordBoundary: Bool) -> Int {
        var count = 0
        var index = haystack.startIndex
        while let found = haystack.range(of: needle, range: index..<haystack.endIndex) {
            let after = found.upperBound
            if !wordBoundary || after == haystack.endIndex
                || !(haystack[after].isLetter || haystack[after].isNumber) {
                count += 1
            }
            index = after
        }
        return count
    }

    private static func describe(_ blocks: [ImportedBlock]) -> String {
        var kinds: [String: Int] = [:]
        for block in blocks {
            switch block {
            case .line(let line) where line.text.isEmpty: kinds["blank", default: 0] += 1
            case .line(let line): kinds[String(describing: BlockStyle(line.kind)), default: 0] += 1
            case .table(let table): kinds["table(\(table.rows.count)×\(table.rows.map(\.count).max() ?? 0))",
                                          default: 0] += 1
            case .codeBlock(let code):
                kinds["code(\(code.code.components(separatedBy: "\n").count) lines)", default: 0] += 1
            }
        }
        return kinds.isEmpty ? "nothing" : kinds.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    }
}
#endif

private extension NSAttributedString {
    /// Whether any run in `range` carries a `.link`. Answers the common case — rich text with no
    /// hyperlink in it — without walking the string run by run.
    func hasLink(in range: NSRange) -> Bool {
        var found = false
        enumerateAttribute(.link, in: range, options: .longestEffectiveRangeNotRequired) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }
}
