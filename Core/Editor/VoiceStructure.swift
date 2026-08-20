import Foundation

// Voice structure commands (Milestone B) built on the shared `DocumentAction` operations, so typing and
// voice converge on the same edits. This is deliberately conservative: a small fixed vocabulary,
// recognized only when spoken as an isolated phrase at a sentence boundary. When no command is detected
// the transcript is inserted verbatim — "Preserve the words. Format the speech." (RULES.md §2).
//
// Vocabulary: new paragraph · new line · heading · subheading · bullet list · numbered list · checklist ·
// next item · end list.
//
// Nine *actions*, each with a small closed set of spellings (added 2026-08-19, RULES.md §2). Speech is
// not a keyboard: a writer who means "start a bullet list" says "start bullet list" about as often as
// "bullet list", and having the first one land in the note as literal text is a failure of the parser,
// not of the writer. Every accepted alias is still an explicit instruction — the set is fixed, closed,
// and listed below, and nothing here infers structure from ordinary speech.

enum VoiceStructureParser {
    /// The nine actions. Aliases multiply the *spellings*, never this list.
    enum Command: CaseIterable {
        case newParagraph, newLine, heading, subheading, bulletList, numberedList, checklist, nextItem, endList
    }

    private enum Segment {
        case content(String)
        case command(Command)
    }

    /// The spoken vocabulary in *teaching* order, for the writing-help sheet: one phrasing per action,
    /// which is what a person can actually learn. `phrases` below is ordered by match precedence, which
    /// is not an order to show anyone, and accepts several spellings of each of these.
    /// `WritingHelpTests` pins this list to `recognizedPhrases`, so help can never advertise a command
    /// the parser does not accept (or quietly omit an action it does).
    static let vocabulary = [
        "New paragraph", "New line", "Heading", "Subheading",
        "Bullet list", "Numbered list", "Checklist", "Next item", "End list",
    ]

    /// Every spelling the matcher recognizes, and the action each performs. Exposed so the help sheet is
    /// checked against the real parser rather than against a copy of its contents.
    static var recognizedPhrases: [String: Command] {
        Dictionary(uniqueKeysWithValues: phrases.map { ($0.text, $0.command) })
    }

    // Longest first, so a phrase is never beaten to the match by a shorter one it contains
    // ("subheading" over "heading", "start numbered list" over "numbered list"). `inline` marks a
    // command that may be followed immediately by its content (only the next-item ones); the rest are
    // standalone and require a following terminator (or end of transcript).
    //
    // The aliases are deliberate and closed. Each one is a phrase whose only plausible reading is the
    // instruction — someone dictating prose does not utter "start numbered list." as a sentence — and
    // each still has to clear the same boundary tests as the canonical wording. "Normal paragraph"
    // leaves a list for the same reason the Style menu's row is called Paragraph: it is the name of the
    // thing you are going back to.
    private static let phrases: [(text: String, command: Command, inline: Bool)] = [
        ("start numbered list", .numberedList, false),
        ("start bullet list", .bulletList, false),
        ("normal paragraph", .endList, false),
        ("start checklist", .checklist, false),
        ("bulleted list", .bulletList, false),
        ("numbered list", .numberedList, false),
        ("new paragraph", .newParagraph, false),
        ("bullet list", .bulletList, false),
        ("subheading", .subheading, false),
        ("next item", .nextItem, true),
        ("stop list", .endList, false),
        ("checklist", .checklist, false),
        ("new item", .nextItem, true),
        ("end list", .endList, false),
        ("new line", .newLine, false),
        ("heading", .heading, false),
    ]

    /// Applies a transcript at a UTF-16 caret offset in `text`, interpreting structure commands where
    /// clearly present and otherwise inserting the words verbatim. Returns the new text and caret (UTF-16).
    static func apply(_ transcript: String, into text: String, atUTF16 offset: Int) -> (text: String, cursor: Int) {
        let segments = scan(transcript)
        let hasCommand = segments.contains { if case .command = $0 { return true }; return false }
        guard hasCommand else { return insertVerbatim(transcript, into: text, atUTF16: offset) }

        var text = text
        var caret = min(max(offset, 0), (text as NSString).length)
        var pendingKind: BlockKind?
        var inList: BlockKind?

        for segment in segments {
            switch segment {
            case .command(let command):
                switch command {
                case .newParagraph:
                    (text, caret) = insertRaw("\n\n", into: text, at: caret); pendingKind = nil; inList = nil
                case .newLine:
                    (text, caret) = insertRaw("\n", into: text, at: caret)
                case .heading:
                    pendingKind = .heading; inList = nil
                case .subheading:
                    pendingKind = .subheading; inList = nil
                case .bulletList:
                    pendingKind = .bullet; inList = .bullet
                case .numberedList:
                    pendingKind = .numbered(1); inList = .numbered(1)
                case .checklist:
                    pendingKind = .checklist(checked: false); inList = .checklist(checked: false)
                case .nextItem:
                    if inList != nil,
                       let result = DocumentAction.handleReturn(text: text, selection: NSRange(location: caret, length: 0)) {
                        text = result.text; caret = result.selection.location; pendingKind = nil
                    } else {
                        (text, caret) = insertRaw("\n", into: text, at: caret)
                    }
                case .endList:
                    inList = nil; pendingKind = .paragraph
                    (text, caret) = leaveStructure(text, at: caret)
                }
            case .content(let content):
                if let kind = pendingKind {
                    if !isAtLineStart(text, caret) { (text, caret) = insertRaw("\n", into: text, at: caret) }
                    let result = DocumentAction.setBlockKind(kind, text: text, selection: NSRange(location: caret, length: 0))
                    text = result.text; caret = result.selection.location
                    (text, caret) = insertContent(content, into: text, at: caret)
                    pendingKind = nil
                } else {
                    (text, caret) = insertContent(content, into: text, at: caret)
                }
            }
        }
        return (text, caret)
    }

