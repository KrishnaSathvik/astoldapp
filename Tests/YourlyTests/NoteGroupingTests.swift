import Testing
import Foundation
@testable import Yourly

struct NoteGroupingTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }

    @Test func labelsTodayAndYesterday() {
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        #expect(dayLabel(for: today, calendar: cal, now: today) == "Today")
        #expect(dayLabel(for: yesterday, calendar: cal, now: today) == "Yesterday")
    }

    @Test func sameCalendarDayGroupsTogetherAcrossHours() {
        let late = cal.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 23, minute: 30))!
        let early = cal.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 0, minute: 30))!
        #expect(cal.startOfDay(for: late) == cal.startOfDay(for: early))
    }

    @Test func groupsPreserveNewestFirstOrder() {
        let n1 = Note(body: "a", createdAt: cal.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 9))!)
        let n2 = Note(body: "b", createdAt: cal.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 9))!)
        let n3 = Note(body: "c", createdAt: cal.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 8))!)
        let groups = groupedByDay([n1, n2, n3], calendar: cal)
        #expect(groups.count == 2)                               // Aug 17 and Aug 15
        #expect(groups.first?.notes.map(\.body) == ["a", "c"])   // same-day order preserved
        #expect(groups.last?.notes.map(\.body) == ["b"])
    }

    @Test func olderYearIncludesYear() {
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 17))!
        let lastYear = cal.date(from: DateComponents(year: 2025, month: 8, day: 17))!
        let label = dayLabel(for: lastYear, calendar: cal, now: now)
        #expect(label.contains("2025"))
    }
}
