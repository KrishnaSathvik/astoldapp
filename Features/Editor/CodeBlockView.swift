import UIKit
import SwiftUI

/// A code block as it is *read*: monospaced, on its own quiet ground, scrolling sideways rather than
/// wrapping, with the code one tap from the pasteboard.
///
/// The mirror of `TableCardView`, and for the same reason (RULES.md §7). How a note stores code is
/// implementation — ```` ```python ```` is a fence, not something a reader should have to look past —
/// so while the note is being read the fences are hidden at the glyph layer and this is drawn over the
/// space they reserved. The moment the body takes the keyboard, this goes and the canonical fenced
/// source comes back for the person entitled to see it: the person editing it.
///
/// What this is not, and must never become: a runner, a console, an IDE, or an editor. It reads.
@MainActor
final class CodeBlockView: UIView {

    struct Palette: Equatable {
        var surface: UIColor
        var text: UIColor
        var secondaryText: UIColor
        var accent: UIColor
        /// One colour per token kind, for a block whose fence named a language As Told knows. Empty
        /// is a complete answer: the code is drawn in `text`, which is what an undeclared or unknown
        /// language gets and what every block got before syntax colour existed.
        var tokens: [CodeHighlighting.Token: UIColor] = [:]
    }

    private let languageLabel = UILabel()
    private let copyButton = UIButton(type: .system)
    private let scroller = UIScrollView()
    /// Non-editable and non-scrolling, sized to the code's own width. A text view rather than a label
    /// for its layout: an unbounded text container is what stops long lines wrapping.
    private let codeView = UITextView()

    /// Which of the block's two presentations this view is drawing.
    ///
    /// They are the *same* card as far as the reader is concerned, which is the point (RULES.md §7,
    /// amended 2026-08-24). The difference is only who draws the code: while the note is read this view
    /// does, from its own copy; while the block is being edited the text view does, because those are
    /// the characters the writer is typing into. So editing keeps the ground, the label and Copy Code
    /// and simply stops drawing text of its own — there is no second editor anywhere in this.
    enum Mode: Equatable {
        /// The whole card: surface, header, and the code drawn from `block`.
        case reading
        /// The header strip only, sitting over the hidden opening fence. The code underneath it is the
        /// text view's own, editable in place.
        case editing
    }

    private var block: CodeBlock
    private var layout: CodeCardLayout.Layout
    private var palette: Palette
    private var mode: Mode
    /// Set while the "Copied" confirmation is showing, so a second tap does not stack timers.
    private var copyResetTask: Task<Void, Never>?


    init(block: CodeBlock, layout: CodeCardLayout.Layout, palette: Palette, mode: Mode = .reading) {
        self.block = block
        self.layout = layout
        self.palette = palette
        self.mode = mode
        super.init(frame: .zero)

        layer.cornerRadius = CodeCardLayout.Metrics.corner
        layer.cornerCurve = .continuous
        clipsToBounds = true

        languageLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        languageLabel.adjustsFontForContentSizeCategory = true

        copyButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
        copyButton.titleLabel?.adjustsFontForContentSizeCategory = true
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)

        scroller.showsHorizontalScrollIndicator = true
        scroller.showsVerticalScrollIndicator = false
        scroller.alwaysBounceVertical = false
        scroller.contentInsetAdjustmentBehavior = .never

