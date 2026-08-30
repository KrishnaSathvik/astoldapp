import Foundation

// One of the two places As Told is allowed to infer structure from plain prose.
//
// The other is `PreformattedDetection`, added 2026-08-25 on the same argument and with the same
// discipline. The two cannot both claim a paste: this file answers only for the eight languages
// `CodeHighlighting` can colour, and no program contains box-drawing characters.
//
// Every other reader in this app translates structure a source *stated* — an `<h2>`, an `NSTextList`,
// a declared Markdown fence — and nothing anywhere reads plain text to decide what it is. That rule
// was locked, and it was amended on 2026-08-24 for exactly one case (RULES.md §4):
//
//   Never infer document structure from plain prose, **except high-confidence code detection and
//   high-confidence preformatted-diagram detection on paste**.
//
// The amendment is narrow on purpose, and the asymmetry is the whole design. Code left as prose is a
// small disappointment the writer can fix with **Paste as Code**. Prose turned into a code card is the
// note being rewritten — fence characters in `body` that nobody typed — which is the failure this app
// exists not to have. So everything here is built to be *wrong in the safe direction*:
//
//  - **Only the eight languages `CodeHighlighting` can colour.** A detected block always arrives with a
//    real label and real syntax colour. Naming a language the highlighter does not know would produce a
//    card that says "java" and looks like plain monospace, which is worse than leaving the text alone.
//  - **A decisive signature, or three supporting ones.** A decisive signature is one that essentially
//    cannot occur in a sentence — a shebang, `SELECT … FROM`, `def name(…):`. Supporting signatures are
//    weaker and never act alone.
//  - **A prose guard that overrules any score.** Text with the symbol density and line shapes of
//    writing is writing, however many keywords happen to be in it.
//  - **No detection from a single line**, unless that line carries a decisive signature. One line is
//    not a program.
//
// YAML is deliberately the strictest of the eight: `key: value` and `- item` are what an ordinary note
// looks like, and As Told already has a bulleted list. It is detected only from a `---` document marker
// or genuinely nested indentation — never from a flat list of colons (see `yamlEvidence`).

enum CodeDetection {

    /// A language a paste can be auto-fenced as, with the signatures that decided it.
    struct Match: Equatable {
        /// A name `CodeHighlighting.language(named:)` answers to.
        var language: String
        /// Why — kept because a detector nobody can interrogate is a detector nobody can trust.
        var evidence: [String]
    }

    /// The language `text` is, or `nil` — which is every case that is not obvious.
    static func detect(_ text: String) -> Match? {
        let lines = text.components(separatedBy: "\n")
        let content = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !content.isEmpty, text.count <= 200_000 else { return nil }
        guard !readsAsProse(content) else { return nil }

        var best: Match?
        var bestWeight = 0
        for language in languages {
            let evidence = language.evidence(content, text)
            guard !evidence.isEmpty else { continue }
            let decisive = evidence.filter { $0.hasPrefix("!") }.count
            let supporting = evidence.count - decisive
            // One line is not a program unless what is on it could be nothing else.
            guard decisive > 0 || (content.count >= 2 && supporting >= 3) else { continue }
            guard content.count >= 2 || decisive > 0 else { continue }

            let weight = decisive * 10 + supporting
            if weight > bestWeight {
                bestWeight = weight
                best = Match(language: language.name,
                             evidence: evidence.map { $0.hasPrefix("!") ? String($0.dropFirst()) : $0 })
            }
        }
        return best
    }

    // MARK: The prose guard

