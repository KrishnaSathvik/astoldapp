import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A handle the editor holds to run a document action *inside* the body text view.
///
/// The Style control lives in the toolbar, but its edit has to go through the text view's own edit
/// primitive — that is what keeps one tap to one undo step and leaves the keyboard and the live
/// selection untouched. Passing a closure the coordinator fills in is the smallest way to reach it;
/// the alternative, pushing a "pending style" down as state and applying it in `updateUIView`, would
/// make an action look like a value and fire again on any unrelated update.
@MainActor
final class BodyEditorActions {
    fileprivate var applyStyle: ((BlockStyle) -> Void)?
    fileprivate var commitAndRead: (() -> String?)?

    /// Applies `style` to every line the body's current selection touches. A no-op before the text
    /// view exists, or while the body is not editable (a recording owns the anchor).
    func apply(_ style: BlockStyle) { applyStyle?(style) }

    /// Closes any edit still open inside the body and returns the text view's own current text.
    ///
    /// For Share, and for the one case where the note in `body` is genuinely behind what is on screen:
    /// a **table cell** being edited lives in the card's own field until it commits, so someone who
    /// changes `Anchorage` to `Fairbanks` and taps Share immediately would otherwise send `Anchorage`.
    /// Typing in the body itself has no such gap — every keystroke reaches the binding — but the text
    /// view is read back anyway, because "what is on screen" is the thing being shared and there is no
    /// reason to ask a copy of it.
    ///
    /// Returns `nil` before the text view exists. Committing a cell is the writer's own edit landing
    /// through the ordinary undoable path; nothing here is a change Share invented.
    func commitPendingEdits() -> String? { commitAndRead?() ?? nil }
}

/// UITextView-backed body editor. The backing store holds the raw source string (with lightweight
/// markers) so voice transcripts insert exactly at the caret and native editing / IME / autocorrect keep
/// working (docs/04-voice-transcription.md §8, docs/02-features.md Milestone A). Markers are hidden and
/// list markers drawn by `StructuredLayoutManager`; structure edits go through the shared `DocumentAction`
/// operations. Plain notes render exactly as before.
///
/// Focus is *explicit*: the view never becomes first responder on its own. A new note asks for focus by
/// setting `isFocused`; an existing note opens for reading with the keyboard hidden, and a tap puts the
/// caret where the user tapped (RULES.md §4).
struct BodyTextView: UIViewRepresentable {
    /// The raw source string (the note body). Selections/offsets are in source coordinates.
    @Binding var text: String
    @Binding var selectedRange: NSRange
    /// Two-way keyboard focus. Setting it true/false focuses/dismisses.
    @Binding var isFocused: Bool
    var isEditable: Bool
    /// The appearance the keyboard is **born** with. Required, and never `.default`.
    ///
    /// SwiftUI knows the effective As Told appearance; UIKit has to be told it outright. The keyboard
    /// lives in its own `UIRemoteKeyboardWindow`, inherits none of `AppRootView`'s
    /// `preferredColorScheme`, and `.default` asks that window to resolve its own appearance — from
    /// the device rather than from the app, so a forced Light/Dark theme would stop at the keyboard.
    /// See `AppTheme.keyboardAppearance(inheriting:)`. There is deliberately **no default value**:
    /// every construction site has to decide, because "left to decide" is the bug. Set in
    /// `makeUIView`, before anything can make this view first responder.
    var keyboardAppearance: UIKeyboardAppearance
    /// Filled in with a way to run a document action against this text view — see `BodyEditorActions`.
    var actions: BodyEditorActions? = nil

    // MARK: The rest of the page
    //
    // The date and the title are inputs to *this* view rather than siblings above it in the editor's
    // stack, because they scroll with the body — see `NotePageView`. They are plain `Binding`s (not
    // `@Binding`) so the pure-logic tests can keep building a `BodyTextView` with the five arguments
    // they care about.

