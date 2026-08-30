import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Yourly

// Syntax colour, on the terms it was admitted (RULES.md §7, amended 2026-08-24): only inside a
// rendered card, only for a language the source declared, only as colour, and never at the cost of
// being able to read the thing.

struct CodeHighlightingLanguageTests {

    @Test func aDeclaredLanguageIsFound() {
        #expect(CodeHighlighting.language(named: "sql")?.displayName == "SQL")
        #expect(CodeHighlighting.language(named: "Python")?.displayName == "Python")
        #expect(CodeHighlighting.language(named: "  swift  ")?.displayName == "Swift")
    }

    @Test func commonSpellingsOfTheSameLanguageAgree() {
        #expect(CodeHighlighting.language(named: "js")?.displayName == "JavaScript")
        #expect(CodeHighlighting.language(named: "ts")?.displayName == "TypeScript")
        #expect(CodeHighlighting.language(named: "py")?.displayName == "Python")
        #expect(CodeHighlighting.language(named: "zsh")?.displayName == "Bash")
        #expect(CodeHighlighting.language(named: "yml")?.displayName == "YAML")
    }

    @Test func anUndeclaredLanguageIsNeverGuessed() {
        // The whole discipline in one test: this *is* SQL, and nobody said so, so it is not coloured.
        #expect(CodeHighlighting.language(named: nil) == nil)
        #expect(CodeHighlighting.language(named: "") == nil)
        #expect(CodeHighlighting.language(named: "   ") == nil)
    }

    @Test func aLanguageThisDoesNotKnowIsNotColoured() {
        #expect(CodeHighlighting.language(named: "sqlite") == nil)
        #expect(CodeHighlighting.language(named: "cobol") == nil)
        #expect(CodeHighlighting.language(named: "ascii-diagram") == nil)
    }

    @Test func anUnknownButStatedLanguageStillNamesItself() {
        // Colouring it would be guessing; *saying* what the fence said is not. The label is the
        // source's word, trimmed, never expanded.
        #expect(CodeHighlighting.displayName(for: "sqlite") == "sqlite")
        #expect(CodeHighlighting.displayName(for: " rust ") == "rust")
        #expect(CodeHighlighting.displayName(for: "sql") == "SQL")
    }

    @Test func noLanguageMeansNoLabelAtAll() {
        // Never "Plain text", never "Code" — a label nobody stated is a guess with a quiet voice.
        #expect(CodeHighlighting.displayName(for: nil) == nil)
        #expect(CodeHighlighting.displayName(for: "  ") == nil)
    }
}

struct CodeHighlightingScannerTests {

    private func spans(_ code: String, _ named: String) -> [CodeHighlighting.Span] {
        guard let language = CodeHighlighting.language(named: named) else {
            Issue.record("\(named) should be a known language")
            return []
        }
        return CodeHighlighting.spans(in: code, language: language)
    }

    private func tokens(_ code: String, _ named: String) -> [(String, CodeHighlighting.Token)] {
        let ns = code as NSString
        return spans(code, named).map { (ns.substring(with: $0.range), $0.token) }
    }

    @Test func sqlKeywordsAreKeywordsInAnyCase() {
        // SQL is written both ways with equal authority, so both are keywords.
        let found = tokens("SELECT x from t", "sql")
        #expect(found.contains { $0 == ("SELECT", .keyword) })
        #expect(found.contains { $0 == ("from", .keyword) })
    }

    @Test func theSQLThatStartedThis() {
        let code = "SELECT managerId\nFROM Employee\nGROUP BY managerId\nHAVING COUNT(*) >= 5;"
        let found = tokens(code, "sql")
        #expect(found.contains { $0 == ("SELECT", .keyword) })
        #expect(found.contains { $0 == ("GROUP", .keyword) })
        #expect(found.contains { $0 == ("HAVING", .keyword) })
        #expect(found.contains { $0 == ("COUNT", .type) })      // a name being called
        #expect(found.contains { $0 == ("5", .number) })
        // `managerId` and `Employee` are the writer's own names and stay the card's text colour.
        #expect(!found.contains { $0.0 == "managerId" })
        #expect(!found.contains { $0.0 == "Employee" })
    }

