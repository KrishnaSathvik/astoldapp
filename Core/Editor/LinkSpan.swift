import Foundation

// A link inside a note.
//
// `body` is one String and stays one String (RULES.md §5). A link is not a new model, a second field,
// an attributed string, or a migration — it is ordinary characters that happen to name a destination.
// There are exactly two spellings, and which one a note holds depends on where the link came from:
//
//   Booking is at https://astold.app
//   └─ a bare URL, exactly as it was typed or spoken. Nothing rewrites it.
//
//   Booking is at [Open reservation](https://astold.app/r/8fa2)
//   └─ a *labelled* link. Only paste writes this, and only when the clipboard stated a hyperlink
//      whose text differs from its href (RULES.md §7, links exception). The bracket and the
//      destination are hidden at the glyph layer; "Open reservation" is what the reader sees.
//
// Like `TableBlock`, this type only *reads*. It never rewrites a note, so a URL someone typed stays
// the characters they typed.
//
// Parsing is deliberately strict, for the same reason a table row must open with a pipe: a note that
// turned words into links because they resembled one would be worse than a note that linked nothing.
//   - A bare URL must carry an explicit `http://` or `https://` scheme. Prose that mentions
//     `apple.com` is prose.
//   - `[text](dest)` is a link only when `dest` is an absolute http(s) URL. Someone writing
//     "[see](this)" in a note keeps their brackets as words.
//
// All offsets/ranges are UTF-16 (NSString) units, in source coordinates.

/// One link found in a note's source.
struct LinkSpan: Equatable {
    /// Where the link goes.
    var destination: String
    /// The whole construct in the source, hidden syntax included — what a tap has to hit and what a
    /// delete has to take.
    var sourceRange: NSRange
    /// The part of the source the reader actually sees, and the only part a caret may enter.
    var displayRange: NSRange
    /// Source runs whose glyphs are hidden. Empty for a bare URL, which is visible in full.
    var hiddenRuns: [NSRange]

    /// Whether this link carries a label distinct from its destination.
    var isLabelled: Bool { !hiddenRuns.isEmpty }

    /// The words the reader sees, with any escaping backslashes resolved.
    func displayText(in source: String) -> String {
        let ns = source as NSString
        guard displayRange.location + displayRange.length <= ns.length else { return "" }
        var out = ""
        var index = displayRange.location
        let end = displayRange.location + displayRange.length
        let hidden = Set(hiddenRuns.flatMap { $0.location..<($0.location + $0.length) })
        while index < end {
            if !hidden.contains(index) { out += ns.substring(with: NSRange(location: index, length: 1)) }
            index += 1
        }
        return out
    }
}

extension LinkSpan {

    // MARK: Writing

    /// The canonical source for a hyperlink a clipboard stated.
    ///
    /// A link whose text is already its destination is written as the bare URL — the labelled form
    /// exists to carry a label, and `[https://x](https://x)` would be the app inventing syntax around
    /// words the user never wrote.
    static func source(label: String, destination: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard isAbsoluteWebURL(destination) else { return label }
        guard !trimmed.isEmpty, trimmed != destination else { return destination }
        return "[\(escapingLabel(label))](\(escapingDestination(destination)))"
    }

    /// `]` and `\` inside a label would end the label early or eat the next character, so they travel
    /// as their escaped spellings — the only characters this ever touches.
    static func escapingLabel(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    /// Same argument for `)` inside a destination.
    static func escapingDestination(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ")", with: "\\)")
    }

    /// A destination As Told will actually open: an absolute URL with a web scheme and a host.
    ///
    /// The scheme allowlist is the safety rule, not a formality. `body` is ordinary text a note can
    /// receive from a clipboard, and a tappable `javascript:` or `file:` run in someone's notes is a
    /// hazard rather than a link (RULES.md §3).
    static func isAbsoluteWebURL(_ text: String) -> Bool {
        guard !text.isEmpty, text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty
        else { return false }
        return true
    }

    // MARK: Reading

    /// Every link in one line's *content* — the part after any hidden block marker — with ranges
    /// reported in whole-source coordinates.
    ///
    /// Labelled links are found first and bare URLs only in the gaps between them, so the `https://`
    /// inside `[Open reservation](https://…)` is part of that link rather than a second one.
    static func links(inLineContent content: String, offset: Int) -> [LinkSpan] {
        let ns = content as NSString
        var found: [LinkSpan] = []
        var index = 0

        while index < ns.length {
            let character = ns.character(at: index)

            if character == unichar(91), !isEscaped(ns, at: index),          // "["
               let link = labelled(ns, from: index, offset: offset) {
                found.append(link)
                index = link.sourceRange.location - offset + link.sourceRange.length
                continue
            }
            if let link = bare(ns, from: index, offset: offset) {
                found.append(link)
                index = link.sourceRange.location - offset + link.sourceRange.length
                continue
            }
            index += 1
        }
        return found
    }