    /// The optional note title.
    var title: Binding<String> = .constant("")
    /// Two-way keyboard focus for the title, exactly as `isFocused` is for the body.
    var titleFocused: Binding<Bool> = .constant(false)
    /// Called when a table in the note is tapped while reading — the note hands over the block, and
    /// the editor opens the reader on it. Never while editing: a tap in a table you are writing is a
    /// tap that places the caret, exactly as it does in any other line.
    var openTable: (TableBlock) -> Void = { _ in }
    /// Opening a link is the page's job, not the text view's. Only http(s) destinations ever reach
    /// here — `LinkSpan` refuses anything else, so a note can never carry a tappable `javascript:`.
    var openLink: (URL) -> Void = { url in UIApplication.shared.open(url) }
    /// Called when the title field gives up first responder — the only moment the title may be tidied
    /// (`EditorModel.endTitleEditing`). Nothing touches those characters while they are being typed.
    var titleEditingEnded: () -> Void = {}
    /// Shown while the body is empty. Empty means "no placeholder".
    var bodyPlaceholder: String = ""

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> NotePageView {
        EditorTrace.mark("makeUIView")
        let tv = StructuredTextView.make()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = StructuredTextStyle.bodyFont()
        tv.adjustsFontForContentSizeCategory = true
        tv.textColor = UIColor(Color.ds.textPrimary)
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        tv.keyboardDismissMode = .interactive
        // Before first responder, never after. Focus is taken from `updateUIView`, one runloop turn
        // after this method returns, so a keyboard raised for a new note is already the right colour
        // the first time it is drawn.
        tv.keyboardAppearance = keyboardAppearance
        tv.alwaysBounceVertical = true
        // Quiet editorial: no visible scrollbar, here as everywhere else in the app. A long note
        // is a page that flows, not a document with a measuring stick down its side.
        tv.showsVerticalScrollIndicator = false
        tv.showsHorizontalScrollIndicator = false
        tv.text = text
        EditorTrace.mark("text assigned (\(text.utf16.count) UTF-16)")
        EditorTrace.measure("first restyle") { context.coordinator.restyle(tv) }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        // A code card is a real subview with a real button in it. Left cancelling, this recognizer
        // sends the button `touchesCancelled` the moment it recognizes, and Copy Code never fires.
        // The text view's own tap still yields to this one, so claiming a touch is still what
        // suppresses caret placement — see `gestureRecognizerShouldBegin`.
        tap.cancelsTouchesInView = false
        tv.addGestureRecognizer(tap)
        context.coordinator.checkboxTap = tap

        // A wide preformatted card is the only thing on this surface that wants a sideways drag, and it
        // cannot ask for one itself: the card hands every touch through so a tap can still reach the
        // source underneath (`CodeBlockView.hitTest`). So the drag is claimed here, on the text view,
        // and only when it is clearly horizontal and there is something to scroll (`CardPanRule`).
        //
        // `cancelsTouchesInView = false` for the same reason the tap sets it: a card holds a real
        // button, and cancelling would take Copy Text away mid-touch.
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleCardPan(_:)))
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        tv.addGestureRecognizer(pan)
        context.coordinator.cardPan = pan
        // The text view's own single-tap (caret placement) yields to ours, so tapping a checkbox toggles
        // without also placing a caret / raising the keyboard. Elsewhere ours declines and the default runs.
        for recognizer in tv.gestureRecognizers ?? [] {
            if let single = recognizer as? UITapGestureRecognizer,
               single !== tap, single.numberOfTapsRequired == 1 {
                single.require(toFail: tap)
            }
        }

        // Body, headings, and list markers are all resolved from the current text size at styling
        // time, and styling otherwise only runs on an edit — so an editor sitting open while the
        // reader changes their text size in Settings would keep the old size until the next keystroke.
        tv.registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) {
            [weak coordinator = context.coordinator] (view: UITextView, _: UITraitCollection) in
            coordinator?.restyle(view)
            // The gutter markers are drawn, not laid out, so they need the redraw asked for explicitly.
            view.setNeedsDisplay()
        }

        // Same argument, one preference over: Differentiate Without Color decides whether a link carries
        // an underline as well as its colour, and it is a notification rather than a trait — so an editor
        // sitting open while the reader turns it on kept un-underlined links until the next keystroke.
        // Registered here for symmetry with the line above; owned and torn down by the coordinator.
        context.coordinator.observeDifferentiateWithoutColor(for: tv)

        context.coordinator.bind(actions, to: tv)

        let page = NotePageView(textView: tv)
        page.placeholderText = bodyPlaceholder
        let field = page.header.titleField
        field.delegate = context.coordinator
        field.keyboardAppearance = keyboardAppearance   // same reasoning as the body's, above
        field.text = title.wrappedValue
        field.isEnabled = isEditable
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.titleChanged(_:)),
                        for: .editingChanged)
        page.refreshPlaceholder()
        context.coordinator.page = page
        return page
    }

    /// Fill whatever the editor offers. The page has no size of its own to report — it is a scroll
    /// view and a header — and left to Auto Layout an unconstrained `UIView` measures to nothing.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NotePageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func updateUIView(_ page: NotePageView, context: Context) {
        context.coordinator.parent = self
        let tv = page.textView
        page.placeholderText = bodyPlaceholder
        updateTitle(page.header.titleField, context: context)

        // A theme changed while this editor was open. Reload the input views *only* when the keyboard
        // is actually on screen and the value genuinely changed: reloading unconditionally is itself a
        // flicker, which is the thing this property exists to remove.
        if tv.keyboardAppearance != keyboardAppearance {
            tv.keyboardAppearance = keyboardAppearance
            if tv.isFirstResponder { tv.reloadInputViews() }
        }

        if tv.text != text {
            // A voice transcript (or SwiftUI handing us a different note) is a document mutation too:
            // apply it as one native edit so it undoes in one step, with the caret the editor asked for.
            context.coordinator.applyExternalChange(text, caret: selectedRange, to: tv)
        }

        if tv.isEditable != isEditable { tv.isEditable = isEditable }

        // Focus is driven from the editor; guard on the current responder state so this never loops.
        //
        // Taking it waits for the navigation transition to finish. A new note sets `isFocused` as it
        // opens, and a keyboard raised while the editor is still sliding in slides in *with* it —
        // see `NotePageView.afterNavigationTransition`. Nothing waits when no transition is running,
        // so tapping into an existing note and coming back from a recording are unaffected.
        if isEditable, isFocused, !tv.isFirstResponder {
            DispatchQueue.main.async {
                guard isFocused, isEditable, !tv.isFirstResponder else { return }
                page.afterNavigationTransition {
                    if isFocused, isEditable, !tv.isFirstResponder {
                        EditorTrace.measure("body becomeFirstResponder") { tv.becomeFirstResponder() }
                    }
                }
            }
        } else if (!isFocused || !isEditable), tv.isFirstResponder {
            DispatchQueue.main.async {
                if !isFocused || !isEditable, tv.isFirstResponder { tv.resignFirstResponder() }
            }
        }

        page.refreshPlaceholder()
    }

    /// The title half of `updateUIView`: value, enabled state, keyboard appearance, and the same
    /// two-way focus dance the body does one method up.
    private func updateTitle(_ field: UITextField, context: Context) {
        // While the writer is in the field, the field's own text is the truth. Assigning `text` here
        // would not only overwrite what they typed, it would move the caret to the end of whatever
        // replaced it — so a model that echoed back a normalized title turned a space into a jump.
        // Outside an edit, the model is the truth and the field follows it.
        if !field.isFirstResponder, field.text != title.wrappedValue {
            field.text = title.wrappedValue
        }
        if field.isEnabled != isEditable { field.isEnabled = isEditable }
        if field.keyboardAppearance != keyboardAppearance {
            field.keyboardAppearance = keyboardAppearance
            if field.isFirstResponder { field.reloadInputViews() }
        }

        let wantsFocus = titleFocused.wrappedValue
        if isEditable, wantsFocus, !field.isFirstResponder {
            DispatchQueue.main.async {
                if wantsFocus, !field.isFirstResponder {
                    EditorTrace.measure("title becomeFirstResponder") { field.becomeFirstResponder() }
                }
            }
        } else if (!wantsFocus || !isEditable), field.isFirstResponder {
            DispatchQueue.main.async {
                if !wantsFocus || !field.isEnabled, field.isFirstResponder { field.resignFirstResponder() }
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate {
        var parent: BodyTextView
        var checkboxTap: UITapGestureRecognizer?
        /// The sideways drag that scrolls a wide preformatted card. See `CardPanRule`.
        var cardPan: UIPanGestureRecognizer?
        /// The card the drag in flight is scrolling, held so a gesture that began on one card cannot
        /// wander onto another halfway through.
        private var panningCard: CodeBlockView?
        /// Whether the drag in flight turned out to be horizontal. `nil` while the finger has not moved
        /// far enough to have said.
        private var panIsHorizontal: Bool?
        /// The page this coordinator's text view lives on, when there is one. Weak because the page
        /// owns the text view that owns this delegate. `nil` in the unit tests, which drive a bare
        /// text view with no chrome around it.
        weak var page: NotePageView?
        /// True while a structural edit is being applied, so our own `replace` never re-enters the
        /// Return/Backspace handling that produced it.
        private var isApplyingEdit = false
        init(_ parent: BodyTextView) { self.parent = parent }

        /// The table cards on the page, and where they sit. Reading only — see `TableCardPresenter`.
        let tableCards = TableCardPresenter()
        /// The code cards, on exactly the same terms — see `CodeCardPresenter`.
        let codeCards = CodeCardPresenter()
        /// The lines the last restyle drew as source — the block the caret was in. Kept so a caret
        /// move only costs a restyle when it actually changes which block is being edited.
        private var renderedSourceLines: ClosedRange<Int>??
        /// Where the caret was before this selection change, so a hidden row knows which way to let it
        /// out — down onto the first row, or back up onto the header.
        private var previousCaret = 0

        // MARK: Differentiate Without Color
        //
        // A link is drawn in `Color.ds.link`, and colour MUST NOT be the only thing that says so
        // (RULES.md §4). When the reader has asked the system not to rely on colour, links also carry an
        // underline. That was read once per restyle and never re-read, so toggling the setting with a
        // note open left the links as they were until the next keystroke moved the caret and paid for a
        // restyle anyway. Dynamic Type had the same gap and is solved the same way, two screens up
        // (`registerForTraitChanges`) — this is that fix for the one accessibility preference that is a
        // notification rather than a trait.

        /// Whether links are underlined as well as coloured.
        ///
        /// A closure rather than a `Bool` so a test can answer for it: the real setting is a global the
        /// process cannot change, and a test that cannot flip it cannot prove the restyle responds. This
        /// is the whole abstraction — production reads `UIAccessibility` exactly as it did before.
        var differentiatesWithoutColor: () -> Bool = { UIAccessibility.shouldDifferentiateWithoutColor }

        /// Held so the observer is removed when this coordinator goes.
        ///
        /// A token rather than the raw observer because `deinit` is nonisolated and cannot reach a
        /// `@MainActor` property. Letting the token's *own* deinit do the removal sidesteps that
        /// entirely: releasing the coordinator releases this, and releasing this removes the observer.
        private var differentiateObserver: ObserverToken?

        /// Restyles `tv` whenever Differentiate Without Color changes, for as long as this coordinator
        /// lives.
        ///
        /// Attributes only, exactly like every other restyle: not one character of `body` moves, the
        /// selection is put back where it was, focus is not taken, and nothing else on the page is
        /// rebuilt. The text view is held weakly — the page owns it, and an observer must never be the
        /// reason it stays alive.
        func observeDifferentiateWithoutColor(for tv: UITextView) {
            guard differentiateObserver == nil else { return }
            // `queue: nil` — the block runs synchronously on the posting thread. UIKit posts this one
            // on the main thread, so that is where the restyle happens, and it happens *before* the
            // next frame rather than a runloop turn later. Anything posting it off the main thread is
            // hopped rather than trusted, because a restyle touches TextKit.
            let observer = NotificationCenter.default.addObserver(
                forName: UIAccessibility.differentiateWithoutColorDidChangeNotification,
                object: nil, queue: nil
            ) { [weak self, weak tv] _ in
                guard Thread.isMainThread else {
                    DispatchQueue.main.async { [weak self, weak tv] in
                        guard let self, let tv else { return }
                        MainActor.assumeIsolated { self.restyle(tv) }
                    }
                    return
                }
                guard let self, let tv else { return }
                MainActor.assumeIsolated { self.restyle(tv) }
            }
            differentiateObserver = ObserverToken(observer)
        }

        /// Owns one notification observer and removes it on the way out.
        ///
        /// A block-based observer outlives its owner unless it is removed by hand, and a stale one
        /// restyling a text view nobody is looking at is a leak with a side effect.
        final class ObserverToken {
            private let observer: any NSObjectProtocol
            init(_ observer: any NSObjectProtocol) { self.observer = observer }
            deinit { NotificationCenter.default.removeObserver(observer) }
        }

        /// Re-applies structure styling (attributes only — never characters), preserving the selection,
        /// and rebuilds the table cards the new styling made room for.
        ///
        /// Tables are the one structure with two presentations, chosen by who is looking. A note being
        /// **read** hides its table source and puts a real `TableCardView` over the space it reserved.
        /// A note being **edited** shows the source, because the caret has to be somewhere the writer
        /// can see it, and because a table is edited the way every other line in the note is — as text
        /// (RULES.md §7, amended 2026-08-21).
        func restyle(_ tv: UITextView) {
            let selection = tv.selectedRange
            let editing = tv.isFirstResponder
            // Only the block the caret is *in* gives up its card. Everything else on the page stays
            // rendered, keyboard up or down — typing a sentence next to a table must not turn every
            // table in the note back into pipe rows (RULES.md §7, amended 2026-08-23).
            let sourceLines: ClosedRange<Int>? = editing
                ? StructuredText.lineIndices(touchedBy: selection, in: tv.text as NSString)
                : nil
            renderedSourceLines = .some(sourceLines)

            // A block flipping between card and source changes the note's height, and the writer is in
            // the middle of typing somewhere below it. Hold the caret's position **on screen** across
            // the change, or the words move under their finger.
            let caretBefore = editing ? caretY(in: tv) : nil

            let heights = tableCards.plan(for: tv, sourceLines: sourceLines)
            let codeHeights = codeCards.plan(for: tv, sourceLines: sourceLines)
            StructuredTextStyler.apply(to: tv.textStorage,
                                       textColor: UIColor(Color.ds.textPrimary),
                                       secondaryColor: UIColor(Color.ds.textTertiary),
                                       linkColor: UIColor(Color.ds.link),
                                       availableWidth: tv.textContainer.size.width
                                           - tv.textContainer.lineFragmentPadding * 2,
                                       tableCards: heights,
                                       codeCards: codeHeights,
                                       codeTokens: CodeBlockView.Palette.ds.tokens,
                                       underlinesLinks: differentiatesWithoutColor())
            tv.selectedRange = selection
            syncTypingAttributes(tv)
            tableCards.sync(in: tv, palette: .ds) { [weak self] table, position, text in
                self?.commitCell(table, at: position, to: text, in: tv)
            }
            codeCards.sync(in: tv, palette: .ds)

            if let caretBefore, let caretAfter = caretY(in: tv) {
                let shift = caretAfter - caretBefore
                // Sub-point drift is TextKit rounding, not a block changing shape; correcting it would
                // fight the scroll view on every keystroke.
                if abs(shift) > 0.5 {
                    tv.contentOffset.y = max(0, tv.contentOffset.y + shift)
                }
            }
        }

        /// One cell of a table, written back into `body`.
        ///
        /// The card reports *which* cell changed and to what; turning that into characters is this
        /// side's job, and it goes through the same edit primitive every other structural operation
        /// uses — so a cell edit is one undo step, and `body` stays canonical pipe rows (RULES.md §4, §5).
        ///
        /// The table is re-read from the note before the edit is computed. The copy the card is holding
        /// was made when the card was last synced, and a commit can arrive after something else has
        /// already changed the note underneath it.
        func commitCell(_ table: TableBlock, at position: TableBlock.CellPosition,
                        to text: String, in tv: UITextView) {
            guard let current = TableBlock.tables(in: tv.text)
                .first(where: { $0.lineRange == table.lineRange }),
                  let edit = TableBlock.cellEdit(in: tv.text, table: current,
                                                 at: position, text: text)
            else { return }
            // The caret stays where the writer put it: it is in a table cell's field, not in the note's
            // text, and moving the note's selection would fight the field for the keyboard.
            let caret = tv.selectedRange
            _ = apply(edit, to: tv, caret: caret)
        }

        /// Where the caret sits in the note's content, or `nil` when there is no caret to hold on to.
        private func caretY(in tv: UITextView) -> CGFloat? {
            tv.layoutManager.ensureLayout(for: tv.textContainer)
            guard let position = tv.selectedTextRange?.start else { return nil }
            let rect = tv.caretRect(for: position)
            return rect.isNull || rect.isInfinite ? nil : rect.minY
        }

        /// The link under `point`, when the note is being read. While it is being edited a tap places
        /// the caret, exactly as it does on a table: a writer reaching into a sentence to fix a word
        /// must not be sent to Safari instead (RULES.md §7 — editable without fighting the writer).
        func tappedLink(in tv: UITextView, at point: CGPoint) -> URL? {
            guard !tv.isFirstResponder, !tv.text.isEmpty else { return nil }
            var point = point
            point.x -= tv.textContainerInset.left
            point.y -= tv.textContainerInset.top
            guard point.x >= 0, point.y >= 0 else { return nil }

            let manager = tv.layoutManager
            let glyph = manager.glyphIndex(for: point, in: tv.textContainer,
                                           fractionOfDistanceThroughGlyph: nil)
            // `glyphIndex(for:)` clamps to the nearest glyph, so a tap in the margin past the end of a
            // line would otherwise "hit" the link that ends it.
            let fragment = manager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
            guard fragment.contains(point) else { return nil }

            let character = manager.characterIndexForGlyph(at: glyph)
            guard character < (tv.text as NSString).length,
                  let destination = tv.textStorage.attribute(.astLink, at: character,
                                                             effectiveRange: nil) as? String
            else { return nil }
            return URL(string: destination)
        }

        /// Keeps the text view's `typingAttributes` describing the line the caret is actually on.
        ///
        /// This is what puts the caret in the right place the *instant* a writer leaves a list, rather
        /// than one keystroke later. An empty last line has no characters, so nothing in the text
        /// storage can describe it — TextKit lays out that final fragment from the typing attributes
        /// instead. Leave them describing the line before it and Return on an empty bullet produced a
        /// correct document with a visibly wrong caret: the marker was gone, the line was a paragraph,
        /// and the caret still sat at the list indent until a character arrived to give the line
        /// attributes of its own.
        ///
        /// Cheap and idempotent, so it runs after every restyle and every selection change. UIKit
        /// resets typing attributes itself when the selection moves, which is why re-deriving them is
        /// the fix rather than setting them once.
        func syncTypingAttributes(_ tv: UITextView) {
            // Never mid-composition: replacing typing attributes under an IME (Telugu/Hindi and other
            // marked text) is the same hazard restyling is, for the same reason.
            guard tv.markedTextRange == nil else { return }
            let doc = MarkupDocument(tv.text)
            let index = doc.lineIndex(containingSource: tv.selectedRange.location)
            guard index < doc.lines.count else { return }
            tv.typingAttributes = StructuredTextStyle.attributes(
                for: doc.lines[index].kind,
                isFirstLine: index == 0,
                textColor: UIColor(Color.ds.textPrimary)
            )
        }

        /// Applies a structural edit through the text view's own edit primitive, so the undo manager
        /// records exactly **one** step for the user's one action. Assigning `tv.text` instead would
        /// bypass undo registration entirely and leave the stack describing text that no longer exists.
        /// `caret` overrides where the selection lands (checkbox toggling leaves the caret where it was).
        @discardableResult
        func apply(_ edit: TextEdit, to tv: UITextView, caret: NSRange? = nil) -> Bool {
            guard let range = tv.textRange(for: edit.range) else { return false }
            let before = tv.text ?? ""
            let caretBefore = tv.selectedRange

            // UIKit registers an *incomplete* undo for a replacement spanning a paragraph break (undoing
            // "\n- " leaves the newline behind), so a structural edit owns its undo entry: UIKit's
            // registration is suppressed and the exact inverse is registered instead. One user action,
            // one undo step, exactly the text that was there before.
            let undoManager = tv.undoManager
            undoManager?.disableUndoRegistration()
            isApplyingEdit = true
            tv.replace(range, withText: edit.string)
            isApplyingEdit = false
            undoManager?.enableUndoRegistration()

            // The *length* survives, not just the caret: converting four selected lines leaves those
            // four lines selected, so a writer who picked the wrong style can pick another without
            // reselecting. Undo relies on it too — the inverse restores the selection the edit had.
            let length = tv.text.utf16.count
            let target = caret ?? edit.selection
            let location = min(target.location, length)
            tv.selectedRange = NSRange(location: location, length: min(target.length, length - location))
            restyle(tv)
            syncBindings(tv)

            // The target is the coordinator, not the text view: the text view owns this undo manager, so
            // registering it as the target would retain the editor for as long as the stack lives.
            let inverse = edit.inverse(in: before, caret: caretBefore)
            undoManager?.registerUndo(withTarget: self) { [weak tv] coordinator in
                guard let tv else { return }
                // Applying the inverse registers *its* inverse, which is the redo.
                coordinator.apply(inverse, to: tv, caret: inverse.selection)
            }
            return true
        }

        /// Gives the editor a way to apply a block style to the live selection. Read straight off the
        /// text view rather than from the SwiftUI binding: the binding is a copy of the selection as of
        /// the last update, and this runs against whatever the writer has selected right now.
        func bind(_ actions: BodyEditorActions?, to tv: UITextView) {
            actions?.applyStyle = { [weak self, weak tv] style in
                guard let self, let tv, tv.isEditable else { return }
                let edit = DocumentAction.setBlockKindEdit(style.kind, text: tv.text, selection: tv.selectedRange)
                self.apply(edit, to: tv)
            }
            actions?.commitAndRead = { [weak self, weak tv] in
                // `nil`, never `""`. An empty string here would be indistinguishable from an empty
                // note, and the caller would go on to share nothing rather than fall back to the
                // model's own body.
                guard let self, let tv else { return nil }
                // The only edit that can still be open somewhere other than this text view. It commits
                // synchronously, through the same `TextEdit` any other change uses, so `tv.text` is
                // current by the time this returns.
                self.tableCards.commitActiveCellEdits()
                return tv.text
            }
        }

        /// A body change that arrives from outside the text view — a voice transcript landing at the
        /// caret, or SwiftUI handing us a different note. Applying the *difference* keeps it one undoable
        /// step; if the view refuses the edit, fall back to assignment and drop the undo stack rather
        /// than leave it describing text that no longer exists.
        func applyExternalChange(_ newText: String, caret: NSRange, to tv: UITextView) {
            let edit = TextEdit.diff(from: tv.text, to: newText, caret: caret)
            if apply(edit, to: tv), tv.text == newText { return }

            tv.text = newText
            tv.undoManager?.removeAllActions()
            restyle(tv)
            tv.selectedRange = NSRange(location: min(caret.location, tv.text.utf16.count), length: 0)
        }

        /// Pushes the view's state back to SwiftUI, but only on a real change: an external update runs
        /// inside `updateUIView`, where writing an unchanged value would still mutate observed state.
        private func syncBindings(_ tv: UITextView) {
            if parent.text != tv.text { parent.text = tv.text }
            if parent.selectedRange != tv.selectedRange { parent.selectedRange = tv.selectedRange }
        }

        // MARK: Editing

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Our own structural edit is already the user's single action; let it through untouched.
            guard !isApplyingEdit else { return true }

            // The second lock on "a marker is not a place" (the first is in `textViewDidChangeSelection`).
            // Text can arrive at a range no caret was ever drawn at — a drag and drop into the gutter,
            // dictation, an autocorrect replacement — and an insertion in front of a marker would push
            // the marker into the middle of the line, where it stops being hidden and starts being
            // words. It happens *after* the marker instead, and the item keeps its structure.
            if range.length == 0, !text.isEmpty, tv.markedTextRange == nil {
                let doc = MarkupDocument(tv.text)
                let line = doc.line(containingSource: range.location)
                // A hidden **link** run is the same hazard as a hidden marker, and arrives by the same
                // routes: a character dropped into the syntax of `](https://…)` does not push a marker
                // out of place, it dismantles the link — the destination is lost and the brackets the
                // reader was never meant to see become words. It lands after the link instead, where
                // the writer could see their caret.
                var destination: Int?
                if let escape = doc.caretEscapingHiddenSyntax(from: range.location, movingForward: true) {
                    destination = escape
                } else if line.markerLength > 0, range.location < line.contentStart {
                    destination = line.contentStart
                }
                if let destination {
                    let caret = NSRange(location: destination, length: 0)
                    let edit = text == "\n"
                        ? (DocumentAction.returnEdit(text: tv.text, selection: caret)
                            ?? DocumentAction.insertEdit(text, selection: caret))
                        : DocumentAction.insertEdit(text, selection: caret)
                    if apply(edit, to: tv) { return false }
                }
            }

            // Return: continue/exit lists via the shared operation.
            if text == "\n" {
                if let edit = DocumentAction.returnEdit(text: tv.text, selection: range), apply(edit, to: tv) {
                    return false
                }
                return true
            }
            // A marker the keyboard altered (smart dash, non-breaking space) is put back to canonical
            // characters at the moment it is completed, so forgiving input still produces strict source.
            if !text.isEmpty,
               let edit = DocumentAction.prefixNormalizationEdit(
                   text: tv.text, selection: range, replacementText: text
               ), apply(edit, to: tv) {
                return false
            }
            // A different complete marker typed on a line that holds only a marker replaces it, so a
            // writer who continues a bullet and then types "1. " gets a numbered item rather than a
            // bullet reading "1. ". One keystroke, one edit, one undo step.
            if !text.isEmpty,
               let edit = DocumentAction.markerReplacementEdit(
                   text: tv.text, selection: range, replacementText: text
               ), apply(edit, to: tv) {
                return false
            }
            // Backspace at the start of a structured line: demote the structure instead of eating a marker.
            if text.isEmpty, tv.selectedRange.length == 0 {
                if let edit = DocumentAction.backspaceEdit(text: tv.text, selection: tv.selectedRange),
                   apply(edit, to: tv) {
                    return false
                }
            }
            return true
        }

        func textViewDidChange(_ tv: UITextView) {
            // Never restyle mid-composition — reapplying attributes during marked text (Telugu/Hindi and
            // other IME) can disrupt the composing session. Styling runs once composition commits.
            if tv.markedTextRange == nil { restyle(tv) }
            syncBindings(tv)
            // Straight off the text view rather than waiting for the binding to come back around, so
            // the first keystroke takes the placeholder with it.
            page?.refreshPlaceholder()
        }

        /// The edit menu gains **Paste as Code** and **Paste as Preformatted** whenever the pasteboard
        /// holds text.
        ///
        /// The system menu is where they belong and the only place they could go: a button on the
        /// writing toolbar is the formatting bar §1 forbids, and a sheet of its own is the editor §7
        /// excludes. This is the menu the writer already opens to paste — two more verbs in it, next to
        /// the verb they were reaching for.
        ///
        /// Two rather than one because a clipboard carrying only plain text has thrown away two
        /// different things, and they want different answers. "This is a program" gets a language label
        /// and syntax colour; "this is a drawing I aligned by hand" gets neither and must simply be left
        /// alone. Neither is ever inferred — that is the whole reason both verbs exist (RULES.md §4).
        ///
        /// `hasStrings` rather than reading the clipboard: asking whether text exists does not open the
        /// pasteboard, so building a menu never shows iOS's paste prompt and never reads a single
        /// character the writer did not ask us to (RULES.md §3).
        func textView(_ tv: UITextView, editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard UIPasteboard.general.hasStrings, let body = tv as? StructuredTextView else { return nil }
            let code = UIAction(title: "Paste as Code") { [weak body] _ in
                body?.pasteAsCode()
            }
            let preformatted = UIAction(title: "Paste as Preformatted") { [weak body] _ in
                body?.pasteAsPreformatted()
            }
            return UIMenu(children: suggestedActions + [code, preformatted])
        }

        func textViewDidChangeSelection(_ tv: UITextView) {
            // Never let the caret land inside a hidden marker — snap it to the line's content start.
            //
            // *Inside* includes the marker's own first character, which is the line start. That is not
            // a pedantic boundary: it is exactly where UIKit puts the caret. Marker glyphs have zero
            // advancement, so every point in the 28-point list gutter resolves to the line start, and
            // so does moving one character right from the end of the line above. Left alone there, the
            // next keystroke inserted *in front of* the marker — "- Eggs" became the literal text
            // "X- Eggs", the bullet gone and an internal marker on screen (RULES.md §4).
            //
            // A caret only. A selection that starts at a line start means "this whole line", marker
            // included, and snapping it forward would shear the structure off a copied item
            // (`StructuredTextExport.copyRange`).
            let selection = tv.selectedRange
            if selection.length == 0 {
                let doc = MarkupDocument(tv.text)
                let line = doc.line(containingSource: selection.location)
                if line.markerLength > 0, selection.location < line.contentStart {
                    let snapped = NSRange(location: line.contentStart, length: 0)
                    if snapped != tv.selectedRange { tv.selectedRange = snapped }
                }
                // And never inside a link's hidden syntax, for the same reason and by the same rule —
                // it leaves the way it came in, so stepping through a link from either side lands on
                // the words rather than in the brackets around them.
                if let escape = doc.caretEscapingHiddenSyntax(
                    from: tv.selectedRange.location,
                    movingForward: tv.selectedRange.location >= previousCaret
                ) {
                    let moved = NSRange(location: escape, length: 0)
                    if moved != tv.selectedRange { tv.selectedRange = moved }
                }
            }
            // A hidden delimiter row is not a place either. It has no glyphs and no height of its own,
            // so a caret left there would be invisible — and the next keystroke would land inside the
            // row that tells the parser where the header is, turning `| --- |` into a data row and the
            // table back into prose (RULES.md §7, amended 2026-08-23).
            if tv.selectedRange.length == 0,
               let escape = TableBlock.caretEscape(in: tv.text, from: tv.selectedRange.location,
                                                   movingForward: tv.selectedRange.location >= previousCaret) {
                let moved = NSRange(location: escape, length: 0)
                if moved != tv.selectedRange { tv.selectedRange = moved }
            }
            // A fence line is not a place either, and since 2026-08-24 it has no glyphs while the block
            // is being edited — so a caret left on one is invisible, and the next keystroke would land
            // inside ```` ```python ```` and break the block back into prose (RULES.md §7).
            if tv.selectedRange.length == 0,
               let escape = CodeBlock.caretEscape(in: tv.text, from: tv.selectedRange.location,
                                                  movingForward: tv.selectedRange.location >= previousCaret) {
                let moved = NSRange(location: escape, length: 0)
                if moved != tv.selectedRange { tv.selectedRange = moved }
            }
            previousCaret = tv.selectedRange.location

            // The caret can reach an empty last line without any text change at all — by tapping, or by
            // opening a note that already ends in one — so this cannot live in `restyle` alone.
            syncTypingAttributes(tv)
            if parent.selectedRange != tv.selectedRange { parent.selectedRange = tv.selectedRange }

            // Moving the caret is what puts a block into — and out of — its source form, and no text
            // changed, so nothing else would redraw it. Deliberately narrow: only while the keyboard is
            // up, only in a note that actually holds a block, and only when the caret changed line.
            // Restyle reassigns the selection, which re-enters here; by then the stored value matches
            // and this stops.
            guard tv.isFirstResponder else { return }
            let text = tv.text as NSString
            guard tv.text.contains(CodeBlock.fence) || tv.text.contains("|") else { return }
            let lines = StructuredText.lineIndices(touchedBy: tv.selectedRange, in: text)
            if renderedSourceLines != .some(.some(lines)) { restyle(tv) }
        }

        /// Taking the keyboard puts the tables back into words. The restyle has to happen *here* rather
        /// than from the focus binding: SwiftUI would deliver that a runloop turn later, and the writer
        /// would spend that turn looking at a card their caret was already inside.
        func textViewDidBeginEditing(_ tv: UITextView) {
            restyle(tv)
            if !parent.isFocused { parent.isFocused = true }
        }

        /// Giving it up puts them back into tables.
        func textViewDidEndEditing(_ tv: UITextView) {
            restyle(tv)
            if parent.isFocused { parent.isFocused = false }
        }

        // MARK: The page scrolling as one

        /// The date and the title ride the body's scroll. `UIScrollViewDelegate` is part of
        /// `UITextViewDelegate`, so the text view already reports its offset here — and it reports it
        /// during its own layout pass, which is what keeps the header locked to the words.
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            page?.syncChromeToScroll()
        }

        // MARK: Title

        @objc func titleChanged(_ field: UITextField) {
            let value = field.text ?? ""
            if parent.title.wrappedValue != value { parent.title.wrappedValue = value }
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            if !parent.titleFocused.wrappedValue { parent.titleFocused.wrappedValue = true }
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            if parent.titleFocused.wrappedValue { parent.titleFocused.wrappedValue = false }
            parent.titleEditingEnded()
        }

        /// Done on the title hands the caret to the body — the note's title is one line, and the next
        /// thing the writer wants is the note.
        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            page?.textView.becomeFirstResponder()
            return false
        }

        // MARK: Checkbox tapping

        /// The table whose preview card is under `point` — the only tap on a table that means something
        /// other than "put the caret here". See `TableCardPresenter.previewTable(at:in:)`.
        private func tappedTable(in tv: UITextView, at point: CGPoint) -> TableBlock? {
            // No longer gated on the keyboard being down: a preview card is on the page while the note
            // is being edited too, and it is still holding rows back, so it still opens the reader.
            tableCards.previewTable(at: point, in: tv)
        }

        /// How many lines either side of the touched one can hold a box whose band reaches it. The
        /// band grows at most `checkboxHitHeight / 2` past a line's own centre and no line of type is
        /// shorter than about twelve points, so two would do; four is free and leaves room for the
        /// smallest text sizes. Bounded on purpose — a tap must not walk a ten-thousand-line note.
        private static let hitSearchRadius = 4

        /// The checklist item a touch at `point` (in text-view coordinates) operates, if any.
        ///
        /// **Horizontally** the target is `StructuredTextStyle.checkboxHitWidth`, wider than the
        /// gutter the box is drawn in. Only a checklist line ever claims that width — every other kind
        /// returns `nil` here — so a bullet's gutter is unchanged and a tap in a paragraph still just
        /// places the caret.
        ///
        /// **Vertically** the target is `checkboxHitHeight`, which is taller than the line it belongs
        /// to. Neighbouring bands therefore overlap, and an overlap is only acceptable if it resolves
        /// to exactly one item every time. It does, by two rules:
        ///
        ///  1. A touch inside an item's **own line** is that item's. Lines never overlap each other,
        ///     so this alone answers every touch in a run of adjacent checklist items: the item you
        ///     touched is the item that ticks, and no neighbour can take it.
        ///  2. Anywhere else — the space above the first line, below the last, or inside a line that
        ///     is not a checklist item — the nearest item wins, measured to the edge of its line.
        ///     Ties go to the earlier item, so the boundary between two bands is decided rather than
        ///     left to floating-point luck.
        ///
        /// How far a band may reach into a *neighbouring* line is capped at half that line's height,
        /// unless the neighbour is another checklist item — overlapping one of those costs nothing,
        /// because rule 1 has already given that space away. So the paragraph under a checklist keeps
        /// the half of itself its own words sit in, and stays tappable for a caret.
        func checkboxLine(in tv: UITextView, at point: CGPoint) -> MarkupDocument.Line? {
            let inset = tv.textContainerInset
            let local = CGPoint(x: point.x - inset.left, y: point.y - inset.top)
            guard local.x <= StructuredTextStyle.checkboxHitWidth else { return nil }

            let doc = MarkupDocument(tv.text)
            guard !doc.lines.isEmpty else { return nil }
            let glyphIndex = tv.layoutManager.glyphIndex(for: local, in: tv.textContainer)
            let charIndex = tv.layoutManager.characterIndexForGlyph(at: glyphIndex)
            let anchor = doc.lineIndex(containingSource: charIndex)

            var winner: (line: MarkupDocument.Line, distance: CGFloat)?
            let first = max(0, anchor - Self.hitSearchRadius)
            let last = min(doc.lines.count - 1, anchor + Self.hitSearchRadius)
            for index in first...last {
                guard case .checklist = doc.lines[index].kind,
                      let line = lineExtent(at: index, in: doc, of: tv),
                      hitBand(around: line, at: index, in: doc, of: tv).contains(local.y)
                else { continue }
                // Zero inside the line itself, which is what makes rule 1 fall out of rule 2 rather
                // than needing a case of its own. Strictly less-than keeps the earlier item on a tie.
                let distance = max(line.lowerBound - local.y, local.y - line.upperBound, 0)
                if winner == nil || distance < winner!.distance {
                    winner = (doc.lines[index], distance)
                }
            }
            return winner?.line
        }

        /// The vertical span a line occupies, in text-container coordinates. Line *fragments* rather
        /// than glyph bounds, because fragments tile the page without gaps — so no touch inside the
        /// text falls between two lines, and two adjacent spans meet exactly at their shared edge.
        private func lineExtent(at index: Int, in doc: MarkupDocument,
                                of tv: UITextView) -> ClosedRange<CGFloat>? {
            let glyphs = tv.layoutManager.glyphRange(forCharacterRange: doc.lines[index].sourceRange,
                                                    actualCharacterRange: nil)
            guard glyphs.length > 0 else { return nil }
            var minY = CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude
            tv.layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in
                minY = Swift.min(minY, rect.minY)
                maxY = Swift.max(maxY, rect.maxY)
            }
            guard maxY > minY else { return nil }
            return minY...maxY
        }

        /// `line` grown towards `checkboxHitHeight`, taking only what the lines either side can spare.
        private func hitBand(around line: ClosedRange<CGFloat>, at index: Int, in doc: MarkupDocument,
                             of tv: UITextView) -> ClosedRange<CGFloat> {
            let deficit = StructuredTextStyle.checkboxHitHeight - (line.upperBound - line.lowerBound)
            guard deficit > 0 else { return line }
            let reach = deficit / 2
            let top = line.lowerBound - allowance(reach, towards: index - 1, in: doc, of: tv)
            let bottom = line.upperBound + allowance(reach, towards: index + 1, in: doc, of: tv)
            return top...bottom
        }

        /// How far a band may grow towards the line at `index`.
        private func allowance(_ reach: CGFloat, towards index: Int, in doc: MarkupDocument,
                               of tv: UITextView) -> CGFloat {
            // Off the end of the note. The space above the first line and below the last belongs to no
            // line at all, so the band may have as much of it as it needs.
            guard doc.lines.indices.contains(index) else { return reach }
            // A checklist neighbour is free to overlap: a touch inside its own line is already its own
            // by rule 1, so reaching across the boundary can never take a touch away from it.
            if case .checklist = doc.lines[index].kind { return reach }
            guard let neighbour = lineExtent(at: index, in: doc, of: tv) else { return reach }
            return min(reach, (neighbour.upperBound - neighbour.lowerBound) / 2)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let tv = gesture.view as? UITextView else { return }
            handleTap(in: tv, at: gesture.location(in: tv))
        }

        /// The tap, in the text view's coordinates. Split from the recognizer so the rules it applies
        /// can be checked with a point rather than with a finger.
        func handleTap(in tv: UITextView, at point: CGPoint) {
            if let table = tappedTable(in: tv, at: point) {
                parent.openTable(table)
                return
            }
            if let url = tappedLink(in: tv, at: point) {
                parent.openLink(url)
                return
            }
            // Under the last thing in a note that ends inside a block: open the paragraph that block
            // left no room for, and put the caret in it.
            if let edit = terminalContinuation(in: tv, at: point) {
                apply(edit, to: tv)
                // A note being *read* has no caret at all, and the point of this tap is to write.
                if !tv.isFirstResponder { tv.becomeFirstResponder() }
                return
            }
            // While recording, the transcript owns the anchor and the body is not editable — a tick then
            // has nowhere to be applied, so the tap does nothing rather than half-happening.
            guard tv.isEditable,
                  let line = checkboxLine(in: tv, at: point),
                  let edit = DocumentAction.toggleChecklistEdit(text: tv.text, sourceOffset: line.sourceRange.location)
            else { return }
            // Ticking an item must not move the caret — only the box changes.
            apply(edit, to: tv, caret: tv.selectedRange)
        }

        /// The edit a tap at `point` would make to write past a block that ends the note, or `nil`.
        ///
        /// Two questions, and both have to be yes: does the note end inside a rendered block
        /// (`DocumentAction.continuePastTerminalBlockEdit`), and is the tap **below** it. The second is
        /// asked of the block's own laid-out lines rather than of its card, because a block being
        /// edited draws only its header there — asking the card would have read every tap on the code
        /// itself as a tap underneath it.
        func terminalContinuation(in tv: UITextView, at point: CGPoint) -> TextEdit? {
            guard tv.isEditable,
                  let edit = DocumentAction.continuePastTerminalBlockEdit(text: tv.text)
            else { return nil }
            let text = tv.text as NSString
            let last = StructuredText.lineIndex(of: text.length, in: text)
            guard let characters = StructuredText.characterRange(ofLines: last...last, in: text)
            else { return nil }
            tv.layoutManager.ensureLayout(for: tv.textContainer)
            let glyphs = tv.layoutManager.glyphRange(forCharacterRange: characters,
                                                    actualCharacterRange: nil)
            var rect = CGRect.null
            tv.layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, _, _ in
                rect = rect.union(fragment)
            }
            guard !rect.isNull else { return nil }
            return point.y > rect.maxY + tv.textContainerInset.top ? edit : nil
        }

        // Our tap begins only when it lands on a checkbox; otherwise the text view's own tap runs.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // The sideways drag: claimed only when it is clearly horizontal *and* it began over a
            // rendered preformatted card that is actually wider than its viewport. Everything short of
            // that declines, and the note scrolls or the caret lands exactly as it always has.
            if gestureRecognizer === cardPan {
                guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                      let tv = pan.view as? UITextView else { return false }
                // Position only. Direction is decided on the first real movement instead, in
                // `handleCardPan` — a pan recognizer is asked this question with **no translation and
                // no velocity yet**, so every direction test here answers against (0, 0) and refuses
                // the gesture forever. That cost an afternoon; the log said `trans=(0.0, 0.0)`.
                return codeCards.horizontallyScrollableCard(at: pan.location(in: tv)) != nil
            }
            guard gestureRecognizer === checkboxTap,
                  let tv = gestureRecognizer.view as? UITextView else { return true }
            let point = gestureRecognizer.location(in: tv)
            return checkboxLine(in: tv, at: point) != nil
                || tappedTable(in: tv, at: point) != nil
                || tappedLink(in: tv, at: point) != nil
                // Only Copy Code is a card's own; every other touch on it falls through and puts the
                // caret in the code, exactly as a tap on a table card does.
                || codeCards.handlesTouch(at: point)
                // Claimed rather than left to the text view: its own tap would resolve a touch under a
                // terminal block to the end of the document — which *is* the closing fence — and the
                // caret would be pushed straight back inside the block it is trying to leave.
                || terminalContinuation(in: tv, at: point) != nil
        }

        /// A wide preformatted card, scrolled sideways under the finger.
        ///
        /// Presentation only — the offset lives on the card's own scroll view and never reaches
        /// `Note.body`. Leaving the note and coming back starts the diagram at its beginning again,
        /// which is where a diagram is read from.
        @objc func handleCardPan(_ pan: UIPanGestureRecognizer) {
            guard let tv = pan.view as? UITextView else { return }
            switch pan.state {
            case .began:
                panningCard = codeCards.horizontallyScrollableCard(at: pan.location(in: tv))
                panIsHorizontal = nil                       // undecided until the finger says so

            case .changed:
                guard let card = panningCard else { return }

                // Decide once, on the first movement large enough to have a direction, and never
                // revisit it — a drag that changes its mind halfway would make the diagram and the page
                // trade the gesture back and forth under the finger.
                if panIsHorizontal == nil {
                    let travelled = pan.translation(in: tv)
                    guard max(abs(travelled.x), abs(travelled.y)) >= CardPanRule.minimumTravel else {
                        return                              // still nothing to go on
                    }
                    panIsHorizontal = CardPanRule.claimsGesture(translation: travelled, canScroll: true)
                    // Not ours: let go entirely. The note has been scrolling alongside us the whole
                    // time (the recognizers run simultaneously), so nothing needs handing back.
                    if panIsHorizontal == false { panningCard = nil; return }
                    pan.setTranslation(.zero, in: tv)
                }

                guard panIsHorizontal == true else { return }
                // Dragging left reveals what is further right, so the offset moves against the finger.
                card.scrollHorizontally(by: -pan.translation(in: tv).x)
                pan.setTranslation(.zero, in: tv)

            default:
                panningCard = nil
                panIsHorizontal = nil
            }
        }

        /// The sideways drag runs alongside the text view's own recognizers rather than replacing them.
        ///
        /// It has already refused every gesture that is not clearly horizontal over a scrollable card,
        /// so what is left cannot be a page scroll or a caret placement — and letting them coexist is
        /// how nested scroll views behave everywhere else on iOS.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            gestureRecognizer === cardPan || other === cardPan
        }
    }
}