    /// Whether this reads as writing rather than as a program. Overrules every score.
    ///
    /// Two independent measures, because either alone has a blind spot: symbol density catches prose
    /// that happens to contain a keyword, and sentence shape catches technical writing that is dense
    /// with punctuation but is still sentences.
    static func readsAsProse(_ content: [String]) -> Bool {
        let joined = content.joined(separator: " ")
        guard !joined.isEmpty else { return true }

        let symbols = joined.reduce(0) { total, character in
            total + (Self.codePunctuation.contains(character) ? 1 : 0)
        }
        // Under one symbol in fifty characters, nothing here is a program.
        if Double(symbols) / Double(joined.count) < 0.02 { return true }

        // Lines shaped like sentences: several words, ending in sentence punctuation.
        let sentences = content.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let last = trimmed.last, ".!?".contains(last) else { return false }
            return trimmed.split(separator: " ").count >= 5
        }.count
        return Double(sentences) / Double(content.count) > 0.5
    }

    /// The hyphen earns its place here: `--save-dev`, `-euo`, and `--dry-run` are most of the symbols
    /// a shell command has, and without it every command line scored zero and was thrown out as prose.
    private static let codePunctuation = Set("{}()[];=<>|&$*/\\+#@:_`~%^-")

    // MARK: Languages

    private struct Rules: Sendable {
        var name: String
        var evidence: @Sendable ([String], String) -> [String]
    }

    /// A decisive signature is marked with a leading "!" and is enough on its own.
    private static let languages: [Rules] = [
        Rules(name: "python", evidence: pythonEvidence),
        Rules(name: "sql", evidence: sqlEvidence),
        Rules(name: "javascript", evidence: javascriptEvidence),
        Rules(name: "typescript", evidence: typescriptEvidence),
        Rules(name: "swift", evidence: swiftEvidence),
        Rules(name: "json", evidence: jsonEvidence),
        Rules(name: "bash", evidence: bashEvidence),
        Rules(name: "yaml", evidence: yamlEvidence),
    ]

    // MARK: Per-language signatures

    private static func pythonEvidence(_ content: [String], _ text: String) -> [String] {
        var found: [String] = []
        for line in content {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("def "), t.hasSuffix(":"), t.contains("(") { found.append("!def") }
            if t.hasPrefix("class "), t.hasSuffix(":") { found.append("!class") }
            if t.hasPrefix("if __name__") { found.append("!__main__") }
            if t.hasPrefix("from "), t.contains(" import ") { found.append("!from-import") }
            // `import numpy as np` is a spelling essentially unique to Python — and unlike a bare
            // `import x`, the `as` rules out the English verb.
            let words = t.split(separator: " ").map(String.init)
            if words.count == 4, words[0] == "import", words[2] == "as" { found.append("!import-as") }
            else if t.hasPrefix("import "), !t.contains(" from "), words.count <= 4,
                    !t.hasSuffix(";") { found.append("import") }
            // `df = pd.DataFrame(...)` — a name bound to a call on a module.
            if let equals = t.range(of: " = "), t[equals.upperBound...].contains("."),
               t.hasSuffix(")"), !t.hasSuffix(".") { found.append("call-assignment") }
            if t.hasPrefix("elif ") || t.hasPrefix("except") || t.hasPrefix("lambda ") { found.append("keyword") }
            if t.hasPrefix("print("), t.hasSuffix(")") { found.append("print") }
            if t.hasPrefix("return ") || t == "pass" { found.append("keyword") }
            // An indented body under a line ending in a colon — Python's whole shape.
            if line.hasPrefix("    "), t.contains("="), !t.hasSuffix(".") { found.append("indent") }
        }
        return Array(Set(found))
    }

    private static func sqlEvidence(_ content: [String], _ text: String) -> [String] {
        let upper = text.uppercased()
        var found: [String] = []
        // The pairs are what make it SQL; either word alone is an English word.
        for (a, b) in [("SELECT", "FROM"), ("INSERT", "INTO"), ("UPDATE", "SET"),
                       ("DELETE", "FROM"), ("CREATE TABLE", "("), ("ALTER TABLE", "")] {
            if upper.contains(a), b.isEmpty || upper.contains(b) { found.append("!\(a)") }
        }
        for word in ["INNER JOIN", "LEFT JOIN", "GROUP BY", "ORDER BY", "WHERE ", "HAVING "]
        where upper.contains(word) { found.append(word.trimmingCharacters(in: .whitespaces)) }
        return Array(Set(found))
    }

    private static func javascriptEvidence(_ content: [String], _ text: String) -> [String] {
        var found: [String] = []
        for line in content {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("function "), t.contains("(") { found.append("!function") }
            if t.contains("console.log(") { found.append("!console.log") }
            if t.contains("=> {") || t.contains("=>{") { found.append("!arrow") }
            if t.contains("require(") { found.append("!require") }
            if t.hasPrefix("const ") || t.hasPrefix("let ") || t.hasPrefix("var ") { found.append("declaration") }
            if t.hasPrefix("export ") || t.hasPrefix("module.exports") { found.append("export") }
            if t.hasSuffix(";") { found.append("semicolon") }
            if t == "}" || t == "};" { found.append("brace") }
        }
        return Array(Set(found))
    }

    private static func typescriptEvidence(_ content: [String], _ text: String) -> [String] {
        var found: [String] = []
        for line in content {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("interface "), t.contains("{") { found.append("!interface") }
            if t.hasPrefix("type "), t.contains("=") { found.append("!type-alias") }
            if t.contains(": string") || t.contains(": number") || t.contains(": boolean") {
                found.append("!annotation")
            }
            if t.hasPrefix("enum "), t.contains("{") { found.append("!enum") }
            if t.hasPrefix("import "), t.contains(" from ") { found.append("import") }
            if t.hasSuffix(";") { found.append("semicolon") }
        }
        return Array(Set(found))
    }

    private static func swiftEvidence(_ content: [String], _ text: String) -> [String] {
        var found: [String] = []
        for line in content {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("func "), t.contains("(") { found.append("!func") }
            if t.hasPrefix("guard let ") || t.hasPrefix("if let ") { found.append("!optional-binding") }
            if t.hasPrefix("struct "), t.contains("{") { found.append("!struct") }
            if t.hasPrefix("import Foundation") || t.hasPrefix("import UIKit")
                || t.hasPrefix("import SwiftUI") { found.append("!import") }
            if t.hasPrefix("@") { found.append("attribute") }
            if t.hasPrefix("let ") || t.hasPrefix("var ") { found.append("declaration") }
            if t == "}" { found.append("brace") }
        }
        return Array(Set(found))
    }

    /// JSON is the one language that can be *proved* rather than guessed: it either parses or it does
    /// not. Nothing shaped like a note parses as a JSON object.
    private static func jsonEvidence(_ content: [String], _ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6,
              (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
                || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")),
              let data = trimmed.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              parsed is [String: Any] || parsed is [Any]
        else { return [] }
        return ["!parses-as-json"]
    }

    private static func bashEvidence(_ content: [String], _ text: String) -> [String] {
        var found: [String] = []
        if content.first?.hasPrefix("#!") == true { found.append("!shebang") }
        for line in content {
            let t = line.trimmingCharacters(in: .whitespaces)
            for tool in ["git ", "npm ", "npx ", "yarn ", "brew ", "sudo ", "docker ", "kubectl ",
                         "curl ", "chmod ", "apt-get ", "pip install", "cargo "]
            where t.hasPrefix(tool) { found.append("!command") }
            if t.contains(" | grep ") || t.contains(" | awk ") || t.contains(" | sed ") {
                found.append("!pipeline")
            }
            if t.contains("$(") || t.contains("${") { found.append("substitution") }
            if t.contains(" && ") || t.hasPrefix("export ") { found.append("shell-op") }
            if t.hasPrefix("cd ") || t.hasPrefix("mkdir ") || t.hasPrefix("rm ") { found.append("command") }
        }
        return Array(Set(found))
    }

    /// The strictest of the eight, because a flat `key: value` list and `- item` are what an ordinary
    /// note looks like — and As Told already renders `- item` as the bulleted list the writer meant.
    /// Only a document marker or real nesting says YAML.
    private static func yamlEvidence(_ content: [String], _ text: String) -> [String] {
        var found: [String] = []
        if content.first?.trimmingCharacters(in: .whitespaces) == "---" { found.append("!document-marker") }

        // A key with nothing after it, followed by an indented key of its own: structure a note has no
        // reason to contain.
        for (index, line) in content.enumerated() where index + 1 < content.count {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasSuffix(":"), !t.hasPrefix("-"), t.count > 1 else { continue }
            let next = content[index + 1]
            let indent = next.prefix { $0 == " " }.count
            guard indent >= 2 else { continue }
            let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
            if nextTrimmed.contains(": ") || nextTrimmed.hasSuffix(":") { found.append("!nesting") }
        }
        return Array(Set(found))
    }
}