        codeView.isEditable = false
        codeView.isScrollEnabled = false
        // Not selectable: the card is inert except for Copy Code, so a tap goes through to the source
        // underneath. See `hitTest(_:with:)`.
        codeView.isSelectable = false
        codeView.backgroundColor = .clear
        codeView.textContainerInset = .zero
        codeView.textContainer.lineFragmentPadding = 0
        // The whole point: the container is unbounded, so nothing wraps and the scroller does the work.
        codeView.textContainer.widthTracksTextView = false
        codeView.textContainer.size = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                             height: CGFloat.greatestFiniteMagnitude)
        codeView.textContainer.lineBreakMode = .byClipping

        addSubview(languageLabel)
        addSubview(copyButton)
        addSubview(scroller)
        scroller.addSubview(codeView)

        apply()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func update(block: CodeBlock, layout: CodeCardLayout.Layout, palette: Palette, mode: Mode = .reading) {
        guard self.block != block || self.layout != layout || self.palette != palette || self.mode != mode
        else { return }
        self.block = block
        self.layout = layout
        self.palette = palette
        self.mode = mode
        apply()
    }

    private func apply() {
        // While editing, the ground is drawn behind the text by `StructuredLayoutManager` (`.astCodeBlock`)
        // so it can sit *under* the glyphs the writer is editing. A second fill here would cover them.
        backgroundColor = mode == .reading ? palette.surface : .clear
        scroller.isHidden = mode == .editing

        // The label says what the *source* said, in the reader's spelling of it — `sql` was stated, so
        // `SQL` is shown; `text` was stated, so **Plain text** is shown. A block whose fence named
        // nothing still shows nothing: an empty corner is quieter than a word nobody wrote (RULES.md §7).
        let name = block.cardLabel
        languageLabel.text = name
        languageLabel.textColor = palette.secondaryText
        languageLabel.isHidden = name == nil

        copyButton.setTitle(copyTitle, for: .normal)
        copyButton.setTitleColor(palette.accent, for: .normal)
        copyButton.accessibilityHint = block.isPreformatted
            ? "Copies the text without its fences."
            : "Copies the code without its fences."

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = CodeCardLayout.Metrics.lineSpacing
        paragraph.lineBreakMode = .byClipping
        let code = NSMutableAttributedString(
            string: block.code,
            attributes: [.font: CodeCardLayout.font(),
                         .foregroundColor: palette.text,
                         .paragraphStyle: paragraph]
        )
        // Colour, and only colour. Every character is already in place before this runs, and nothing
        // here inserts, removes, or reorders one — which is why syntax colour cannot reach `body`
        // (RULES.md §7, amended 2026-08-24). A language the fence did not name gets no spans at all.
        if let language = CodeHighlighting.language(named: block.language) {
            for span in CodeHighlighting.spans(in: block.code, language: language) {
                guard let colour = palette.tokens[span.token],
                      NSMaxRange(span.range) <= code.length else { continue }
                code.addAttribute(.foregroundColor, value: colour, range: span.range)
            }
        }
        // Nothing to draw in editing mode: those characters are in the text view, where they can be
        // typed into. Building the attributed copy anyway would be work whose result is never shown.
        codeView.attributedText = mode == .reading ? code : NSAttributedString()

        // A screen reader is told what this is before it is read out. Without that, a block of Python
        // is announced as a run of punctuation and the reader has no idea why — and a diagram is worse,
        // because box characters read as nothing at all (RULES.md §4).
        //
        // A preformatted block says "Plain text block" rather than "Code block, Plain text": the label
        // *is* the kind here, and announcing both would be two contradictory claims in one sentence.
        // What it does not do is interpret the drawing. `│` and `▼` are read as the characters they
        // are; describing them as "a branch going down to Airflow" would be As Told deciding what
        // somebody's diagram means, which is the one thing it must never do (RULES.md §2).
        codeView.accessibilityLabel = block.isPreformatted
            ? "Plain text block"
            : name.map { "Code block, \($0)" } ?? "Code block"
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let insetH = CodeCardLayout.Metrics.cardInsetH
        let insetV = CodeCardLayout.Metrics.cardInsetV
        let header = CodeCardLayout.Metrics.headerHeight

        languageLabel.frame = CGRect(x: insetH, y: 0,
                                     width: bounds.width / 2, height: header)
        let copyWidth = max(88, copyButton.intrinsicContentSize.width + 16)
        copyButton.frame = CGRect(x: bounds.width - insetH - copyWidth, y: 0,
                                  width: copyWidth, height: header)

        // The height `CodeCardLayout` reserved is header + insetV + lines + insetV, so the code sits
        // inside both of those insets rather than starting flush against the header.
        scroller.frame = CGRect(x: insetH, y: header + insetV,
                                width: max(0, bounds.width - insetH * 2),
                                height: max(0, bounds.height - header - insetV * 2))
        let codeWidth = max(layout.codeWidth, scroller.bounds.width)
        codeView.frame = CGRect(x: 0, y: 0, width: codeWidth, height: scroller.bounds.height)
        scroller.contentSize = CGSize(width: codeWidth, height: scroller.bounds.height)
    }

    // MARK: What the card drew
    //
    // Colour is the one thing about this view that cannot be checked from the document layer, and a
    // screenshot is not a test. These read back what was drawn — they never change it.

    /// The code exactly as it is drawn, colours included.
    var drawnCode: NSAttributedString? { codeView.attributedText }
    /// The language label's text, or `nil` when there is no label — which is what a block whose fence
    /// named nothing gets.
    var drawnLanguage: String? { languageLabel.isHidden ? nil : languageLabel.text }
    /// What a screen reader is told before it reads the code.
    var drawnCodeAccessibilityLabel: String? { codeView.accessibilityLabel }

    // MARK: Reaching a diagram that is wider than the page
    //
    // A wide block has always measured wider than its card, refused to wrap, and drawn a scroll
    // indicator — and could not be scrolled, because `hitTest` hands every touch through to the text
    // view underneath. That transparency is not a bug to remove: it is what lets a tap put the caret in
    // the source, and owning the card's touches once left a block with no way in at all.
    //
    // So the card does not take the gesture. It exposes what a gesture would need — whether there is
    // anything to scroll, where the scroll currently is, and how to move it — and `StructuredTextView`
    // claims a clearly horizontal drag on its behalf (`CardPanRule`, added 2026-08-25).

    /// Whether a horizontal drag over this card should scroll it.
    ///
    /// **Every** rendered block that is wider than its card, code and preformatted alike (widened
    /// 2026-08-25). This first shipped scoped to `isPreformatted`, because widening it touched a shipped
    /// interaction and that is a decision rather than a detail. The decision went the only way it could:
    /// `RULES.md` §7 says long code lines *scroll horizontally; they never wrap*, and a card that draws a
    /// scroll indicator no finger can move does not keep that promise — it advertises it. A code card and
    /// a diagram card are the same card with a different label, and this is the last place they differed.
    ///
    /// A block being **edited** is still excluded: its characters belong to the text view then, not to
    /// this view's scroller, and the caret is what moves through them.
    var scrollsHorizontally: Bool {
        mode == .reading && layout.scrolls
    }

    /// How far the drawing is scrolled, in points.
    var horizontalOffset: CGFloat { scroller.contentOffset.x }

    /// The furthest it may go — zero when the drawing already fits.
    var maxHorizontalOffset: CGFloat {
        max(0, scroller.contentSize.width - scroller.bounds.width)
    }

    /// Moves the drawing sideways, bounded to `0...maxHorizontalOffset`.
    ///
    /// Presentation only: not one character moves, and nothing here reaches `Note.body`. The offset is
    /// the card's own and is not persisted — leaving the note and coming back starts at the beginning,
    /// which is where a diagram is read from.
    func scrollHorizontally(by delta: CGFloat) {
        guard scrollsHorizontally else { return }
        let target = min(max(0, scroller.contentOffset.x + delta), maxHorizontalOffset)
        scroller.contentOffset.x = target
    }

    /// Whether a drag beginning at `point` (in this card's coordinates) may scroll it.
    ///
    /// Copy Code / Copy Text wins wherever the touch begins on the button, however the finger moves
    /// afterwards — a drag that starts on a button is a cancelled tap, not a scroll.
    func acceptsHorizontalPan(at point: CGPoint) -> Bool {
        scrollsHorizontally && !copyButton.frame.contains(point)
    }

    /// Whether this card claims a touch at `point`, in its own coordinates. Only Copy Code does.
    func claimsTouch(at point: CGPoint) -> Bool { copyButton.frame.contains(point) }

    /// Everything but Copy Code is transparent to touches, so a tap on the card reaches the text view
    /// underneath and puts the caret in the code — exactly what a tap on a table card does.
    ///
    /// This is why the card does not offer selection of its own. Owning its touches so the code could
    /// be selected in place left the block with **no way in**: a tap did nothing, and the source it was
    /// covering could not be reached at all. Copy Code covers copying the whole block, and selecting
    /// part of it means tapping in — which is now what a tap does. (Caught by
    /// `testOnlyTheCodeBlockTheCaretIsInShowsItsSource` before it could ship.)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === copyButton ? hit : nil
    }

    /// What the button says at rest. A diagram is not code, and a button that calls it code is the
    /// card telling the reader something untrue about their own note.
    private var copyTitle: String { block.isPreformatted ? "Copy Text" : "Copy Code" }

    @objc func copyCode() {
        // The fences are storage, not content. Someone pasting this into a terminal, an editor, or
        // straight back into a chat wants what they saw — every space and every box character of it
        // (locked with the V2 links/code contract, RULES.md §5).
        UIPasteboard.general.string = block.code

        copyResetTask?.cancel()
        copyButton.setTitle("Copied", for: .normal)
        UIAccessibility.post(notification: .announcement,
                             argument: block.isPreformatted ? "Text copied" : "Code copied")
        copyResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled, let self else { return }
            self.copyButton.setTitle(self.copyTitle, for: .normal)
        }
    }
}

extension CodeBlockView.Palette {
    /// The card in the app's own colours, resolved from the semantic tokens so Light and Dark are one
    /// definition (RULES.md §4).
    @MainActor static var ds: CodeBlockView.Palette {
        CodeBlockView.Palette(
            surface: UIColor(Color.ds.codeSurface),
            text: UIColor(Color.ds.textPrimary),
            secondaryText: UIColor(Color.ds.textSecondary),
            accent: UIColor(Color.ds.accent),
            tokens: [
                .keyword: UIColor(Color.ds.codeKeyword),
                .string: UIColor(Color.ds.codeString),
                .comment: UIColor(Color.ds.codeComment),
                .number: UIColor(Color.ds.codeNumber),
                .type: UIColor(Color.ds.codeType),
            ]
        )
    }
}
