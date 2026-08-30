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

    // MARK: Editing a cell in place (Item 4)
    //
    // A table stays a table while it is edited (RULES.md §7, amended 2026-08-24). The pipes and the
    // header rule are storage and are never drawn, so the grid cannot be edited as text the way a code
    // block can — a text view lays out lines, and a table is not lines. Instead the card itself takes
    // the edit: one field, over one cell, at a time.
    //
    // What this is not, and must not become: a spreadsheet. No row/column insertion, no resizing, no
    // sorting, no formulas, no merged cells, no multiline cells (§7 is unchanged).

    /// The cell being edited, when one is.
    private(set) var editingCell: TableBlock.CellPosition?
    /// The field over that cell. One, re-used — a field per cell would be a grid of text views.
    private lazy var cellField: UITextField = {
        let field = UITextField()
        field.borderStyle = .none
        field.autocorrectionType = .no
        field.autocapitalizationType = .sentences
        field.returnKeyType = .next
        field.delegate = self
        field.adjustsFontForContentSizeCategory = true
        field.isHidden = true
        return field
    }()

    /// Called with the cell and its new text when an edit commits. The owner turns it into a
    /// `TextEdit` against `body` — the card never writes to the note itself.
    var onCommit: ((TableBlock.CellPosition, String) -> Void)?
    /// Called when editing leaves the table entirely, so the page can put the keyboard away.
    var onEndEditing: (() -> Void)?

    init(table: TableBlock, layout: TableCardLayout.Layout, palette: Palette) {
        self.lineRange = table.lineRange
        self.table = table
        self.layout = layout
        self.palette = palette
        super.init(frame: CGRect(origin: .zero, size: layout.size))
        backgroundColor = .clear
        // The card takes its own touches now: a tap has to resolve to a *cell*, which is a question
        // only this view can answer. Before Item 4 it passed everything through to the text view,
        // because the only thing a tap could mean was "put the caret in the source" — and there is no
        // longer any source on screen to put it in.
        isUserInteractionEnabled = true
        addSubview(cellField)
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
        if editingCell != nil { positionCellField() }
    }

    // MARK: Cell editing

    /// Starts editing `position`, committing whatever cell was open before it.
    @discardableResult
    func beginEditing(_ position: TableBlock.CellPosition) -> Bool {
        guard !layout.isPreview,                       // a preview holds rows back; the reader owns those
              layout.cellFrame(row: position.row, column: position.column) != nil,
              let value = table.cell(at: position)
        else { return false }

        if let open = editingCell, open != position { commitActiveCellIfNeeded() }
        editingCell = position
        cellField.text = value
        cellField.font = position.row == 0 ? StructuredTextStyle.tableHeaderFont()
                                           : StructuredTextStyle.bodyFont()
        cellField.textColor = palette.text
        cellField.tintColor = palette.accent
        cellField.textAlignment = position.column < layout.alignments.count
            ? layout.alignments[position.column] : .left
        cellField.isHidden = false
        positionCellField()
        setNeedsDisplay()                              // the cell's own drawn text steps aside
        cellField.becomeFirstResponder()
        return true
    }

    /// Ends the editing session and puts the field away. **It always commits** (2026-08-27).
    ///
    /// This took a `commit: Bool` and defaulted to `true`, and the one caller that passed `false` —
    /// ordinary card retirement inside `TableCardPresenter.sync` — meant that scrolling could silently
    /// throw away what somebody had typed. The flag is gone rather than corrected, because the rule it
    /// was expressing does not exist: **a table has no Cancel**, so there is no exit from a cell that
    /// is supposed to discard. A future Cancel would be its own method, not a `false` passed in here.
    ///
    /// Safe to call repeatedly: the commit is idempotent and the teardown is guarded on the field.
    func endEditing() {
        commitActiveCellIfNeeded()
        editingCell = nil
        guard !cellField.isHidden else { return }
        cellField.isHidden = true
        cellField.resignFirstResponder()
        setNeedsDisplay()
    }

    /// Hands the open cell's text to the note, once, if it changed. **The** commit — every exit routes
    /// through here so none of them can invent its own semantics.
    ///
    /// Idempotent by construction: it clears `editingCell` before returning, so the second caller in a
    /// sequence finds no session open and does nothing. That matters because the paths overlap —
    /// Return commits and *then* the field resigns, which calls `textFieldDidEndEditing`, which would
    /// otherwise commit the same text a second time and put two entries in the undo stack for one edit.
    ///
    /// One session is one `onCommit`, which the editor turns into one ordinary undoable `TextEdit`:
    /// typing `F`, `Fa`, `Fai`, `Fair`, `Fairbanks` in a cell is *one* step back to the original value,
    /// because the keystrokes live in this field and only the result ever reaches `body`.
    @discardableResult
    func commitActiveCellIfNeeded() -> Bool {
        guard let position = editingCell else { return false }
        let text = cellField.text ?? ""
        editingCell = nil                                        // the session is over from here on
        guard text != table.cell(at: position) else { return false }  // nothing typed, nothing to undo
        onCommit?(position, text)
        return true
    }

    private func positionCellField() {
        guard let position = editingCell,
              let frame = layout.cellFrame(row: position.row, column: position.column) else { return }
        cellField.frame = frame.insetBy(dx: 0, dy: TableCardLayout.Metrics.rowInsetV)
    }

    /// Moves to the next or previous cell, committing this one. Leaving the table's last cell ends
    /// editing rather than wrapping round to the first — a table is not a loop.
    private func move(forward: Bool) {
        guard let position = editingCell else { return }
        commitActiveCellIfNeeded()
        // The table this card holds is refreshed by `update` as the commit travels back through the
        // note, so navigation is computed from the position rather than from a stale copy of the rows.
        let next = forward ? table.cellAfter(position) : table.cellBefore(position)
        guard let next, beginEditing(next) else {
            endEditing()          // already committed just above; this is the idempotent teardown
            onEndEditing?()
            return
        }
    }

    // MARK: Touches

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // A preview card holds rows back and belongs to the reader, exactly as it did before — its
        // touches go to the page so the tap that opens the full grid still works.
        guard !layout.isPreview else { return nil }
        return super.hitTest(point, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let point = touches.first?.location(in: self) else { return }
        if let cell = layout.cell(at: point) {
            beginEditing(cell)
        } else {
            // The gaps between columns, and the footer: a tap on the table but not on a cell commits
            // what is open and stays put, rather than guessing at a neighbour.
            endEditing()
        }
    }

    /// Whether this card is showing a field the keyboard belongs to.
    var isEditingACell: Bool { editingCell != nil }

    // MARK: Driving the field from a test
    //
    // The field is private because nothing outside this view has any business writing into it. A test
    // still has to be able to type into a cell and press Return, so these two do exactly what the
    // keyboard does and nothing else.

    func setCellTextForTesting(_ text: String) { cellField.text = text }
    func advanceForTesting(forward: Bool = true) { move(forward: forward) }

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

    /// Which row starts at `y` — the drawing pass knows its offset but not its index.
    private func rowIndex(ofY y: CGFloat) -> Int? {
        for row in 0..<(1 + layout.rows.count) where layout.rowTop(row).map({ abs($0 - y) < 0.5 }) == true {
            return row
        }
        return nil
    }

    private func draw(cells: [String], y: CGFloat, height: CGFloat, font: UIFont, color: UIColor) {
        var x = TableCardLayout.Metrics.cardInsetH
        for (column, width) in layout.columnWidths.enumerated() {
            let value = column < cells.count ? cells[column] : ""
            // The cell with the field over it draws nothing: the field is showing those characters,
            // and drawing them again underneath shows every one of them twice.
            let isBeingEdited = editingCell.map { $0.column == column && rowIndex(ofY: y) == $0.row } ?? false
            if !value.isEmpty, !isBeingEdited {
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


// MARK: - The field's own keys

extension TableCardView: UITextFieldDelegate {

    /// Return commits and moves on: A1 → B1 → C1 → A2, the order the table reads in.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        move(forward: true)
        return false
    }

    /// Losing focus commits (added 2026-08-27). This is the path that used to lose text: tapping the
    /// note's title, tapping into the body, or the editor being torn down all resign the field, and
    /// nothing was listening — so the characters sat in a `UITextField` that was about to be discarded
    /// while autosave faithfully persisted a note that had never received them.
    ///
    /// Deliberately does **not** call `endEditing()`: this *is* the resignation, and re-entering
    /// teardown from inside the delegate callback is how that turns into recursion. It commits and puts
    /// the field away, and leaves resigning to whoever already did it.
    func textFieldDidEndEditing(_ textField: UITextField) {
        commitActiveCellIfNeeded()
        editingCell = nil
        guard !cellField.isHidden else { return }
        cellField.isHidden = true
        setNeedsDisplay()
    }

    /// A hardware Tab walks the same order, and Shift-Tab walks back. Nothing else is bound: this is a
    /// note that holds a table, not a spreadsheet.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard editingCell != nil, let key = presses.first?.key, key.keyCode == .keyboardTab else {
            super.pressesBegan(presses, with: event)
            return
        }
        move(forward: !key.modifierFlags.contains(.shift))
    }
}
