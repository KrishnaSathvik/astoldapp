import SwiftUI
import UIKit

/// The chrome a note carries above its first line: the creation date and the optional title.
///
/// Deliberately **not** a subview of the text view. A `UITextView` is an accessibility element in its
/// own right, so a control nested inside one disappears from VoiceOver — and from the UI tests that
/// tap `Title`. Kept as a sibling it stays a real, reachable text field, and `NotePageView` is what
/// makes it travel with the text.
@MainActor
final class NotePageHeaderView: UIView {
    let dateLabel = UILabel()
    let titleField = UITextField()

    /// The gap between date and title, and between the title and the first line of body text —
    /// the spacing the SwiftUI `VStack` used to supply (docs/03-design-system.md §4.7).
    static let gap = DSSpacing.s3

    override init(frame: CGRect) {
        super.init(frame: frame)

        dateLabel.font = StructuredTextStyle.dateLabelFont()
        dateLabel.textColor = UIColor(Color.ds.textTertiary)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.numberOfLines = 1
        addSubview(dateLabel)

        titleField.font = StructuredTextStyle.editorTitleFont()
        titleField.textColor = UIColor(Color.ds.textPrimary)
        titleField.adjustsFontForContentSizeCategory = true
        titleField.borderStyle = .none          // "title has no box" (docs/03-design-system.md §4.7)
        titleField.backgroundColor = .clear
        titleField.returnKeyType = .done
        titleField.enablesReturnKeyAutomatically = false
        titleField.accessibilityIdentifier = "Title"
        setPlaceholder("Title")
        addSubview(titleField)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// The placeholder is attributed rather than plain because the design system's tertiary token —
    /// not UIKit's own placeholder grey — is what "Title" is written in.
    private func setPlaceholder(_ text: String) {
        titleField.attributedPlaceholder = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: UIColor(Color.ds.textTertiary)]
        )
    }

    /// Only the title field takes touches. Everything else in the header — the date, the empty space
    /// beside it — falls through to the text view underneath, so a drag that starts on the header
    /// still scrolls the page and a tap beside the date still puts the caret in the body.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        var y: CGFloat = 0
        if !dateLabel.isHidden {
            let height = fittingHeight(of: dateLabel, width: width)
            dateLabel.frame = CGRect(x: 0, y: y, width: width, height: height)
            y += height + Self.gap
        }
        titleField.frame = CGRect(x: 0, y: y, width: width, height: fittingHeight(of: titleField, width: width))
    }

    /// The height the header occupies at `width` — what the text view reserves above its first line.
    func height(forWidth width: CGFloat) -> CGFloat {
        var total = fittingHeight(of: titleField, width: width)
        if !dateLabel.isHidden { total += fittingHeight(of: dateLabel, width: width) + Self.gap }
        return total
    }

    private func fittingHeight(of view: UIView, width: CGFloat) -> CGFloat {
        ceil(view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }
}

/// One scrolling page: date, title, and body moving together.
///
/// The body text view is the **only** scroll view on the screen and it fills the page, so every
/// native behavior that depends on being the scroller — following the caret, lifting the line being
/// typed above the keyboard, interactive dismissal — is untouched. Room for the header is reserved
/// with the text view's own `textContainerInset.top`, and the header is repositioned from
/// `scrollViewDidScroll`, which runs inside the scroll's own layout pass.
///
/// The header used to sit *outside* the scroll, in the editor's `VStack`. That pinned the date and
/// title to the top of the screen while a long note slid past underneath them, clipped mid-line at
/// the body's top edge — the note stopped reading as one page (2026-08-20).
@MainActor
final class NotePageView: UIView {
    let textView: StructuredTextView
    let header = NotePageHeaderView()
    let placeholderLabel = UILabel()

    /// The text view's own inset above the first line, unchanged from before the header moved in.
    private static let bodyTopInset: CGFloat = 6

    init(textView: StructuredTextView) {
        self.textView = textView
        super.init(frame: .zero)
        // The header leaves the page at the top edge rather than drawing over the navigation bar.
        clipsToBounds = true
        addSubview(textView)
        addSubview(header)

        placeholderLabel.font = StructuredTextStyle.bodyFont()
        placeholderLabel.textColor = UIColor(Color.ds.textTertiary)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isUserInteractionEnabled = false
        placeholderLabel.accessibilityIdentifier = "Body placeholder"
        addSubview(placeholderLabel)

        // Date and title are set in the reader's text size, so the space reserved for them has to be
        // measured again when that size changes — the body already restyles itself for the same reason.
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (page: NotePageView, _) in
            page.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var dateText: String = "" {
        didSet {
            guard dateText != oldValue else { return }
            header.dateLabel.text = dateText
            header.dateLabel.isHidden = dateText.isEmpty
            setNeedsLayout()
        }
    }

    var placeholderText: String = "" {
        didSet {
            guard placeholderText != oldValue else { return }
            placeholderLabel.text = placeholderText
            setNeedsLayout()
        }
    }

    /// Shown only while the body is empty — the one line an empty note carries (RULES.md §7).
    func refreshPlaceholder() {
        placeholderLabel.isHidden = placeholderText.isEmpty || !textView.text.isEmpty
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds

        let width = bounds.width
        let headerHeight = header.height(forWidth: width)
        let bodyTop = headerHeight + NotePageHeaderView.gap + Self.bodyTopInset
        // Guarded: assigning the inset invalidates layout, so writing it unconditionally would loop.
        if textView.textContainerInset.top != bodyTop {
            textView.textContainerInset.top = bodyTop
        }

        header.frame = CGRect(x: 0, y: 0, width: width, height: headerHeight)
        placeholderLabel.frame = CGRect(
            x: 0, y: bodyTop, width: width,
            height: ceil(placeholderLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        )
        syncChromeToScroll()
    }

    /// Moves the header and the placeholder with the text.
    ///
    /// A point at content `y` is drawn at view `y - contentOffset.y`; the header owns content `0`, so
    /// this is the whole calculation, and it stays right under content insets and rubber-banding
    /// alike. Called from the scroll delegate so it lands in the same pass as the text it follows —
    /// pushing the offset through SwiftUI state instead would let the header lag the words by a frame.
    func syncChromeToScroll() {
        let offset = textView.contentOffset.y
        header.frame.origin.y = -offset
        placeholderLabel.frame.origin.y = textView.textContainerInset.top - offset
    }
}