    @Test func aCommentSwallowsWhatIsInsideIt() {
        // Including code someone commented out: a keyword in a comment is comment.
        let found = tokens("SELECT 1 -- SELECT 2\nFROM t", "sql")
        #expect(found.contains { $0 == ("-- SELECT 2", .comment) })
        #expect(found.filter { $0.1 == .keyword }.map(\.0) == ["SELECT", "FROM"])
    }

    @Test func aStringSwallowsWhatIsInsideIt() {
        let found = tokens("WHERE name = 'from -- not a comment'", "sql")
        #expect(found.contains { $0 == ("'from -- not a comment'", .string) })
        #expect(!found.contains { $0.0 == "from" })
    }

    @Test func anUnterminatedStringStopsAtItsLine() {
        // A half-typed quote must not turn the rest of the snippet into one colour.
        let found = tokens("x = 'oops\nSELECT 1", "sql")
        #expect(found.contains { $0 == ("'oops", .string) })
        #expect(found.contains { $0 == ("SELECT", .keyword) })
    }

    @Test func blockCommentsCloseAndAnUnclosedOneEndsAtTheEnd() {
        #expect(tokens("/* note */ SELECT 1", "sql").first?.0 == "/* note */")
        #expect(tokens("/* never closed", "sql").map(\.1) == [.comment])
    }

    @Test func aNumberInsideANameIsPartOfTheName() {
        let found = tokens("let utf8Data1 = 42", "swift")
        #expect(found.contains { $0 == ("42", .number) })
        #expect(!found.contains { $0.0 == "8" || $0.0 == "1" })
    }

    @Test func pythonCommentsAndStringsAndCalls() {
        let found = tokens("# setup\ndef run(x):\n    return len(\"ok\")", "python")
        #expect(found.contains { $0 == ("# setup", .comment) })
        #expect(found.contains { $0 == ("def", .keyword) })
        #expect(found.contains { $0 == ("run", .type) })
        #expect(found.contains { $0 == ("\"ok\"", .string) })
    }

    @Test func swiftCapitalisedNamesReadAsTypes() {
        let found = tokens("let note: Note = Note()", "swift")
        #expect(found.contains { $0 == ("let", .keyword) })
        #expect(found.filter { $0.0 == "Note" }.allSatisfy { $0.1 == .type })
    }

    @Test func bashColoursSyntaxAndNotSomebodysCommands() {
        // `echo` is a program on their machine, not a word this file has an opinion about.
        let found = tokens("if true; then echo \"hi\"; fi", "bash")
        #expect(found.contains { $0 == ("if", .keyword) })
        #expect(found.contains { $0 == ("fi", .keyword) })
        #expect(!found.contains { $0.0 == "echo" })
    }

    @Test func jsonHasThreeWordsAndNoGrammarOfItsOwn() {
        let found = tokens("{\"on\": true, \"n\": 3}", "json")
        #expect(found.contains { $0 == ("true", .keyword) })
        #expect(found.contains { $0 == ("3", .number) })
        #expect(found.contains { $0 == ("\"on\"", .string) })
        // "on" is a YAML keyword and a JSON key. Inside a string it is neither.
        #expect(!found.contains { $0.0 == "on" })
    }

