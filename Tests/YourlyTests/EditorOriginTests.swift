import Testing
import Foundation
@testable import Yourly

// Where Back goes, and what a reader who cannot see it is told.
//
// The editor is pushed from two places — Home and the calendar — onto whichever stack the reader is
// already in, so Back has always *gone* to the right screen. What it said was wrong: a note opened
// from the calendar offered "‹ Notes", which names a screen the tap does not lead to (fixed
// 2026-08-25). The visible word was dropped entirely on 2026-08-26; every origin now draws the
// chevron alone, and the origin survives only to name the destination out loud.
//
// These are assertions about a value. What the navigation bar actually *renders* is a separate
// question and a separate test — `NavigationUITests` asserts on the accessibility tree, because this
// suite passed happily once while the button on screen said the wrong thing.
struct EditorOriginTests {

    @Test func aNoteOpenedFromHomeAnnouncesNotes() {
        #expect(EditorOrigin.notes.backAccessibilityLabel == "Back to notes")
    }

    @Test func aNoteOpenedFromTheCalendarAnnouncesTheCalendar() {
        #expect(EditorOrigin.calendar.backAccessibilityLabel == "Back to calendar")
    }

    @Test func everyOriginNamesADestinationOutLoud() {
        // The chevron carries nothing for a VoiceOver reader, so "Back" alone would not say back to
        // *what*. Each origin must name a screen, and no two origins that lead somewhere different
        // may say the same thing (RULES.md §4).
        let labels = [EditorOrigin.notes, .calendar].map(\.backAccessibilityLabel)
        for label in labels {
            #expect(label.hasPrefix("Back to "))
            #expect(label != "Back to ")
        }
        #expect(Set(labels).count == labels.count, "two origins announce the same destination")
    }

    @Test func homeIsTheDefault() {
        // Every caller that does not say otherwise came from Home, including the compose button —
        // a new note goes back to exactly the screen an existing one does.
        #expect(EditorOrigin.notes == EditorOrigin())
    }

    @Test func theRouteCarriesTheOriginWithTheNote() {
        // The origin rides *inside* the pushed item. Held in a `@State` beside it, it was read one
        // push stale and the editor was handed the wrong origin every time — see `EditorRoute`.
        let note = Note()
        #expect(EditorRoute(note, from: .calendar).origin == .calendar)
        #expect(EditorRoute(note, from: .notes).origin == .notes)
        #expect(EditorRoute(note, from: .calendar) != EditorRoute(note, from: .notes))
    }
}
