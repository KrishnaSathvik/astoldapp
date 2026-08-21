import UIKit
import SwiftUI

/// A table, drawn as a table.
///
/// A real view sitting in the note's scroll, not a re-spacing of the source underneath it. The lines of
/// `body` this covers are hidden at the glyph layer and squeezed to the height of this card
/// (`StructuredTextStyler.reserveTableCards`), so what a reader sees is columns, a heading row, and quiet
/// separators — never `| Day | Date |`. How a note stores a table is implementation, and implementation
/// is not something a reader should have to decode.
///
/// Editorial, not spreadsheet (docs/03-design-system.md): no vertical rules, no boxed grid, no zebra
/// striping. The columns are separated by the space between them, which is how a printed table does it.
///
/// It draws rather than stacking labels because everything on it has already been measured by
/// `TableCardLayout`, and because a note can hold several tables. Accessibility is supplied explicitly:
/// one element per row, each cell spoken with the column it belongs to.
@MainActor
final class TableCardView: UIView {

    /// The design-system colours this is painted in, resolved by the view that owns it.
    struct Palette {
        var surface: UIColor
        var text: UIColor
        var secondaryText: UIColor
        var separator: UIColor
        var headerFill: UIColor
        var accent: UIColor
    }

    /// The lines of `body` this card stands in for — its identity while the note is on screen.
    let lineRange: ClosedRange<Int>
    private(set) var table: TableBlock
    private(set) var layout: TableCardLayout.Layout
    private var palette: Palette
    /// One empty view per row, carrying nothing but the row's VoiceOver label — see `rebuildAccessibility`.
    private var rows: [UIView] = []

