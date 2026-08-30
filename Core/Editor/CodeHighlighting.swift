import Foundation

// Syntax colour for a code card — and nothing else.
//
// Admitted 2026-08-24 on narrow terms (RULES.md §7): code pasted into As Told should look like code,
// and five kinds of token are what the eye actually uses to read a snippet — keywords, strings,
// comments, numbers, and the names being called. This is presentation. It writes attributes onto a
// card's own text and never touches `body`, so the note is the characters the writer pasted, exactly
// as it was before this file existed.
//
// Two rules keep it from becoming an IDE:
//
//  - **A language is never inferred.** `language(named:)` answers only for a name the source itself
//    stated on the opening fence, out of a closed list. A block with no language, or one this does not
//    know, is drawn in one colour — the same monospaced ground it had before. Guessing a language from
//    the code's contents is the same mistake as reading a short line as a heading (RULES.md §2, §4).
//  - **It is a scanner, not a parser.** It knows comments, strings, numbers, a fixed keyword list, and
//    a name immediately followed by `(`. It does not resolve symbols, check types, or understand
//    scope, and it never will — that is a compiler, and §7 excludes one.
//
// ASCII diagrams, logs, and preformatted prose stay uncoloured for the same reason a language is never
// inferred: nobody declared them to be a program.

enum CodeHighlighting {

    /// What a run of characters is, as far as the eye reading it needs to know.
    enum Token: Hashable, CaseIterable {
        case keyword
        case string
        case comment
        case number
        /// A type or a function — the names in the snippet that are being *called* or *declared*,
        /// which is the one such distinction a scanner can make without guessing.
        case type
    }

    /// One coloured run, in UTF-16 offsets so it can be applied to an attributed string directly.
    struct Span: Equatable {
        var range: NSRange
        var token: Token
    }

    /// One language's syntax, as much of it as colouring needs.
    struct Language: Equatable {
        /// What the card's label says. The source stated `sql`; a reader is shown `SQL`.
        var displayName: String
        var keywords: Set<String>
        /// SQL is written `SELECT` and `select` with equal authority; Swift is not.
        var keywordsAreCaseInsensitive: Bool
        var lineComments: [String]
        var blockComment: (open: String, close: String)?
        var stringDelimiters: Set<Character>
        /// Whether a backslash escapes the next character inside a string. Shell single quotes and
        /// SQL literals do not work that way, and pretending otherwise swallows half a file.
        var escapesInStrings: Bool
        /// Whether a name immediately followed by `(` is drawn as a function.
        var highlightsCalls: Bool
        /// Whether a Capitalized name is drawn as a type. Only where the language's own convention
        /// makes that reliable — never in a language where capitals are just capitals.
        var highlightsCapitalizedNames: Bool

        static func == (a: Language, b: Language) -> Bool { a.displayName == b.displayName }
    }

    // MARK: The closed list