/// UITextView whose backing store holds the raw source (with markers), so both VoiceOver and the
/// pasteboard must be given the *visible* text instead — never "pound", "dash bracket", "# Shopping".
/// Copy/cut additionally attach a private representation carrying the raw source, so structure survives
/// a copy/paste that stays inside As Told (RULES.md §4, docs/02-features.md Milestone A).
final class StructuredTextView: UITextView {
    /// Builds the TextKit 1 stack the structured editor needs: a custom layout manager that hides source
    /// markers and draws the visible list glyphs.
    static func make() -> StructuredTextView {
        let storage = NSTextStorage()
        let layoutManager = StructuredLayoutManager()
        layoutManager.accentColor = UIColor(Color.ds.accent)
        layoutManager.markerColor = UIColor(Color.ds.textSecondary)
        layoutManager.codeFill = UIColor(Color.ds.codeSurface)
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        return StructuredTextView(frame: .zero, textContainer: container)
    }

    // MARK: Copy / cut / paste

    override func copy(_ sender: Any?) {
        writeSelectionToPasteboard()
    }

    override func cut(_ sender: Any?) {
        // Cutting a visibly complete list item takes its hidden marker with it, leaving no orphan.
        let range = StructuredTextExport.copyRange(in: text, selection: selectedRange)
        writeSelectionToPasteboard()
        let edit = TextEdit(range: range, string: "", selection: NSRange(location: range.location, length: 0))
        (delegate as? BodyTextView.Coordinator)?.apply(edit, to: self)
    }

