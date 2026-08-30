import Testing
import Foundation
import UIKit
import SwiftUI
@testable import Yourly

// Colour is never the only signal a link is a link (RULES.md §4).
//
// The underline that carries that guarantee was read once per restyle and never re-read, so turning
// Differentiate Without Color on with a note already open changed nothing until the next keystroke
// happened to pay for a restyle. Dynamic Type had the identical gap and is answered with
// `registerForTraitChanges`; this preference is a notification rather than a trait, so it is answered
// with an observer the coordinator owns.
//
// The preference is read through `Coordinator.differentiatesWithoutColor` — a closure whose only
// reason to exist is this file. A unit test cannot flip the real system setting, so a test that had to
// use it could not prove the restyle responds at all. Production still reads `UIAccessibility`.
@MainActor
struct DifferentiateWithoutColorTests {

    private let source = "Booking is at [Open reservation](https://astold.app) — see you there"

    /// Somewhere inside "Open reservation", which is what the reader sees and what carries the styling.
    private let inTheWords = 16

    private func editor(_ text: String) -> (BodyTextView.Coordinator, UITextView) {
        var body = text
        var range = NSRange(location: 0, length: 0)
        var focused = false
        let parent = BodyTextView(text: Binding(get: { body }, set: { body = $0 }),
                                  selectedRange: Binding(get: { range }, set: { range = $0 }),
                                  isFocused: Binding(get: { focused }, set: { focused = $0 }),
                                  isEditable: true,
                                  keyboardAppearance: .light)
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 360, height: 800)
        tv.textContainer.size = CGSize(width: 360, height: 100_000)
        tv.text = text
        let coordinator = parent.makeCoordinator()
        // Exactly what `makeUIView` does, and the reason the notification means anything here.
        coordinator.observeDifferentiateWithoutColor(for: tv)
        return (coordinator, tv)
    }

    private func underline(_ tv: UITextView, at index: Int) -> Int? {
        tv.textStorage.attribute(.underlineStyle, at: index, effectiveRange: nil) as? Int
    }

    // MARK: The three states

    @Test func aLinkIsNotUnderlinedWhileTheReaderHasNotAskedForMore() {
        let (coordinator, tv) = editor(source)
        coordinator.differentiatesWithoutColor = { false }
        coordinator.restyle(tv)

        #expect(underline(tv, at: inTheWords) == nil)
        // It is still a link — the colour and the destination are doing their work.
        #expect(tv.textStorage.attribute(.astLink, at: inTheWords, effectiveRange: nil) != nil)
    }

    @Test func turningTheSettingOnUnderlinesTheLinkImmediately() {
        let (coordinator, tv) = editor(source)
        var isOn = false
        coordinator.differentiatesWithoutColor = { isOn }
        coordinator.restyle(tv)
        #expect(underline(tv, at: inTheWords) == nil)

        // The setting changes under an open note, and the notification arrives.
        isOn = true
        NotificationCenter.default.post(
            name: UIAccessibility.differentiateWithoutColorDidChangeNotification, object: nil)

        #expect(underline(tv, at: inTheWords) == NSUnderlineStyle.single.rawValue,
                "the link did not gain its underline when the setting was turned on")
    }

    @Test func turningItBackOffRemovesTheUnderline() {
        let (coordinator, tv) = editor(source)
        var isOn = true
        coordinator.differentiatesWithoutColor = { isOn }
        coordinator.restyle(tv)
        #expect(underline(tv, at: inTheWords) == NSUnderlineStyle.single.rawValue)

        isOn = false
        NotificationCenter.default.post(
            name: UIAccessibility.differentiateWithoutColorDidChangeNotification, object: nil)

        #expect(underline(tv, at: inTheWords) == nil,
                "the underline outlived the setting that asked for it")
    }

    // MARK: What a restyle must not cost

    @Test func theNotesOwnCharactersAreNeverTouched() {
        // The whole point of a restyle: attributes only. Nothing here may reach `body`.
        let (coordinator, tv) = editor(source)
        var isOn = false
        coordinator.differentiatesWithoutColor = { isOn }
        coordinator.restyle(tv)

        isOn = true
        NotificationCenter.default.post(
            name: UIAccessibility.differentiateWithoutColorDidChangeNotification, object: nil)

        #expect(tv.text == source)
        #expect(tv.textStorage.string == source)
    }

    @Test func theCaretStaysExactlyWhereItWas() {
        let (coordinator, tv) = editor(source)
        coordinator.differentiatesWithoutColor = { false }
        coordinator.restyle(tv)
        let selection = NSRange(location: 3, length: 7)
        tv.selectedRange = selection

        coordinator.differentiatesWithoutColor = { true }
        NotificationCenter.default.post(
            name: UIAccessibility.differentiateWithoutColorDidChangeNotification, object: nil)

        #expect(tv.selectedRange == selection, "the selection moved during an appearance change")
    }

    @Test func theSettingChangeNeverTakesFocus() {
        // A preference changing is not a reason for the keyboard to appear over somebody's note.
        let (coordinator, tv) = editor(source)
        coordinator.differentiatesWithoutColor = { true }
        #expect(!tv.isFirstResponder)

        NotificationCenter.default.post(
            name: UIAccessibility.differentiateWithoutColorDidChangeNotification, object: nil)

        #expect(!tv.isFirstResponder)
    }

    @Test func aNoteWithNoLinksIsUnaffected() {
        let plain = "Just words, and a dash — nothing to open here"
        let (coordinator, tv) = editor(plain)
        coordinator.differentiatesWithoutColor = { true }
        coordinator.restyle(tv)

        var underlined = false
        tv.textStorage.enumerateAttribute(.underlineStyle,
                                          in: NSRange(location: 0, length: tv.textStorage.length)) {
            value, _, _ in
            if value != nil { underlined = true }
        }
        #expect(!underlined, "prose gained an underline it has no link to justify")
        #expect(tv.text == plain)
    }

    // MARK: Teardown

    @Test func theObserverDiesWithItsCoordinator() {
        // A block-based observer outlives its owner unless it is removed, and a stale one restyling a
        // text view nobody is looking at is a leak with a side effect.
        weak var escaped: BodyTextView.Coordinator?
        do {
            let (coordinator, tv) = editor(source)
            coordinator.observeDifferentiateWithoutColor(for: tv)
            escaped = coordinator
            #expect(escaped != nil)
        }
        #expect(escaped == nil, "the coordinator was kept alive by its own notification observer")
    }

    @Test func registeringTwiceStillLeavesOneObserver() {
        // `makeUIView` runs once, but the guard is what makes that safe to rely on rather than assume.
        let (coordinator, tv) = editor(source)
        var reads = 0
        coordinator.differentiatesWithoutColor = { reads += 1; return true }
        coordinator.observeDifferentiateWithoutColor(for: tv)
        coordinator.observeDifferentiateWithoutColor(for: tv)

        reads = 0
        NotificationCenter.default.post(
            name: UIAccessibility.differentiateWithoutColorDidChangeNotification, object: nil)
        #expect(reads == 1, "the preference was read \(reads) times — the observer registered twice")
    }
}
