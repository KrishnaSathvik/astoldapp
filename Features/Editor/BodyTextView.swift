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
    /// Shown while the body is empty. Empty means "no placeholder".
    var bodyPlaceholder: String = ""

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> NotePageView {
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
        context.coordinator.restyle(tv)

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
                    if isFocused, isEditable, !tv.isFirstResponder { tv.becomeFirstResponder() }
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
        if field.text != title.wrappedValue { field.text = title.wrappedValue }
        if field.isEnabled != isEditable { field.isEnabled = isEditable }
        if field.keyboardAppearance != keyboardAppearance {
            field.keyboardAppearance = keyboardAppearance
            if field.isFirstResponder { field.reloadInputViews() }
        }

        let wantsFocus = titleFocused.wrappedValue
        if isEditable, wantsFocus, !field.isFirstResponder {
            DispatchQueue.main.async {
                if wantsFocus, !field.isFirstResponder { field.becomeFirstResponder() }
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

        /// Re-applies structure styling (attributes only — never characters), preserving the selection.
        func restyle(_ tv: UITextView) {
            let selection = tv.selectedRange
            StructuredTextStyler.apply(to: tv.textStorage, textColor: UIColor(Color.ds.textPrimary))
            tv.selectedRange = selection
            syncTypingAttributes(tv)
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
            let selection = tv.selectedRange
            if selection.length == 0 {
                let doc = MarkupDocument(tv.text)
                let line = doc.line(containingSource: selection.location)
                if line.markerLength > 0,
                   selection.location > line.sourceRange.location,
                   selection.location < line.contentStart {
                    let snapped = NSRange(location: line.contentStart, length: 0)
                    if snapped != tv.selectedRange { tv.selectedRange = snapped }
                }
            }
            // The caret can reach an empty last line without any text change at all — by tapping, or by
            // opening a note that already ends in one — so this cannot live in `restyle` alone.
            syncTypingAttributes(tv)
            if parent.selectedRange != tv.selectedRange { parent.selectedRange = tv.selectedRange }
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
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
        }

        /// Done on the title hands the caret to the body — the note's title is one line, and the next
        /// thing the writer wants is the note.
        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            page?.textView.becomeFirstResponder()
            return false
        }

        // MARK: Checkbox tapping

        /// The checklist line whose checkbox gutter contains `point` (in text-view coordinates), if any.
        private func checkboxLine(in tv: UITextView, at point: CGPoint) -> MarkupDocument.Line? {
            let inset = tv.textContainerInset
            let local = CGPoint(x: point.x - inset.left, y: point.y - inset.top)
            guard local.x <= StructuredTextStyle.listIndent else { return nil }
            let glyphIndex = tv.layoutManager.glyphIndex(for: local, in: tv.textContainer)
            let charIndex = tv.layoutManager.characterIndexForGlyph(at: glyphIndex)
            let line = MarkupDocument(tv.text).line(containingSource: charIndex)
            if case .checklist = line.kind { return line }
            return nil
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // While recording, the transcript owns the anchor and the body is not editable — a tick then
            // has nowhere to be applied, so the tap does nothing rather than half-happening.
            guard let tv = gesture.view as? UITextView, tv.isEditable,
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
            return checkboxLine(in: tv, at: point) != nil
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
            return MarkupDocument(text).visibleText()
        }
        set { super.accessibilityValue = newValue }
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