    @Test func spansNeverOverlapAndStayInsideTheCode() {
        let code = "-- head\nSELECT 'a', 12 FROM t /* tail */"
        let found = spans(code, "sql")
        let length = (code as NSString).length
        for span in found { #expect(NSMaxRange(span.range) <= length) }
        for (a, b) in zip(found, found.dropFirst()) {
            #expect(a.range.location + a.range.length <= b.range.location)
        }
    }

    @Test func scanningNeverChangesTheCode() {
        // It reports ranges. It has no way to write, and this is the test that says so out loud.
        let code = "SELECT 'x' -- 1\nFROM t"
        let before = code
        _ = spans(code, "sql")
        #expect(code == before)
    }

    @Test func textThatIsNotCodeIsLeftAlone() {
        // An ASCII diagram declared as nothing gets no language, and so no spans. Declared as `text`
        // it is still no language this knows.
        #expect(CodeHighlighting.language(named: "text") == nil)
        #expect(CodeHighlighting.language(named: nil) == nil)
    }
}

/// The card: what is drawn, what is copied, and whether it can be read.
@MainActor
struct CodeCardHighlightingTests {

    private func card(_ code: String, language: String?) -> CodeBlockView {
        let block = CodeBlock(language: language, lineRange: 0...2, codeLines: code.components(separatedBy: "\n"))
        guard let layout = CodeCardLayout.layout(for: block, availableWidth: 353) else {
            Issue.record("353pt is a width; the layout should exist")
            return CodeBlockView(block: block,
                                 layout: CodeCardLayout.layout(for: block, availableWidth: 1)!,
                                 palette: .ds)
        }
        let view = CodeBlockView(block: block, layout: layout, palette: .ds)
        view.frame = CGRect(origin: .zero, size: layout.size)
        view.layoutIfNeeded()
        return view
    }

    private func drawnColours(_ view: CodeBlockView) -> [(String, UIColor)] {
        guard let attributed = view.drawnCode else { return [] }
        var out: [(String, UIColor)] = []
        let full = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.foregroundColor, in: full) { value, range, _ in
            guard let colour = value as? UIColor else { return }
            out.append(((attributed.string as NSString).substring(with: range), colour))
        }
        return out
    }

    @Test func adeclaredLanguageIsDrawnInMoreThanOneColour() {
        let colours = drawnColours(card("SELECT 1 FROM t", language: "sql"))
        #expect(Set(colours.map(\.1)).count > 1)
    }

    @Test func anUndeclaredBlockIsDrawnInExactlyOne() {
        // Identical characters, no fence language: one colour, exactly as before this shipped.
        let colours = drawnColours(card("SELECT 1 FROM t", language: nil))
        #expect(Set(colours.map(\.1)).count == 1)
    }

    @Test func anUnknownLanguageIsDrawnInExactlyOne() {
        let colours = drawnColours(card("SELECT 1 FROM t", language: "sqlite"))
        #expect(Set(colours.map(\.1)).count == 1)
    }

    @Test func colouringNeverChangesTheCharacters() {
        let code = "SELECT 'x' -- note\nFROM t"
        #expect(card(code, language: "sql").drawnCode?.string == code)
    }

    @Test func copyCodeCopiesTheCodeAndNotWhatIsDrawn() {
        // Colour is presentation; the pasteboard gets the characters, with no fences and no styling.
        let code = "SELECT 1\nFROM t"
        let view = card(code, language: "sql")
        UIPasteboard.general.string = ""
        view.copyCode()
        #expect(UIPasteboard.general.string == code)
        #expect(UIPasteboard.general.string?.contains("```") == false)
    }

    @Test func theLabelSaysWhatTheSourceSaid() {
        #expect(card("x", language: "sql").drawnLanguage == "SQL")
        #expect(card("x", language: "python").drawnLanguage == "Python")
        #expect(card("x", language: "sqlite").drawnLanguage == "sqlite")
    }

    @Test func noLanguageMeansNoLabel() {
        #expect(card("x", language: nil).drawnLanguage == nil)
    }

    @Test func aScreenReaderIsToldItIsCodeBeforeItIsReadTheCode() {
        #expect(card("x", language: "sql").drawnCodeAccessibilityLabel == "Code block, SQL")
        #expect(card("x", language: nil).drawnCodeAccessibilityLabel == "Code block")
    }
}

/// Every token has to be readable on the ground it is read on.
@MainActor
struct CodeTokenContrastTests {