    /// `[label](destination)` starting at `start`, or `nil` when those characters are just characters.
    private static func labelled(_ ns: NSString, from start: Int, offset: Int) -> LinkSpan? {
        var escapes: [NSRange] = []
        var index = start + 1
        var closeBracket = -1

        while index < ns.length {
            let character = ns.character(at: index)
            if character == unichar(92), index + 1 < ns.length {             // "\"
                escapes.append(NSRange(location: index + offset, length: 1))
                index += 2
                continue
            }
            if character == unichar(93) { closeBracket = index; break }      // "]"
            if character == unichar(10) { return nil }                       // a link never spans lines
            index += 1
        }
        guard closeBracket > start + 1 else { return nil }                   // an empty label shows nothing
        guard closeBracket + 1 < ns.length,
              ns.character(at: closeBracket + 1) == unichar(40) else { return nil }   // "("

        var destination = ""
        var closeParen = -1
        index = closeBracket + 2
        while index < ns.length {
            let character = ns.character(at: index)
            if character == unichar(92), index + 1 < ns.length {
                destination += ns.substring(with: NSRange(location: index + 1, length: 1))
                index += 2
                continue
            }
            if character == unichar(41) { closeParen = index; break }        // ")"
            if character == unichar(10) { return nil }
            destination += ns.substring(with: NSRange(location: index, length: 1))
            index += 1
        }
        guard closeParen > 0, isAbsoluteWebURL(destination) else { return nil }

        let displayRange = NSRange(location: start + 1 + offset, length: closeBracket - start - 1)
        var hidden = [NSRange(location: start + offset, length: 1)]
        hidden.append(contentsOf: escapes)
        hidden.append(NSRange(location: closeBracket + offset, length: closeParen - closeBracket + 1))

        return LinkSpan(destination: destination,
                        sourceRange: NSRange(location: start + offset, length: closeParen - start + 1),
                        displayRange: displayRange,
                        hiddenRuns: hidden.sorted { $0.location < $1.location })
    }

    /// A bare `http(s)://…` run starting at `start`, or `nil`.
    private static func bare(_ ns: NSString, from start: Int, offset: Int) -> LinkSpan? {
        guard matchesScheme(ns, at: start) else { return nil }
        // "xhttps://y" is one word, not a link inside a word.
        if start > 0, let previous = Unicode.Scalar(ns.character(at: start - 1)),
           CharacterSet.alphanumerics.contains(previous) { return nil }

        var end = start
        while end < ns.length {
            guard let scalar = Unicode.Scalar(ns.character(at: end)),
                  !CharacterSet.whitespacesAndNewlines.contains(scalar) else { break }
            end += 1
        }
        end = trimmingTrailingPunctuation(ns, from: start, to: end)

        let text = ns.substring(with: NSRange(location: start, length: end - start))
        guard isAbsoluteWebURL(text) else { return nil }

        let range = NSRange(location: start + offset, length: end - start)
        return LinkSpan(destination: text, sourceRange: range, displayRange: range, hiddenRuns: [])
    }

    private static func matchesScheme(_ ns: NSString, at index: Int) -> Bool {
        for scheme in ["https://", "http://"] {
            let length = (scheme as NSString).length
            guard index + length <= ns.length else { continue }
            if ns.substring(with: NSRange(location: index, length: length)).lowercased() == scheme {
                return true
            }
        }
        return false
    }

    /// Pulls sentence punctuation back out of a URL.
    ///
    /// "Booking is at https://astold.app." ends a sentence; the period is not part of the address.
    /// A closing bracket is only dropped when the URL never opened one, so a Wikipedia address that
    /// legitimately ends in `)` keeps it.
    private static func trimmingTrailingPunctuation(_ ns: NSString, from start: Int, to end: Int) -> Int {
        var end = end
        let trailing: Set<unichar> = [46, 44, 59, 58, 33, 63, 34, 39]        // . , ; : ! ? " '
        let closers: [unichar: unichar] = [41: 40, 93: 91, 125: 123]         // ) ] }

        while end > start {
            let character = ns.character(at: end - 1)
            if trailing.contains(character) { end -= 1; continue }
            if let opener = closers[character] {
                let text = ns.substring(with: NSRange(location: start, length: end - start)) as NSString
                var opens = 0, closes = 0
                for i in 0..<text.length {
                    if text.character(at: i) == opener { opens += 1 }
                    if text.character(at: i) == character { closes += 1 }
                }
                if closes > opens { end -= 1; continue }
            }
            break
        }
        return end
    }

    private static func isEscaped(_ ns: NSString, at index: Int) -> Bool {
        var backslashes = 0
        var probe = index - 1
        while probe >= 0, ns.character(at: probe) == unichar(92) { backslashes += 1; probe -= 1 }
        return backslashes % 2 == 1
    }
}