    override func paste(_ sender: Any?) {
        // The pasteboard carries the same content in several flavors; the richest one that states
        // structure As Told already supports wins, and a clipboard that states none falls through to
        // the system's own plain-text paste, exactly as before (`RichPasteImport`).
        #if DEBUG
        RichPasteImport.logFlavors(of: .general)
        #endif
        guard let structured = RichPasteImport.source(from: .general), !structured.isEmpty,
              let coordinator = delegate as? BodyTextView.Coordinator
        else {
            // Nothing on the pasteboard stated structure. This is the one point in the app where
            // structure may be *inferred* rather than translated, and only for the two things a
            // detector can be certain about (RULES.md §4, amended 2026-08-24 for code and 2026-08-25
            // for diagrams). Anything short of certain falls through to the system's plain-text paste,
            // exactly as it always has, with **Paste as Code** and **Paste as Preformatted** as the
            // writer's manual overrides.
            //
            // Code is asked first and diagrams second, and they are built not to overlap: `CodeDetection`
            // answers only for the eight languages it can colour, and `PreformattedDetection` requires
            // real box-drawing characters, which no program contains.
            if let coordinator = delegate as? BodyTextView.Coordinator,
               let plain = UIPasteboard.general.string {
                if let match = CodeDetection.detect(plain),
                   let edit = DocumentAction.pasteAsCodeEdit(plain, language: match.language,
                                                             text: text, selection: selectedRange),
                   coordinator.apply(edit, to: self) {
                    return
                }
                // A diagram pasted as prose is not a disappointment, it is unreadable: proportional
                // type throws its columns out and the first wrap breaks its arrows. That asymmetry is
                // the whole justification for inferring it at all.
                if PreformattedDetection.isDiagram(plain),
                   let edit = DocumentAction.pasteAsPreformattedEdit(plain, text: text,
                                                                     selection: selectedRange),
                   coordinator.apply(edit, to: self) {
                    return
                }
            }
            super.paste(sender)
            return
        }

        let edit = DocumentAction.pasteEdit(structured, text: text, selection: selectedRange)
        if !coordinator.apply(edit, to: self) { super.paste(sender) }
    }

