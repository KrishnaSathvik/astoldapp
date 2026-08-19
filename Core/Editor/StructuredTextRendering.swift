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

    /// Body size, heavier weight. Deliberately *not* a second large size: at `.title3` a subheading
    /// sat two points under a heading at the same weight, so the two structures were indistinguishable
    /// on the page and the choice between them meant nothing. Size carries "heading", weight carries
    /// "subheading", and the ladder reads 22-semibold / 17-semibold / 17-regular.
    static func subheadingFont() -> UIFont { UIFont.preferredFont(forTextStyle: .headline) }

    /// Space above a heading. A heading is a section break, and heavier type alone does not read as
    /// one when it is jammed against the paragraph above it. Derived from the body line height so it
    /// tracks Dynamic Type, and never applied to the first line, which has the page edge above it.
    static func spacingBefore(_ kind: BlockKind) -> CGFloat {
        switch kind {
        case .heading: return bodyFont().lineHeight * 0.75
        case .subheading: return bodyFont().lineHeight * 0.55
        case .paragraph, .bullet, .numbered, .checklist: return 0
        }
    }

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

        for (index, line) in doc.lines.enumerated() {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = StructuredTextStyle.lineSpacing
            if index > 0 {
                paragraph.paragraphSpacingBefore = StructuredTextStyle.spacingBefore(line.kind)
            }
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

/// A layout manager that hides the glyphs of source markers and draws the visible list markers.
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

    // MARK: Hide marker glyphs (zero advancement, not drawn)

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
                newProps[i] = .controlCharacter
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

    /// Marker glyphs are hidden by giving them *zero advancement*, not by nulling them.
    ///
    /// The distinction is the whole reason an empty list item is visible. A null glyph is ignored
    /// during layout, so a line holding nothing but its marker — exactly what Return produces, and
    /// what the Style menu produces on a blank line — laid out to no height at all: the caret stayed
    /// on the line above, no bullet/number/box appeared, and the marker drew itself over the item
    /// above. A zero-advancement control glyph still takes part in layout, so the line keeps its
    /// full height and its own fragment while the marker itself stays invisible.
    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldUse action: NSLayoutManager.ControlCharacterAction,
                       forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        guard let storage = textStorage, charIndex < storage.length,
              storage.attribute(.astHiddenMarker, at: charIndex, effectiveRange: nil) != nil
        else { return action }
        return .zeroAdvancement
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

            // Anchor to the line's own first character. Marker glyphs are zero-advancement control
            // glyphs rather than null ones, so they still belong to this line's fragment — which is
            // what lets an item that holds *only* a marker (the moment after Return) draw its marker
            // on its own line instead of over the item above it.
            let anchorChar = line.sourceRange.location
            let glyphIndex = glyphIndexForCharacter(at: anchorChar)
            let fragment = lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            // Align to the text *baseline*, not to the middle of the fragment: the fragment's height
            // carries this paragraph's line spacing below the text, so a centered marker rides that
            // low by half the leading. `location(forGlyphAt:)` is relative to the fragment origin and
            // its y is the baseline, so this stays correct at every Dynamic Type size.
            let baselineY = origin.y + fragment.minY + location(forGlyphAt: glyphIndex).y
            let color = (storage.attribute(.foregroundColor, at: anchorChar, effectiveRange: nil) as? UIColor) ?? .label
            drawMarker(for: line.kind, x: origin.x, baselineY: baselineY, color: color)
        }
    }

    private func drawMarker(for kind: BlockKind, x: CGFloat, baselineY: CGFloat, color: UIColor) {
        let font = StructuredTextStyle.bodyFont()
        switch kind {
        case .bullet:
            drawText("•", font: font, color: color, x: x, baselineY: baselineY)
        case .numbered(let n):
            drawText("\(n).", font: font, color: color.withAlphaComponent(0.7), x: x, baselineY: baselineY)
        case .checklist(let checked):
            drawCheckbox(checked: checked, color: color, x: x, baselineY: baselineY, font: font)
        case .paragraph, .heading, .subheading:
            break
        }
    }

    private func drawText(_ string: String, font: UIFont, color: UIColor, x: CGFloat, baselineY: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        // `draw(at:)` takes the text's top-left, so back off the ascender to land on the baseline.
        let point = CGPoint(x: x + 6, y: baselineY - font.ascender)
        (string as NSString).draw(at: point, withAttributes: attributes)
    }

    private func drawCheckbox(checked: Bool, color: UIColor, x: CGFloat, baselineY: CGFloat, font: UIFont) {
        let name = checked ? "checkmark.square.fill" : "square"
        let config = UIImage.SymbolConfiguration(font: font)
        guard let image = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(checked ? accentColor : color.withAlphaComponent(0.55), renderingMode: .alwaysOriginal)
        else { return }
        // Centred on the cap height rather than the fragment: a box optically sits with the letters
        // beside it, not with the leading underneath them.
        let centerY = baselineY - font.capHeight / 2
        image.draw(at: CGPoint(x: x + 2, y: centerY - image.size.height / 2))
    }
}
