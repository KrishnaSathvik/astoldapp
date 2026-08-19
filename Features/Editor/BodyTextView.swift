import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = StructuredTextView.make()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = StructuredTextStyle.bodyFont()
        tv.adjustsFontForContentSizeCategory = true
        tv.textColor = UIColor(Color.ds.textPrimary)
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        tv.keyboardDismissMode = .interactive
        tv.alwaysBounceVertical = true
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

        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self

        if tv.text != text {
            // A voice transcript (or SwiftUI handing us a different note) is a document mutation too:
            // apply it as one native edit so it undoes in one step, with the caret the editor asked for.
            context.coordinator.applyExternalChange(text, caret: selectedRange, to: tv)
        }

        if tv.isEditable != isEditable { tv.isEditable = isEditable }

        // Focus is driven from the editor; guard on the current responder state so this never loops.
        if isEditable, isFocused, !tv.isFirstResponder {
            DispatchQueue.main.async {
                if isFocused, isEditable, !tv.isFirstResponder { tv.becomeFirstResponder() }
            }
        } else if (!isFocused || !isEditable), tv.isFirstResponder {
            DispatchQueue.main.async {
                if !isFocused || !isEditable, tv.isFirstResponder { tv.resignFirstResponder() }
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: BodyTextView
        var checkboxTap: UITapGestureRecognizer?
        /// True while a structural edit is being applied, so our own `replace` never re-enters the
        /// Return/Backspace handling that produced it.
        private var isApplyingEdit = false
        init(_ parent: BodyTextView) { self.parent = parent }

        /// Re-applies structure styling (attributes only — never characters), preserving the selection.
        func restyle(_ tv: UITextView) {
            let selection = tv.selectedRange
            StructuredTextStyler.apply(to: tv.textStorage, textColor: UIColor(Color.ds.textPrimary))
            tv.selectedRange = selection
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

            let length = tv.text.utf16.count
            let target = caret ?? edit.selection
            tv.selectedRange = NSRange(location: min(target.location, length), length: 0)
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
            if parent.selectedRange != tv.selectedRange { parent.selectedRange = tv.selectedRange }
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            if parent.isFocused { parent.isFocused = false }
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
        let pasteboard = UIPasteboard.general
        guard pasteboard.contains(pasteboardTypes: [StructuredTextExport.pasteboardType]),
              let data = pasteboard.data(forPasteboardType: StructuredTextExport.pasteboardType),
              let structured = String(data: data, encoding: .utf8), !structured.isEmpty
        else {
            // Anything from another app is exactly what it looks like: plain text.
            super.paste(sender)
            return
        }

        let edit = DocumentAction.pasteEdit(structured, text: text, selection: selectedRange)
        guard let coordinator = delegate as? BodyTextView.Coordinator, coordinator.apply(edit, to: self) else {
            super.paste(sender)
            return
        }
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