    /// **Paste as Code** — the clipboard's characters, fenced, as a block.
    ///
    /// The one thing As Told will not do is decide on its own that four lines of text are a program
    /// (RULES.md §7). This is the other half of that rule: a clipboard that states nothing is left
    /// alone, and the person who *knows* it is code has a way to say so. It says nothing about the
    /// language, because nobody stated one.
    func pasteAsCode() {
        guard let coordinator = delegate as? BodyTextView.Coordinator,
              let pasted = UIPasteboard.general.string,
              let edit = DocumentAction.pasteAsCodeEdit(pasted, text: text, selection: selectedRange)
        else { return }
        _ = coordinator.apply(edit, to: self)
    }

    /// **Paste as Preformatted** — the clipboard's characters, fenced as plain text, as a block.
    ///
    /// The sibling of `pasteAsCode()`, for the case that made it necessary: an ASCII diagram, a
    /// directory tree, a column of aligned figures. Its alignment is the whole content and a plain-text
    /// clipboard carries no way to say so. As Told does not read the characters and decide they are a
    /// drawing — there is no ASCII-art detector and there is not going to be one, because a note
    /// rewritten into a diagram nobody asked for is the failure this app exists not to have
    /// (RULES.md §4). This is the person who knows saying so.
    func pasteAsPreformatted() {
        guard let coordinator = delegate as? BodyTextView.Coordinator,
              let pasted = UIPasteboard.general.string,
              let edit = DocumentAction.pasteAsPreformattedEdit(pasted, text: text,
                                                                selection: selectedRange)
        else { return }
        _ = coordinator.apply(edit, to: self)
    }

