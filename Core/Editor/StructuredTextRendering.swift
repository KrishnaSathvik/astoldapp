import UIKit
import SwiftUI

// TextKit 1 rendering for the structured editor (R1a): the UITextView's backing store holds the raw
// source string (with markers) so native editing, IME/marked-text composition, and autocorrect keep
// working for Telugu/Hindi/code-switch input. Markers are *hidden* at the glyph layer and the visible
// list markers (•, 1., ☐/☑) are drawn in a left gutter. See docs/02-features.md (Milestone A) and
// RULES.md §1 (no formatting ribbon; structure must not dominate).

extension NSAttributedString.Key {
    /// Marks a marker-prefix range whose glyphs must be hidden (zero-width) by the layout manager.
    static let astHiddenMarker = NSAttributedString.Key("astHiddenMarker")
}

enum StructuredTextStyle {
    /// Left gutter width for lists; content and drawn markers align to this.
    static let listIndent: CGFloat = 28
    static let lineSpacing: CGFloat = 4

    static func bodyFont() -> UIFont { UIFont.preferredFont(forTextStyle: .body) }

    static func headingFont() -> UIFont { scaled(.title2, weight: .semibold) }

    static func subheadingFont() -> UIFont { scaled(.title3, weight: .semibold) }

    private static func scaled(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let descriptor = base.fontDescriptor.addingAttributes(
            [.traits: [UIFontDescriptor.TraitKey.weight: weight]]
        )
        return UIFont(descriptor: descriptor, size: 0)
    }

    static func isList(_ kind: BlockKind) -> Bool {
        switch kind {
        case .bullet, .numbered, .checklist: return true
        case .paragraph, .heading, .subheading: return false
        }
    }
}

/// Applies fonts, paragraph indentation, and the hidden-marker attribute to a text storage, driven by
/// the parsed source. Only attributes change — never the characters — so this is safe to run after every
/// edit without disturbing IME composition.
enum StructuredTextStyler {
    static func apply(to storage: NSTextStorage, textColor: UIColor) {
        let text = storage.string
        let doc = MarkupDocument(text)
        let full = NSRange(location: 0, length: (text as NSString).length)

        storage.beginEditing()
        storage.removeAttribute(.astHiddenMarker, range: full)

        for line in doc.lines {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = StructuredTextStyle.lineSpacing
            if StructuredTextStyle.isList(line.kind) {
                paragraph.firstLineHeadIndent = StructuredTextStyle.listIndent
                paragraph.headIndent = StructuredTextStyle.listIndent
            }

            let font: UIFont
            switch line.kind {
            case .heading: font = StructuredTextStyle.headingFont()
            case .subheading: font = StructuredTextStyle.subheadingFont()
            default: font = StructuredTextStyle.bodyFont()
            }

            storage.addAttributes(
                [.font: font, .paragraphStyle: paragraph, .foregroundColor: textColor],
                range: line.sourceRange
            )

            if line.markerLength > 0 {
                let markerRange = NSRange(location: line.sourceRange.location, length: line.markerLength)
                storage.addAttribute(.astHiddenMarker, value: true, range: markerRange)
            }
        }
        storage.endEditing()
    }
}

/// A layout manager that nulls the glyphs of hidden markers and draws the visible list markers.
final class StructuredLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    /// Accent used to fill a checked checkbox; set by the view so it matches the design system.
    var accentColor: UIColor = .label

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    // MARK: Hide marker glyphs (zero-width, not drawn)

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes: UnsafePointer<Int>,
                       font: UIFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        guard let storage = textStorage else {
            layoutManager.setGlyphs(glyphs, properties: props, characterIndexes: characterIndexes,
                                    font: font, forGlyphRange: glyphRange)
            return glyphRange.length
        }

        var newProps = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
        var changed = false
        for i in 0..<glyphRange.length {
            let charIndex = characterIndexes[i]
            if charIndex < storage.length,
               storage.attribute(.astHiddenMarker, at: charIndex, effectiveRange: nil) != nil {
                newProps[i] = .null
                changed = true
            }
        }
        guard changed else {
            layoutManager.setGlyphs(glyphs, properties: props, characterIndexes: characterIndexes,
                                    font: font, forGlyphRange: glyphRange)
            return glyphRange.length
        }
        newProps.withUnsafeBufferPointer { buffer in
            layoutManager.setGlyphs(glyphs, properties: buffer.baseAddress!, characterIndexes: characterIndexes,
                                    font: font, forGlyphRange: glyphRange)
        }
        return glyphRange.length
    }

    // MARK: Draw visible list markers in the gutter

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage else { return }
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let doc = MarkupDocument(storage.string)

        for line in doc.lines where StructuredTextStyle.isList(line.kind) {
            guard NSIntersectionRange(line.sourceRange, charRange).length > 0
                    || NSLocationInRange(line.sourceRange.location, charRange)
                    || (line.sourceRange.length == 0 && line.sourceRange.location == charRange.location)
            else { continue }

            // Anchor to the first *visible* content glyph — the marker glyphs are nulled, so anchoring
            // to them resolves to the previous line's fragment.
            let anchorChar = line.contentLength > 0 ? line.contentStart : line.sourceRange.location
            let glyphIndex = glyphIndexForCharacter(at: anchorChar)
            let used = lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let box = CGRect(x: origin.x,
                             y: origin.y + used.minY,
                             width: StructuredTextStyle.listIndent,
                             height: used.height)
            let color = (storage.attribute(.foregroundColor, at: anchorChar, effectiveRange: nil) as? UIColor) ?? .label
            drawMarker(for: line.kind, box: box, color: color)
        }
    }

    private func drawMarker(for kind: BlockKind, box: CGRect, color: UIColor) {
        let font = StructuredTextStyle.bodyFont()
        switch kind {
        case .bullet:
            drawText("•", font: font, color: color, box: box)
        case .numbered(let n):
            drawText("\(n).", font: font, color: color.withAlphaComponent(0.7), box: box)
        case .checklist(let checked):
            drawCheckbox(checked: checked, color: color, box: box)
        case .paragraph, .heading, .subheading:
            break
        }
    }

    private func drawText(_ string: String, font: UIFont, color: UIColor, box: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (string as NSString).size(withAttributes: attributes)
        let point = CGPoint(x: box.minX + 6, y: box.midY - size.height / 2)
        (string as NSString).draw(at: point, withAttributes: attributes)
    }

    private func drawCheckbox(checked: Bool, color: UIColor, box: CGRect) {
        let name = checked ? "checkmark.square.fill" : "square"
        let config = UIImage.SymbolConfiguration(font: StructuredTextStyle.bodyFont())
        guard let image = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(checked ? accentColor : color.withAlphaComponent(0.55), renderingMode: .alwaysOriginal)
        else { return }
        image.draw(at: CGPoint(x: box.minX + 2, y: box.midY - image.size.height / 2))
    }
}