    /// The language a fence *declared*, or `nil` when it declared none this knows.
    ///
    /// Matching is exact against the name and its common spellings. A fence saying `sqlite` is not
    /// SQL here: it is a name nobody taught this file, and one colour is the honest answer.
    static func language(named declared: String?) -> Language? {
        guard let declared else { return nil }
        let name = declared.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return nil }
        return languages[aliases[name] ?? name]
    }

    /// What the card's label shows for a declared language, or `nil` when there is nothing to show.
    /// A block with no language shows no label rather than "Plain text" — a label nobody stated is a
    /// guess, and an empty slot is quieter than a wrong word.
    static func displayName(for declared: String?) -> String? {
        if let known = language(named: declared) { return known.displayName }
        // A language this does not colour was still stated by the source, and saying so is not a
        // guess. It is shown as written, trimmed — never invented, never expanded.
        let raw = (declared ?? "").trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? nil : raw
    }

    private static let aliases: [String: String] = [
        "js": "javascript", "jsx": "javascript", "node": "javascript",
        "ts": "typescript", "tsx": "typescript",
        "py": "python", "python3": "python",
        "sh": "bash", "shell": "bash", "zsh": "bash",
        "yml": "yaml",
    ]

    private static let languages: [String: Language] = [
        "sql": Language(
            displayName: "SQL",
            keywords: [
                "select", "from", "where", "group", "by", "having", "order", "asc", "desc", "join",
                "left", "right", "inner", "outer", "full", "cross", "on", "as", "and", "or", "not",
                "null", "insert", "into", "values", "update", "set", "delete", "create", "table",
                "index", "view", "drop", "alter", "add", "primary", "key", "foreign", "references",
                "distinct", "limit", "offset", "union", "all", "case", "when", "then", "else", "end",
                "in", "is", "like", "between", "exists", "with", "using", "default", "constraint",
            ],
            keywordsAreCaseInsensitive: true,
            lineComments: ["--"],
            blockComment: ("/*", "*/"),
            stringDelimiters: ["'"],
            escapesInStrings: false,
            highlightsCalls: true,
            highlightsCapitalizedNames: false
        ),
        "python": Language(
            displayName: "Python",
            keywords: [
                "def", "class", "return", "if", "elif", "else", "for", "while", "break", "continue",
                "in", "not", "and", "or", "is", "import", "from", "as", "with", "try", "except",
                "finally", "raise", "lambda", "None", "True", "False", "pass", "global", "nonlocal",
                "yield", "assert", "del", "async", "await", "self",
            ],
            keywordsAreCaseInsensitive: false,
            lineComments: ["#"],
            blockComment: nil,
            stringDelimiters: ["'", "\""],
            escapesInStrings: true,
            highlightsCalls: true,
            highlightsCapitalizedNames: true
        ),
        "swift": Language(
            displayName: "Swift",
            keywords: [
                "func", "let", "var", "if", "else", "guard", "return", "for", "in", "while", "repeat",
                "switch", "case", "default", "break", "continue", "struct", "class", "enum", "protocol",
                "extension", "import", "init", "deinit", "self", "Self", "nil", "true", "false",
                "throws", "throw", "try", "catch", "do", "defer", "where", "as", "is", "some", "any",
                "static", "private", "fileprivate", "public", "internal", "open", "final", "override",
                "mutating", "async", "await", "typealias", "associatedtype", "subscript", "inout",
                "lazy", "weak", "unowned", "convenience", "required", "indirect",
            ],
            keywordsAreCaseInsensitive: false,
            lineComments: ["//"],
            blockComment: ("/*", "*/"),
            stringDelimiters: ["\""],
            escapesInStrings: true,
            highlightsCalls: true,
            highlightsCapitalizedNames: true
        ),
        "javascript": Language(
            displayName: "JavaScript",
            keywords: [
                "function", "const", "let", "var", "if", "else", "return", "for", "while", "do",
                "class", "extends", "super", "new", "this", "null", "undefined", "true", "false",
                "import", "export", "default", "from", "as", "async", "await", "try", "catch",
                "finally", "throw", "typeof", "instanceof", "switch", "case", "break", "continue",
                "in", "of", "delete", "void", "yield", "static", "get", "set",
            ],
            keywordsAreCaseInsensitive: false,
            lineComments: ["//"],
            blockComment: ("/*", "*/"),
            stringDelimiters: ["'", "\"", "`"],
            escapesInStrings: true,
            highlightsCalls: true,
            highlightsCapitalizedNames: true
        ),
        "typescript": Language(
            displayName: "TypeScript",
            keywords: [
                "function", "const", "let", "var", "if", "else", "return", "for", "while", "do",
                "class", "extends", "super", "new", "this", "null", "undefined", "true", "false",
                "import", "export", "default", "from", "as", "async", "await", "try", "catch",
                "finally", "throw", "typeof", "instanceof", "switch", "case", "break", "continue",
                "in", "of", "delete", "void", "yield", "static", "get", "set",
                "interface", "type", "enum", "implements", "private", "public", "protected",
                "readonly", "namespace", "declare", "abstract", "satisfies", "keyof", "infer",
            ],
            keywordsAreCaseInsensitive: false,
            lineComments: ["//"],
            blockComment: ("/*", "*/"),
            stringDelimiters: ["'", "\"", "`"],
            escapesInStrings: true,
            highlightsCalls: true,
            highlightsCapitalizedNames: true
        ),
        "json": Language(
            displayName: "JSON",
            // JSON has three words and no statements. Colouring anything else would be inventing a
            // grammar the format does not have.
            keywords: ["true", "false", "null"],
            keywordsAreCaseInsensitive: false,
            lineComments: [],
            blockComment: nil,
            stringDelimiters: ["\""],
            escapesInStrings: true,
            highlightsCalls: false,
            highlightsCapitalizedNames: false
        ),
        "yaml": Language(
            displayName: "YAML",
            keywords: ["true", "false", "null", "yes", "no", "on", "off"],
            keywordsAreCaseInsensitive: true,
            lineComments: ["#"],
            blockComment: nil,
            stringDelimiters: ["'", "\""],
            escapesInStrings: true,
            highlightsCalls: false,
            highlightsCapitalizedNames: false
        ),
        "bash": Language(
            displayName: "Bash",
            // Shell *syntax*, not a list of commands. `echo` is a program someone installed, and
            // colouring it like a keyword would be this file having an opinion about their $PATH.
            keywords: [
                "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case",
                "esac", "function", "in", "return", "export", "local", "readonly", "declare", "unset",
                "shift", "source", "exit", "break", "continue", "trap", "set",
            ],
            keywordsAreCaseInsensitive: false,
            lineComments: ["#"],
            blockComment: nil,
            stringDelimiters: ["'", "\""],
            escapesInStrings: true,
            highlightsCalls: false,
            highlightsCapitalizedNames: false
        ),
    ]

    // MARK: Scanning

    /// Every coloured run in `code`, in the order they appear and never overlapping.
    ///
    /// Precedence is the order a reader's eye resolves them: a keyword inside a comment is comment, a
    /// `--` inside a string is string. Anything unrecognised is left alone and keeps the card's own
    /// text colour, which is what makes an unknown construct harmless rather than mis-coloured.
    static func spans(in code: String, language: Language) -> [Span] {
        var spans: [Span] = []
        let characters = Array(code)
        var index = 0
        var offset = 0          // UTF-16, because that is what an NSRange counts

        func width(_ range: Range<Int>) -> Int {
            characters[range].reduce(0) { $0 + String($1).utf16.count }
        }

        while index < characters.count {
            let character = characters[index]
            let start = index
            let startOffset = offset

            // A comment runs to the end of its line, or to its closing delimiter, and everything in
            // it is comment — including code someone commented out.
            if language.lineComments.contains(where: { matches($0, in: characters, at: index) }) {
                while index < characters.count, characters[index] != "\n" { index += 1 }
                offset += width(start..<index)
                spans.append(Span(range: NSRange(location: startOffset, length: offset - startOffset),
                                  token: .comment))
                continue
            }
            if let block = language.blockComment, matches(block.open, in: characters, at: index) {
                index += block.open.count
                while index < characters.count, !matches(block.close, in: characters, at: index) {
                    index += 1
                }
                if index < characters.count { index += block.close.count }
                index = min(index, characters.count)
                offset += width(start..<index)
                spans.append(Span(range: NSRange(location: startOffset, length: offset - startOffset),
                                  token: .comment))
                continue
            }

            // A string runs to its matching quote. An unterminated one stops at the end of its line
            // rather than colouring the rest of the file — a half-typed quote is common, and a snippet
            // that turns green from one character down is worse than one that does not.
            if language.stringDelimiters.contains(character) {
                let quote = character
                index += 1
                while index < characters.count {
                    let current = characters[index]
                    if current == "\n" { break }
                    if language.escapesInStrings, current == "\\" {
                        index = min(index + 2, characters.count)
                        continue
                    }
                    index += 1
                    if current == quote { break }
                }
                offset += width(start..<index)
                spans.append(Span(range: NSRange(location: startOffset, length: offset - startOffset),
                                  token: .string))
                continue
            }

            // A number, only where one can start: after anything but a name character, so the `1` in
            // `utf8Data1` is part of the name.
            if character.isNumber, !isNameCharacter(previous(characters, before: start)) {
                while index < characters.count,
                      characters[index].isNumber || characters[index] == "." || characters[index] == "_" {
                    index += 1
                }
                // A trailing dot belongs to whatever follows, not to the number.
                if characters[index - 1] == "." { index -= 1 }
                offset += width(start..<index)
                spans.append(Span(range: NSRange(location: startOffset, length: offset - startOffset),
                                  token: .number))
                continue
            }

            // A name: a keyword, a call, a type, or nothing at all.
            if isNameStart(character) {
                while index < characters.count, isNameCharacter(characters[index]) { index += 1 }
                let name = String(characters[start..<index])
                offset += width(start..<index)
                let range = NSRange(location: startOffset, length: offset - startOffset)

                if isKeyword(name, in: language) {
                    spans.append(Span(range: range, token: .keyword))
                } else if language.highlightsCalls, isFollowedByOpenParen(characters, from: index) {
                    spans.append(Span(range: range, token: .type))
                } else if language.highlightsCapitalizedNames, name.first?.isUppercase == true {
                    spans.append(Span(range: range, token: .type))
                }
                continue
            }

            index += 1
            offset += String(character).utf16.count
        }
        return spans
    }

    // MARK: Small answers

    private static func isKeyword(_ name: String, in language: Language) -> Bool {
        language.keywordsAreCaseInsensitive
            ? language.keywords.contains(name.lowercased())
            : language.keywords.contains(name)
    }

    /// Whether `text` reads at `index`. Compared over Characters so a multi-scalar grapheme cannot
    /// half-match a delimiter.
    private static func matches(_ text: String, in characters: [Character], at index: Int) -> Bool {
        let wanted = Array(text)
        guard index + wanted.count <= characters.count else { return false }
        for (offset, character) in wanted.enumerated() where characters[index + offset] != character {
            return false
        }
        return true
    }

    private static func previous(_ characters: [Character], before index: Int) -> Character? {
        index > 0 ? characters[index - 1] : nil
    }

    /// Whitespace between a name and its parenthesis is still a call: `count (x)` is one in every
    /// language here. A newline is not — that is the next statement.
    private static func isFollowedByOpenParen(_ characters: [Character], from index: Int) -> Bool {
        var cursor = index
        while cursor < characters.count, characters[cursor] == " " || characters[cursor] == "\t" {
            cursor += 1
        }
        return cursor < characters.count && characters[cursor] == "("
    }

    private static func isNameStart(_ character: Character) -> Bool {
        character.isLetter || character == "_" || character == "$"
    }

    private static func isNameCharacter(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.isLetter || character.isNumber || character == "_" || character == "$"
    }
}
