import Testing
import Foundation
import SwiftData
@testable import Yourly

@MainActor
struct NoteCalendarQueryTests {
    private func makeStore() throws -> SwiftDataNoteStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return SwiftDataNoteStore(context: ModelContext(container))
    }

    private var cal: Calendar { .current }
    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func notesOnDayReturnsOnlyThatDay() throws {
        let store = try makeStore()
        let a = try store.createDraft(); a.body = "morning"; a.createdAt = day(2026, 8, 17, 8); try store.save(a)
        let b = try store.createDraft(); b.body = "evening"; b.createdAt = day(2026, 8, 17, 22); try store.save(b)
        let c = try store.createDraft(); c.body = "other";   c.createdAt = day(2026, 8, 16, 12); try store.save(c)

        let onDay = try store.notes(on: day(2026, 8, 17))
        #expect(onDay.count == 2)
        #expect(onDay.map(\.body) == ["evening", "morning"])   // newest first
    }

    @Test func noteDaysCollapsesMultipleSameDayToOne() throws {
        let store = try makeStore()
        for h in [8, 12, 20] {
            let n = try store.createDraft(); n.body = "n"; n.createdAt = day(2026, 8, 17, h); try store.save(n)
        }
        let other = try store.createDraft(); other.body = "o"; other.createdAt = day(2026, 8, 15, 9); try store.save(other)

        let days = try store.noteDays(in: day(2026, 8, 1))
        #expect(days.count == 2)                                   // Aug 17 and Aug 15 only
        #expect(days.contains(cal.startOfDay(for: day(2026, 8, 17))))
        #expect(days.contains(cal.startOfDay(for: day(2026, 8, 15))))
    }

    @Test func noteDaysExcludesOtherMonthsAndDeleted() throws {
        let store = try makeStore()
        let inMonth = try store.createDraft(); inMonth.body = "in"; inMonth.createdAt = day(2026, 8, 10); try store.save(inMonth)
        let nextMonth = try store.createDraft(); nextMonth.body = "next"; nextMonth.createdAt = day(2026, 9, 3); try store.save(nextMonth)
        let deleted = try store.createDraft(); deleted.body = "del"; deleted.createdAt = day(2026, 8, 20); try store.save(deleted)
        try store.delete(deleted)

        let days = try store.noteDays(in: day(2026, 8, 1))
        #expect(days == [cal.startOfDay(for: day(2026, 8, 10))])
    }
}
