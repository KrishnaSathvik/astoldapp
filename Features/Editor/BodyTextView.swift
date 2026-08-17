import SwiftUI
import UIKit

/// UITextView-backed body editor so we know the caret position — voice transcripts insert exactly
/// where the cursor is (docs/04-voice-transcription.md §8). Plain text, no formatting toolbar.
struct BodyTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var isEditable: Bool
    /// Change this token to request first-responder focus (initial appearance, after voice insertion).
    var focusToken: UUID

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.textColor = UIColor(Color.ds.textPrimary)
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.text = text
        context.coordinator.lastFocusToken = focusToken
        DispatchQueue.main.async { if isEditable { tv.becomeFirstResponder() } }
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text {
            tv.text = text
        }
        if tv.isEditable != isEditable {
            tv.isEditable = isEditable
            if !isEditable { tv.resignFirstResponder() }
        }
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            if isEditable { DispatchQueue.main.async { tv.becomeFirstResponder() } }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: BodyTextView
        var lastFocusToken: UUID?
        init(_ parent: BodyTextView) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            parent.selectedRange = tv.selectedRange
        }
        func textViewDidChangeSelection(_ tv: UITextView) {
            parent.selectedRange = tv.selectedRange
        }
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
}