    private func luminance(_ colour: UIColor, _ style: UIUserInterfaceStyle) -> CGFloat {
        let resolved = colour.resolvedColor(with: UITraitCollection { $0.userInterfaceStyle = style })
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    private func contrast(_ a: UIColor, _ b: UIColor, _ style: UIUserInterfaceStyle) -> CGFloat {
        let (x, y) = (luminance(a, style), luminance(b, style))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func everyTokenClearsTheFloorAgainstTheCodeSurface(style: UIUserInterfaceStyle) {
        // 4.5:1 is what every glyph in this app clears, and a syntax colour is not exempt for looking
        // like an IDE. The ground is `codeSurface` — the card's own — not the canvas beside it.
        let surface = UIColor(Color.ds.codeSurface)
        let palette = CodeBlockView.Palette.ds
        for token in CodeHighlighting.Token.allCases {
            guard let colour = palette.tokens[token] else {
                Issue.record("no colour for \(token)")
                continue
            }
            let ratio = contrast(colour, surface, style)
            #expect(ratio >= 4.5, "\(token) is \(ratio):1 on the code surface in \(style.rawValue)")
        }
    }

    /// CIE L\*a\*b\*, because telling two colours apart is not the same question as reading text on a
    /// ground. Contrast ratio is a *lightness* measure: two tokens can differ in hue while sitting at
    /// nearly the same lightness — which is exactly what a palette wants, so that no token shouts —
    /// and a ratio test calls that a failure. Perceptual distance is the honest measure here.
    private func lab(_ colour: UIColor, _ style: UIUserInterfaceStyle) -> (CGFloat, CGFloat, CGFloat) {
        let resolved = colour.resolvedColor(with: UITraitCollection { $0.userInterfaceStyle = style })
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ v: CGFloat) -> CGFloat { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let (lr, lg, lb) = (linear(r), linear(g), linear(b))
        let x = (0.4124 * lr + 0.3576 * lg + 0.1805 * lb) / 0.95047
        let y = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
        let z = (0.0193 * lr + 0.1192 * lg + 0.9505 * lb) / 1.08883
        func f(_ t: CGFloat) -> CGFloat { t > 0.008856 ? pow(t, 1.0 / 3.0) : 7.787 * t + 16.0 / 116.0 }
        let (fx, fy, fz) = (f(x), f(y), f(z))
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    private func difference(_ a: UIColor, _ b: UIColor, _ style: UIUserInterfaceStyle) -> CGFloat {
        let (l1, a1, b1) = lab(a, style)
        let (l2, a2, b2) = lab(b, style)
        return sqrt(pow(l1 - l2, 2) + pow(a1 - a2, 2) + pow(b1 - b2, 2))
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func theTokensAreTellableApartFromEachOther(style: UIUserInterfaceStyle) {
        // Five colours that all clear the floor but read as the same colour would be decoration, not
        // information. ΔE 20 is comfortably past "these are different colours"; the closest pair here
        // is string against comment, at 26 in Light and 28 in Dark.
        let palette = CodeBlockView.Palette.ds
        let tokens = CodeHighlighting.Token.allCases
        for (index, token) in tokens.enumerated() {
            for other in tokens[(index + 1)...] {
                guard let a = palette.tokens[token], let b = palette.tokens[other] else { continue }
                let delta = difference(a, b, style)
                #expect(delta >= 20, "\(token) and \(other) are ΔE \(delta) apart")
            }
        }
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func aCommentRecedesWithoutDisappearing(style: UIUserInterfaceStyle) {
        // The quietest token by design, and still above the floor. This is the one that goes wrong in
        // every theme that has ever shipped grey-on-grey comments.
        let palette = CodeBlockView.Palette.ds
        let surface = UIColor(Color.ds.codeSurface)
        let comment = palette.tokens[.comment]!
        let keyword = palette.tokens[.keyword]!
        #expect(contrast(comment, surface, style) >= 4.5)
        #expect(contrast(comment, surface, style) < contrast(keyword, surface, style))
    }
}