    /// Writes what the reader sees for other apps, plus the raw source under a private type for As Told.
    private func writeSelectionToPasteboard() {
        let selection = selectedRange
        guard selection.length > 0 else { return }

        var item: [String: Any] = [
            UTType.utf8PlainText.identifier: StructuredTextExport.plainText(from: text, range: selection)
        ]
        // Only when the selection actually carries a link. A note without one copies exactly as it
        // always has — no new flavor on the pasteboard to change what a receiving app decides to take.
        if let html = StructuredTextExport.html(from: text, range: selection) {
            item[UTType.html.identifier] = html
        }
        if let structured = StructuredTextExport.structuredText(from: text, range: selection) {
            item[StructuredTextExport.pasteboardType] = Data(structured.utf8)
        }
        UIPasteboard.general.setItems([item])
    }

    // MARK: VoiceOver

    override var accessibilityValue: String? {
        get {
            #if DEBUG
            // UI tests need to observe the raw source (markers included); opt in explicitly so normal
            // VoiceOver behavior is unaffected.
            if ProcessInfo.processInfo.arguments.contains("-exposeSourceForTests") { return text }
            #endif
            return StructuredTextExport.spokenText(text)
        }
        set { super.accessibilityValue = newValue }
    }

    /// One action per checklist item, so a box can be ticked without a touch landing in its gutter.
    ///
    /// VoiceOver could already *hear* the state — `spokenText` reads "Unchecked, Call Ravi" — but the
    /// only way to change it was a tap inside a 44-point band, which is not something a rotor can aim.
    /// Hearing a control you cannot work is not access to it (RULES.md §4).
    ///
    /// Each action **names its own item** ("Check Call Ravi") rather than acting on wherever a cursor
    /// happens to be. A note being read has no caret at all — it opens with the keyboard down — so a
    /// caret-relative action would have ticked the first line of the note every time. Naming the item
    /// also means the reader hears which box they are about to change before they change it.
    ///
    /// The names are the **visible** words. The stored `- [ ] ` is never spoken, here or anywhere else.
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            // While a recording owns the anchor the body is not editable and a tick has nowhere to be
            // applied — exactly the state in which `handleTap` does nothing rather than half-happen.
            guard isEditable else { return super.accessibilityCustomActions }
            let ns = text as NSString
            let actions: [UIAccessibilityCustomAction] = MarkupDocument(text).lines.compactMap { line in
                guard case .checklist(let checked) = line.kind else { return nil }
                let content = ns.substring(with: NSRange(location: line.contentStart,
                                                        length: line.contentLength))
                let offset = line.sourceRange.location
                let name = (checked ? "Uncheck " : "Check ") + Self.spoken(content)
                return UIAccessibilityCustomAction(name: name) {
                    [weak self] _ in self?.toggleChecklistItem(atSource: offset) ?? false
                }
            }
            return actions.isEmpty ? super.accessibilityCustomActions : actions
        }
        set { super.accessibilityCustomActions = newValue }
    }

    /// Ticks the item starting at `offset`, through the same edit a tap on its box makes.
    ///
    /// Deliberately the *same* call — `DocumentAction.toggleChecklistEdit` into the coordinator's edit
    /// primitive — and not a second implementation that happens to agree today. One undo step, the
    /// caret left where it was, and the two ways of reaching a checkbox cannot drift apart.
    ///
    /// The offset is captured when the actions are built, and stays valid: both markers are the same
    /// length, so ticking a box moves nothing after it, and an offset that has stopped being a
    /// checklist line makes `toggleChecklistEdit` return `nil` rather than edit the wrong text.
    private func toggleChecklistItem(atSource offset: Int) -> Bool {
        guard isEditable,
              let coordinator = delegate as? BodyTextView.Coordinator,
              let edit = DocumentAction.toggleChecklistEdit(text: text, sourceOffset: offset),
              coordinator.apply(edit, to: self, caret: selectedRange)
        else { return false }
        // `accessibilityValue` is derived from the text, so it is already right — but a value nobody
        // is told about is a change the reader has to go and look for. Say the item and its new state,
        // in the same words the note itself would have used.
        let line = MarkupDocument(text).line(containingSource: offset)
        let content = (text as NSString).substring(with: NSRange(location: line.contentStart,
                                                                length: line.contentLength))
        UIAccessibility.post(notification: .announcement,
                             argument: line.kind.spokenMarker + Self.spoken(content))
        return true
    }

    /// An item's words, or what to call one that has none. Pressing Return on a checklist leaves an
    /// item holding nothing but its marker, and "Check " — a verb and a silence — names nothing a
    /// reader could choose between.
    private static func spoken(_ content: String) -> String {
        content.trimmingCharacters(in: .whitespaces).isEmpty ? "item" : content
    }
}

extension String {
    /// Converts a UTF-16 offset (as used by NSRange/UITextView) to a Character offset for the pure
    /// insertion logic. Clamps into range.
    func characterOffset(fromUTF16 utf16Offset: Int) -> Int {
        let clamped = max(0, min(utf16Offset, utf16.count))
        guard let u16 = utf16.index(utf16.startIndex, offsetBy: clamped, limitedBy: utf16.endIndex),
              let idx = u16.samePosition(in: self) else {
            return count
        }
        return distance(from: startIndex, to: idx)
    }

    /// Converts a Character offset back to the UTF-16 offset UITextView needs for the caret.
    func utf16Offset(fromCharacter characterOffset: Int) -> Int {
        let clamped = max(0, min(characterOffset, count))
        let idx = index(startIndex, offsetBy: clamped)
        return utf16.distance(from: utf16.startIndex, to: idx.samePosition(in: utf16)!)
    }
}

extension UITextView {
    /// The `UITextRange` for a UTF-16 source range, or `nil` when it falls outside the document.
    func textRange(for range: NSRange) -> UITextRange? {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length)
        else { return nil }
        return textRange(from: start, to: end)
    }
}
