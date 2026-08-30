import SwiftUI
import UIKit

/// The chrome a note carries above its first line: the optional title.
///
/// The **date used to live here too**, and moved to the navigation bar on 2026-08-26 when the header
/// gained Share — see `EditorView`. It is drawn in exactly one place, so nothing on this page has to
/// stay in step with it.
///
/// Deliberately **not** a subview of the text view. A `UITextView` is an accessibility element in its
/// own right, so a control nested inside one disappears from VoiceOver — and from the UI tests that
/// tap `Title`. Kept as a sibling it stays a real, reachable text field, and `NotePageView` is what
/// makes it travel with the text.
@MainActor
final class NotePageHeaderView: UIView {
    let titleField = UITextField()

    /// The gap between the title and the first line of body text — the spacing the SwiftUI `VStack`
    /// used to supply (docs/03-design-system.md §4.7).
    static let gap = DSSpacing.s3

    override init(frame: CGRect) {
        super.init(frame: frame)

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
        titleField.frame = CGRect(x: 0, y: 0, width: width,
                                  height: fittingHeight(of: titleField, width: width))
    }

    /// The height the header occupies at `width` — what the text view reserves above its first line.
    func height(forWidth width: CGFloat) -> CGFloat {
        fittingHeight(of: titleField, width: width)
    }

    private func fittingHeight(of view: UIView, width: CGFloat) -> CGFloat {
        ceil(view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }
}

/// One scrolling page: title and body moving together.
///
/// The body text view is the **only** scroll view on the screen and it fills the page, so every
/// native behavior that depends on being the scroller — following the caret, lifting the line being
/// typed above the keyboard, interactive dismissal — is untouched. Room for the header is reserved
/// with the text view's own `textContainerInset.top`, and the header is repositioned from
/// `scrollViewDidScroll`, which runs inside the scroll's own layout pass.
///
/// The header used to sit *outside* the scroll, in the editor's `VStack`. That pinned the date and
/// title to the top of the screen while a long note slid past underneath them, clipped mid-line at
/// the body's top edge — the note stopped reading as one page (2026-08-20). The **title** still lives
/// in the scroll for that reason and always will. The date left for the navigation bar on 2026-08-26,
/// which is a different thing: a navigation bar already reserves its own height, so nothing scrolls
/// underneath it and the clipping this class exists to prevent cannot come back through it.
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

    /// The container width the text was last styled for. Table columns are measured against the width
    /// the page actually has, and the first styling pass runs before this view has been laid out — so
    /// without this, a table was measured against a width of zero and never got its columns.
    private var styledWidth: CGFloat = 0

    /// Debug tracing marks the first layout pass only: the cold one is the question, and a page that
    /// lays out sixty times a second would drown the timeline it is meant to explain.
    private var hasLaidOut = false

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds

        let width = bounds.width
        let headerHeight = EditorTrace.measure("first header measurement") { header.height(forWidth: width) }
        let bodyTop = headerHeight + NotePageHeaderView.gap + Self.bodyTopInset
        // Guarded: assigning the inset invalidates layout, so writing it unconditionally would loop.
        if textView.textContainerInset.top != bodyTop {
            textView.textContainerInset.top = bodyTop
        }

        header.frame = CGRect(x: 0, y: 0, width: width, height: headerHeight)
        if !hasLaidOut { hasLaidOut = true; EditorTrace.mark("first page layout") }
        let containerWidth = textView.textContainer.size.width
        if abs(containerWidth - styledWidth) > 0.5 {
            styledWidth = containerWidth
            (textView.delegate as? BodyTextView.Coordinator)?.restyle(textView)
        }
        placeholderLabel.frame = CGRect(
            x: 0, y: bodyTop, width: width,
            height: ceil(placeholderLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        )
        // Table cards sit over the space their source lines reserved, and that space moves whenever the
        // header's height does — a longer title, a larger text size — so their positions settle here,
        // in the same pass as the words they belong to.
        let coordinator = textView.delegate as? BodyTextView.Coordinator
        coordinator?.tableCards.position(in: textView)
        coordinator?.codeCards.position(in: textView)
        syncChromeToScroll()
    }

    // MARK: Arriving

    /// Work parked until this page reaches a window — see `afterNavigationTransition`.
    private var pendingArrival: (() -> Void)?

    /// Runs `work` once the navigation transition this page arrived in has finished, or straight away
    /// when it arrived without one.
    ///
    /// A new note asks for the keyboard as it opens, and taken literally that means "become first
    /// responder while the push is still sliding". The keyboard then belongs to a view that is
    /// mid-transition, so it *travels with the page*: its surface slides in horizontally from the
    /// right edge along with the editor instead of rising from the bottom once the editor is there.
    /// In Light mode the incoming grey reads as a dark panel sweeping across the screen — the flicker
    /// a frame-by-frame look at the Home → New Note push finally explained (2026-08-20). It is a
    /// focus *timing* problem, not a keyboard appearance one.
    ///
    /// The transition coordinator is the only thing that actually knows when the push is over. A
    /// fixed delay would only guess, and guess wrong on a slow device, under Reduce Motion, and on
    /// any transition whose duration is not the one it was tuned against.
    func afterNavigationTransition(_ work: @escaping () -> Void) {
        afterNavigationTransition(work, lookAgain: true)
    }

    private func afterNavigationTransition(_ work: @escaping () -> Void, lookAgain: Bool) {
        // Not on screen yet: `didMoveToWindow` picks this back up, because a view outside the window
        // has no responder chain and so no transition to wait on.
        guard window != nil else { pendingArrival = work; return }

        if let coordinator = owningViewController?.transitionCoordinator {
            // `animate` returns false when there is nothing to animate alongside — its completion
            // never runs then, so the work has to happen here rather than be dropped.
            if !coordinator.animate(alongsideTransition: nil, completion: { _ in work() }) { work() }
            return
        }

        // No transition in flight. That can mean the push has not begun yet — SwiftUI can mount the
        // destination and activate the route in the same runloop turn — so look once more on the next
        // turn before concluding that the editor is already in place.
        guard lookAgain else { work(); return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { work(); return }
            self.afterNavigationTransition(work, lookAgain: false)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { EditorTrace.mark("didMoveToWindow") }
        guard window != nil, let work = pendingArrival else { return }
        pendingArrival = nil
        afterNavigationTransition({ EditorTrace.mark("navigation transition complete"); work() })
    }

    /// The view controller presenting this page — the SwiftUI host. `transitionCoordinator` resolves
    /// through its ancestors, so this finds the navigation controller's push without knowing about it.
    private var owningViewController: UIViewController? {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
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
