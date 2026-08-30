import UIKit

/// The geometry of a code block as it is *read* — how tall the card is, and how wide the code inside it
/// actually wants to be.
///
/// Separate from the drawing for the same reason `TableCardLayout` is: where things land is arithmetic
/// over measured text, and arithmetic is the part that has to hold at a width, at a Dynamic Type size,
/// and against a line nobody thought of. `CodeBlockView` only paints what this decides.
///
/// The one rule that shapes all of it: **code does not wrap.** A wrapped line of code is a different
/// line of code — indentation stops meaning anything and a long argument list becomes prose. So the
/// card is as wide as the page and the code scrolls sideways inside it, which is also the reason a code
/// block cannot simply be styled in place inside the note's own wrapping text view.
enum CodeCardLayout {

    enum Metrics {
        /// Air between the card's edge and the code.
        static let cardInsetH: CGFloat = 14
        static let cardInsetV: CGFloat = 12
        static let corner: CGFloat = 12
        /// Air above and below the card, so it reads as a block on the page and not as a run of text.
        static let blockMargin: CGFloat = 10
        /// The header carries the language name and Copy Code. It is present on every block, because
        /// Copy Code is the reason a reader taps a code block at all.
        static let headerHeight: CGFloat = 44
        static let lineSpacing: CGFloat = 2
    }

    /// Everything `CodeBlockView` needs to draw one block, and everything the styler needs to reserve
    /// room for it.
    struct Layout: Equatable {
        /// The card's own size on the page.
        var size: CGSize
        /// How wide the widest line of code is. Larger than `size.width` means it scrolls.
        var codeWidth: CGFloat
        var lineHeight: CGFloat
        var scrolls: Bool { codeWidth > size.width - Metrics.cardInsetH * 2 }

        /// The height the note reserves for this block: the card plus the air around it.
        var reservedHeight: CGFloat { size.height + Metrics.blockMargin * 2 }
    }

    /// The monospaced face code is set in. Dynamic Type applies — code is still someone's writing, and
    /// a reader who needs larger text needs it here too (RULES.md §4).
    static func font() -> UIFont {
        let body = UIFont.preferredFont(forTextStyle: .body)
        return UIFont.monospacedSystemFont(ofSize: body.pointSize * 0.92, weight: .regular)
    }

    /// One entry per code block in `source`, in the order they appear.
    static func layouts(in source: String, availableWidth: CGFloat) -> [(block: CodeBlock, layout: Layout)] {
        CodeBlock.blocks(in: source).compactMap { block in
            layout(for: block, availableWidth: availableWidth).map { (block, $0) }
        }
    }

    /// The layout for one block, or `nil` when there is no width to lay it out in yet.
    static func layout(for block: CodeBlock, availableWidth: CGFloat) -> Layout? {
        guard availableWidth > 0 else { return nil }

        let font = font()
        let lineHeight = (font.lineHeight + Metrics.lineSpacing).rounded(.up)
        // An empty fence still draws a card: the writer made a block, and a block that vanishes when
        // it holds nothing is a block that looks broken while it is being filled.
        let lines = max(1, block.codeLines.count)

        let widest = block.codeLines.reduce(CGFloat(0)) { widest, line in
            let width = (line as NSString)
                .size(withAttributes: [.font: font]).width
            return max(widest, width.rounded(.up))
        }

        let height = Metrics.headerHeight + Metrics.cardInsetV
            + CGFloat(lines) * lineHeight + Metrics.cardInsetV

        return Layout(size: CGSize(width: availableWidth, height: height.rounded(.up)),
                      codeWidth: widest,
                      lineHeight: lineHeight)
    }
}
