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

    /// Applies `style` to every line the body's current selection touches. A no-op before the text
    /// view exists, or while the body is not editable (a recording owns the anchor).
    func apply(_ style: BlockStyle) { applyStyle?(style) }
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

    /// The note's creation date, already formatted. Empty hides the line.
    var dateText: String = ""
    /// The optional note title.
    var title: Binding<String> = .constant("")
    /// Two-way keyboard focus for the title, exactly as `isFocused` is for the body.
    var titleFocused: Binding<Bool> = .constant(false)
    /// Called when a table in the note is tapped while reading — the note hands over the block, and
    /// the editor opens the reader on it. Never while editing: a tap in a table you are writing is a
    /// tap that places the caret, exactly as it does in any other line.
    var openTable: (TableBlock) -> Void = { _ in }
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
        tv.addGestureRecognizer(tap)
        context.coordinator.checkboxTap = tap
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

        context.coordinator.bind(actions, to: tv)

        let page = NotePageView(textView: tv)
        page.dateText = dateText
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
        page.dateText = dateText
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
            let heights = tableCards.plan(for: tv, showsCards: !tv.isFirstResponder)
            StructuredTextStyler.apply(to: tv.textStorage,
                                       textColor: UIColor(Color.ds.textPrimary),
                                       secondaryColor: UIColor(Color.ds.textTertiary),
                                       availableWidth: tv.textContainer.size.width
                                           - tv.textContainer.lineFragmentPadding * 2,
                                       tableCards: heights)
            tv.selectedRange = selection
            syncTypingAttributes(tv)
            tableCards.sync(in: tv, palette: .ds)
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
                let line = MarkupDocument(tv.text).line(containingSource: range.location)
                if line.markerLength > 0, range.location < line.contentStart {
                    let caret = NSRange(location: line.contentStart, length: 0)
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
            }
            // The caret can reach an empty last line without any text change at all — by tapping, or by
            // opening a note that already ends in one — so this cannot live in `restyle` alone.
            syncTypingAttributes(tv)
            if parent.selectedRange != tv.selectedRange { parent.selectedRange = tv.selectedRange }
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
            guard !tv.isFirstResponder else { return nil }
            return tableCards.previewTable(at: point, in: tv)
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
            if let table = tappedTable(in: tv, at: gesture.location(in: tv)) {
                parent.openTable(table)
                return
            }
            // While recording, the transcript owns the anchor and the body is not editable — a tick then
            // has nowhere to be applied, so the tap does nothing rather than half-happening.
            guard tv.isEditable,
                  let line = checkboxLine(in: tv, at: gesture.location(in: tv)),
                  let edit = DocumentAction.toggleChecklistEdit(text: tv.text, sourceOffset: line.sourceRange.location)
            else { return }
            // Ticking an item must not move the caret — only the box changes.
            apply(edit, to: tv, caret: tv.selectedRange)
        }

        // Our tap begins only when it lands on a checkbox; otherwise the text view's own tap runs.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === checkboxTap,
                  let tv = gestureRecognizer.view as? UITextView else { return true }
            let point = gestureRecognizer.location(in: tv)
            return checkboxLine(in: tv, at: point) != nil || tappedTable(in: tv, at: point) != nil
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
            super.paste(sender)
            return
        }

        let edit = DocumentAction.pasteEdit(structured, text: text, selection: selectedRange)
        if !coordinator.apply(edit, to: self) { super.paste(sender) }
    }

    /// Writes what the reader sees for other apps, plus the raw source under a private type for As Told.
    private func writeSelectionToPasteboard() {
        let selection = selectedRange
        guard selection.length > 0 else { return }

        var item: [String: Any] = [
            UTType.utf8PlainText.identifier: StructuredTextExport.plainText(from: text, range: selection)
        ]
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