    init(table: TableBlock, layout: TableCardLayout.Layout, palette: Palette) {
        self.lineRange = table.lineRange
        self.table = table
        self.layout = layout
        self.palette = palette
        super.init(frame: CGRect(origin: .zero, size: layout.size))
        backgroundColor = .clear
        // Touches belong to the page. The tap that opens the reader is the text view's own, resolved
        // through the glyphs underneath this — one gesture for the whole note rather than a second one
        // per table that has to be told to yield to it.
        isUserInteractionEnabled = false
        isOpaque = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (card: TableCardView, _) in
            card.setNeedsDisplay()
        }
        rebuildAccessibility()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Re-uses this card for the same table at a new size or in new colours — a Dynamic Type change, a
    /// rotation of the writing width, an edit somewhere else in the note.
    func update(table: TableBlock, layout: TableCardLayout.Layout, palette: Palette) {
        self.table = table
        self.layout = layout
        self.palette = palette
        setNeedsDisplay()
        rebuildAccessibility()
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        let card = UIBezierPath(roundedRect: bounds, cornerRadius: TableCardLayout.Metrics.corner)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        palette.surface.setFill()
        card.fill()
        card.addClip()

        // The heading row takes a tint rather than a rule, so the eye reads "these are labels" without
        // a line being drawn across the note.
        palette.headerFill.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: bounds.width, height: layout.headerHeight)).fill()

        draw(cells: layout.header, y: 0, height: layout.headerHeight,
             font: StructuredTextStyle.tableHeaderFont(), color: palette.text)

        var y = layout.headerHeight
        separator(at: y, width: bounds.width, strong: true)
        for row in layout.rows {
            draw(cells: row.cells, y: y, height: row.height,
                 font: StructuredTextStyle.bodyFont(), color: palette.text)
            y += row.height
            if row.height > 0, y < bounds.height - 0.5 { separator(at: y, width: bounds.width) }
        }

        if let footer = layout.footer {
            drawFooter(footer, y: y, height: layout.footerHeight, width: bounds.width)
        }
        context.restoreGState()

        palette.separator.setStroke()
        card.lineWidth = hairline
        card.stroke()
    }

    private var hairline: CGFloat { max(0.5, 1 / max(traitCollection.displayScale, 1)) }

    private func separator(at y: CGFloat, width: CGFloat, strong: Bool = false) {
        (strong ? palette.separator : palette.separator.withAlphaComponent(0.55)).setFill()
        UIBezierPath(rect: CGRect(x: 0, y: y - hairline / 2, width: width, height: hairline)).fill()
    }

    private func draw(cells: [String], y: CGFloat, height: CGFloat, font: UIFont, color: UIColor) {
        var x = TableCardLayout.Metrics.cardInsetH
        for (column, width) in layout.columnWidths.enumerated() {
            let value = column < cells.count ? cells[column] : ""
            if !value.isEmpty {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = column < layout.alignments.count ? layout.alignments[column] : .left
                // Only a preview truncates, and only because the whole table is one tap away. A full
                // table wraps: losing a word to an ellipsis is not something this app does.
                paragraph.lineBreakMode = layout.isPreview ? .byTruncatingTail : .byWordWrapping
                let rect = CGRect(x: x, y: y + TableCardLayout.Metrics.rowInsetV,
                                  width: width, height: height - TableCardLayout.Metrics.rowInsetV * 2)
                (value as NSString).draw(
                    with: rect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph],
                    context: nil
                )
            }
            x += width + TableCardLayout.Metrics.columnGap
        }
    }

    /// "9 rows · 7 columns" on one side, the way into the full grid on the other. Only a preview has
    /// one, because only a preview is holding something back.
    private func drawFooter(_ text: String, y: CGFloat, height: CGFloat, width: CGFloat) {
        separator(at: y, width: width)
        let font = StructuredTextStyle.tableFooterFont()
        let box = CGRect(x: TableCardLayout.Metrics.cardInsetH,
                         y: y + TableCardLayout.Metrics.rowInsetV,
                         width: width - TableCardLayout.Metrics.cardInsetH * 2,
                         height: height - TableCardLayout.Metrics.rowInsetV * 2)

        (text as NSString).draw(with: box, options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: [.font: font, .foregroundColor: palette.secondaryText],
                                context: nil)

        let action = NSMutableAttributedString(
            string: Self.openTitle,
            attributes: [.font: StructuredTextStyle.tableFooterFont(),
                         .foregroundColor: palette.accent]
        )
        let chevron = NSTextAttachment()
        chevron.image = UIImage(systemName: "chevron.right",
                                withConfiguration: UIImage.SymbolConfiguration(font: font))?
            .withTintColor(palette.accent, renderingMode: .alwaysOriginal)
        action.append(NSAttributedString(string: " "))
        action.append(NSAttributedString(attachment: chevron))

        let size = action.size()
        action.draw(at: CGPoint(x: box.maxX - ceil(size.width),
                                y: box.midY - size.height / 2))
    }

    static let openTitle = "View Table"

    // MARK: Accessibility

    /// One accessible row per row, as **real subviews**.
    ///
    /// Synthetic `UIAccessibilityElement`s under an `accessibilityElements` container did not survive
    /// the trip out of the text view this card lives inside — a `UITextView` is an accessibility element
    /// in its own right, and a container nested in one is not reliably walked (the same trap
    /// `NotePageHeaderView` documents for the title field). Empty views are, so the rows are views.
    ///
    /// A table read aloud is read *by row*: a cell without its heading is a word with the relationship
    /// stripped out of it, and that relationship is the entire content of a table.
    private func rebuildAccessibility() {
        rows.forEach { $0.removeFromSuperview() }
        rows = []

        if layout.isPreview {
            isAccessibilityElement = true
            accessibilityTraits = .button
            accessibilityLabel = "Table, \(table.records.count) rows, \(table.width) columns"
            accessibilityHint = "Opens the full table"
            return
        }

        isAccessibilityElement = false
        accessibilityTraits = .none
        accessibilityLabel = nil
        accessibilityHint = nil

        let headings = layout.header
        addRow(headings.filter { !$0.isEmpty }.joined(separator: ", "),
               y: 0, height: layout.headerHeight)

        var y = layout.headerHeight
        for row in layout.rows {
            let spoken = row.cells.enumerated().map { column, value -> String in
                let heading = column < headings.count ? headings[column] : ""
                let words = value.isEmpty ? "empty" : value
                return heading.isEmpty ? words : "\(heading), \(words)"
            }
            addRow(spoken.joined(separator: ", "), y: y, height: row.height)
            y += row.height
        }
    }

    private func addRow(_ label: String, y: CGFloat, height: CGFloat) {
        let row = UIView(frame: CGRect(x: 0, y: y, width: layout.size.width, height: height))
        row.backgroundColor = .clear
        row.isUserInteractionEnabled = false
        row.isAccessibilityElement = true
        row.accessibilityLabel = label
        addSubview(row)
        rows.append(row)
    }
}
