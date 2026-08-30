import Testing
import Foundation
import UIKit
@testable import Yourly

/// What leaves As Told on the pasteboard, byte for byte.
///
/// The bug this pins was reported from a real device: an em dash copied out of a note arrived in the
/// receiving app as "â€”", an arrow as "â†’", a curly apostrophe as "â€™". Those are not random — they
/// are exactly the UTF-8 bytes of those characters read back as a legacy single-byte encoding, which
/// is what an app does with HTML that never says what encoding it is in. The note's words are the one
/// thing a copy owes the writer (RULES.md §2, §5).
struct ClipboardEncodingTests {

    /// Punctuation a keyboard produces, an arrow, and two of the scripts As Told is built for.
    private let samples = [
        "I'm building — this → that",
        "I’m testing – everything",
        "తెలుగు",
        "हिन्दी",
        "café — naïve · “quoted” … 50°",
    ]

    // MARK: The declaration itself

    @Test func theHTMLFlavorSaysWhatEncodingItIs() {
        let source = "See [the docs](https://astold.app) — now"
        let html = StructuredTextExport.html(from: source,
                                             range: NSRange(location: 0, length: (source as NSString).length))
        #expect(html?.lowercased().contains("charset=\"utf-8\"") == true,
                "the HTML flavor declared no encoding, so a receiving app must guess")
    }

    // MARK: Round trips

    /// The exact trip a real copy/paste makes: our HTML out, UTF-8 bytes on the pasteboard, our
    /// importer back in.
    private func roundTripped(_ source: String) -> String? {
        let range = NSRange(location: 0, length: (source as NSString).length)
        guard let html = StructuredTextExport.html(from: source, range: range) else { return nil }
        let bytes = Data(html.utf8)
        guard let decoded = String(data: bytes, encoding: .utf8) else { return nil }
        return RichPasteHTML.source(from: decoded)
    }

    @Test func everyCharacterSurvivesTheRichFlavor() {
        for sample in samples {
            let source = "\(sample) [link](https://astold.app)"
            let out = roundTripped(source) ?? ""
            #expect(out.contains(sample), "\(sample) did not survive the HTML flavor — got \(out)")
        }
    }

    @Test func everyCharacterSurvivesThePlainFlavor() {
        for sample in samples {
            let range = NSRange(location: 0, length: (sample as NSString).length)
            let plain = StructuredTextExport.plainText(from: sample, range: range)
            #expect(plain == sample, "\(sample) came back as \(plain)")
            // …and as the bytes the pasteboard actually carries.
            #expect(String(data: Data(plain.utf8), encoding: .utf8) == sample)
        }
    }

    @Test func everyCharacterSurvivesTheInternalFlavor() {
        for sample in samples {
            let source = "# \(sample)"
            let range = NSRange(location: 0, length: (source as NSString).length)
            guard let structured = StructuredTextExport.structuredText(from: source, range: range) else {
                Issue.record("no internal flavor for \(sample)")
                continue
            }
            // Exactly how the pasteboard stores and reads it back (`writeSelectionToPasteboard`).
            #expect(String(data: Data(structured.utf8), encoding: .utf8) == structured)
            #expect(structured.contains(sample))
        }
    }

    @Test func noneOfItArrivesAsMojibake() {
        // The literal symptom, asserted as a symptom: the marker sequences that appear when UTF-8 is
        // read as a single-byte encoding must not be present in anything we emit.
        for sample in samples {
            let source = "\(sample) [x](https://astold.app)"
            let range = NSRange(location: 0, length: (source as NSString).length)
            let flavors = [StructuredTextExport.html(from: source, range: range) ?? "",
                           StructuredTextExport.plainText(from: source, range: range),
                           StructuredTextExport.structuredText(from: source, range: range) ?? ""]
            for flavor in flavors {
                for garbage in ["â€", "â†", "Ã¢", "Â "] {
                    #expect(!flavor.contains(garbage), "\(garbage) leaked into a flavor for \(sample)")
                }
            }
        }
    }

    @Test func aNonASCIILabelKeepsItsLinkAndItsCharacters() {
        let source = "[తెలుగు — docs](https://astold.app)"
        let out = roundTripped(source) ?? ""
        let doc = MarkupDocument(out)
        #expect(doc.links.first?.destination == "https://astold.app")
        #expect(doc.visibleText() == "తెలుగు — docs")
    }

    @Test func codeKeepsItsCharactersThroughTheRichFlavor() {
        // `<pre>` plus escaping plus a declared charset: three things that each have to hold.
        let source = "See [x](https://astold.app)\n```python\nprint(\"— → ’ తెలుగు\")\nif a < b & c > d:\n    pass\n```"
        let out = roundTripped(source) ?? ""
        let block = CodeBlock.blocks(in: out).first
        #expect(block?.codeLines.first == "print(\"— → ’ తెలుగు\")")
        #expect(block?.codeLines.contains("if a < b & c > d:") == true)
    }
}