    // MARK: Scanning

    private static func scan(_ transcript: String) -> [Segment] {
        let chars = Array(transcript)
        var segments: [Segment] = []
        var content = ""
        var i = 0

        func flushContent() {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { segments.append(.content(trimmed)) }
            content = ""
        }

        func atSentenceStart() -> Bool {
            var j = i - 1
            while j >= 0, chars[j] == " " || chars[j] == "\t" { j -= 1 }
            if j < 0 { return true }
            let c = chars[j]
            return c == "." || c == "!" || c == "?" || c == "\n"
        }

        while i < chars.count {
            if atSentenceStart(), let (command, consumed) = matchCommand(chars, at: i) {
                flushContent()
                segments.append(.command(command))
                i += consumed
            } else {
                content.append(chars[i])
                i += 1
            }
        }
        flushContent()
        return segments
    }

    private static func matchCommand(_ chars: [Character], at i: Int) -> (Command, consumed: Int)? {
        func isTerminator(_ c: Character) -> Bool {
            c == "." || c == "," || c == "!" || c == "?" || c == "…" || c == "\n"
        }

        /// Speech does not end a command with one tidy period — the model transcribes "new paragraph...",
        /// "heading…", "checklist!?". The whole punctuation run belongs to the command token; leaving part
        /// of it behind would drop stray dots into the note. A newline is a boundary, not part of a run.
        func endOfPunctuation(_ chars: [Character], from start: Int) -> Int {
            var k = start + 1
            while k < chars.count, isTerminator(chars[k]), chars[k] != "\n" { k += 1 }
            return k
        }

        for phrase in phrases {
            let p = Array(phrase.text)
            guard i + p.count <= chars.count else { continue }
            var matches = true
            for k in 0..<p.count where Character(chars[i + k].lowercased()) != p[k] { matches = false; break }
            guard matches else { continue }

            let after = i + p.count
            // The phrase must end on a word boundary, not be a prefix of a longer word ("headings").
            if after < chars.count, chars[after].isLetter || chars[after].isNumber { continue }

            if phrase.inline {
                var j = after
                if j < chars.count, isTerminator(chars[j]) { j = endOfPunctuation(chars, from: j) }
                while j < chars.count, chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" { j += 1 }
                return (phrase.command, j - i)
            } else {
                // Standalone: require a terminator (after optional spaces) or the end of the transcript.
                var j = after
                while j < chars.count, chars[j] == " " || chars[j] == "\t" { j += 1 }
                if j >= chars.count { return (phrase.command, j - i) }
                if isTerminator(chars[j]) {
                    var k = endOfPunctuation(chars, from: j)
                    while k < chars.count, chars[k] == " " || chars[k] == "\t" { k += 1 }
                    return (phrase.command, k - i)
                }
                // Followed by more words → ordinary speech, not a command.
                continue
            }
        }
        return nil
    }

    // MARK: Text helpers (UTF-16)

    /// Leaves the current structure for a normal paragraph — the spoken counterpart of pressing Return
    /// on an empty item, and deliberately the *same* operation underneath.
    ///
    /// The empty-item case is the one that used to go wrong. "Bullet list. Milk. Next item. End list."
    /// left the caret on an item holding nothing but its marker, and adding a newline there stranded
    /// that marker as an orphan bullet the speaker never asked for. Taking the marker instead ends the
    /// list exactly where the speaker ended it.
    private static func leaveStructure(_ text: String, at caret: Int) -> (String, Int) {
        let line = MarkupDocument(text).line(containingSource: caret)
        if line.kind != .paragraph, line.contentLength == 0,
           let result = DocumentAction.handleReturn(text: text,
                                                    selection: NSRange(location: caret, length: 0)) {
            return (result.text, result.selection.location)
        }
        return insertRaw("\n", into: text, at: caret)
    }

    private static func insertRaw(_ string: String, into text: String, at caret: Int) -> (String, Int) {
        let newText = (text as NSString).replacingCharacters(in: NSRange(location: caret, length: 0), with: string)
        return (newText, caret + (string as NSString).length)
    }

    private static func insertContent(_ content: String, into text: String, at caret: Int) -> (String, Int) {
        let charOffset = text.characterOffset(fromUTF16: caret)
        let (newText, cursor) = insertTranscript(content, into: text, at: charOffset)
        return (newText, newText.utf16Offset(fromCharacter: cursor))
    }

    private static func isAtLineStart(_ text: String, _ caret: Int) -> Bool {
        guard caret > 0 else { return true }
        return (text as NSString).character(at: caret - 1) == unichar(10)
    }

    static func insertVerbatim(_ transcript: String, into text: String, atUTF16 offset: Int) -> (text: String, cursor: Int) {
        let charOffset = text.characterOffset(fromUTF16: offset)
        let (newText, cursor) = insertTranscript(transcript, into: text, at: charOffset)
        return (newText, newText.utf16Offset(fromCharacter: cursor))
    }
}
