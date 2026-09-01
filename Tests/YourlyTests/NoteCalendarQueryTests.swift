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

    /// One entry per day, whatever time the notes were written — and the **count** of them, which is
    /// what the grid's density dots are drawn from (changed 2026-08-31 from a bare `Set<Date>`; the
    /// fetch and the visibility rule are unchanged, only the projection is richer).
    @Test func noteDayCountsCollapsesMultipleSameDayToOneEntry() throws {
        let store = try makeStore()
        for h in [8, 12, 20] {
            let n = try store.createDraft(); n.body = "n"; n.createdAt = day(2026, 8, 17, h); try store.save(n)
        }
        let other = try store.createDraft(); other.body = "o"; other.createdAt = day(2026, 8, 15, 9); try store.save(other)

        let counts = try store.noteDayCounts(in: day(2026, 8, 1))
        #expect(counts.count == 2)                                 // Aug 17 and Aug 15 only
        #expect(counts[cal.startOfDay(for: day(2026, 8, 17))] == 3)
        #expect(counts[cal.startOfDay(for: day(2026, 8, 15))] == 1)
    }

    /// The old answer is still exactly derivable, so nothing that only asks *which days* has changed.
    @Test func theDaysWithNotesAreStillTheKeys() throws {
        let store = try makeStore()
        let n = try store.createDraft(); n.body = "n"; n.createdAt = day(2026, 8, 17, 9); try store.save(n)
        let counts = try store.noteDayCounts(in: day(2026, 8, 1))
        #expect(Set(counts.keys) == [cal.startOfDay(for: day(2026, 8, 17))])
    }

    /// A day with nothing on it is **absent**, not zero — so a cell never asks for dots it should
    /// not draw.
    @Test func aDayWithNoNotesHasNoEntry() throws {
        let store = try makeStore()
        let n = try store.createDraft(); n.body = "n"; n.createdAt = day(2026, 8, 17, 9); try store.save(n)
        let counts = try store.noteDayCounts(in: day(2026, 8, 1))
        #expect(counts[cal.startOfDay(for: day(2026, 8, 18))] == nil)
    }

    @Test func noteDayCountsExcludeOtherMonthsAndDeleted() throws {
        let store = try makeStore()
        let inMonth = try store.createDraft(); inMonth.body = "in"; inMonth.createdAt = day(2026, 8, 10); try store.save(inMonth)
        let nextMonth = try store.createDraft(); nextMonth.body = "next"; nextMonth.createdAt = day(2026, 9, 3); try store.save(nextMonth)
        let deleted = try store.createDraft(); deleted.body = "del"; deleted.createdAt = day(2026, 8, 20); try store.save(deleted)
        try store.delete(deleted)

        let days = Set((try store.noteDayCounts(in: day(2026, 8, 1))).keys)
        #expect(days == [cal.startOfDay(for: day(2026, 8, 10))])
    }
}
