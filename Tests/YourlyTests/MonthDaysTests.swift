import Testing
import Foundation
@testable import Yourly

struct MonthDaysTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        c.firstWeekday = 1   // Sunday
        return c
    }

    @Test func startOfMonthIsFirstDay() {
        let d = cal.date(from: DateComponents(year: 2026, month: 8, day: 17))!
        let som = MonthMath.startOfMonth(for: d, calendar: cal)
        #expect(cal.component(.day, from: som) == 1)
        #expect(cal.component(.month, from: som) == 8)
    }

    @Test func monthRolloverDecToJan() {
        let dec = cal.date(from: DateComponents(year: 2026, month: 12, day: 10))!
        let jan = MonthMath.addMonths(1, to: dec, calendar: cal)
        #expect(cal.component(.year, from: jan) == 2027)
        #expect(cal.component(.month, from: jan) == 1)
    }

    @Test func monthRollbackJanToDec() {
        let jan = cal.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let dec = MonthMath.addMonths(-1, to: jan, calendar: cal)
        #expect(cal.component(.year, from: dec) == 2025)
        #expect(cal.component(.month, from: dec) == 12)
    }

    @Test func gridCellCountMatchesDaysPlusLeadingBlanks() {
        // August 2026: Aug 1, 2026 is a Saturday → 6 leading blanks (Sun..Fri), 31 days.
        let aug = cal.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let cells = MonthMath.gridCells(for: aug, calendar: cal)
        let blanks = cells.filter { $0.date == nil }.count
        let days = cells.filter { $0.date != nil }.count
        #expect(days == 31)
        #expect(blanks == 6)
    }

    @Test func firstRealCellIsDayOne() {
        let aug = cal.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let cells = MonthMath.gridCells(for: aug, calendar: cal)
        let firstDay = cells.first { $0.date != nil }!.date!
        #expect(cal.component(.day, from: firstDay) == 1)
    }

    @Test func weekdayInitialsCountSeven() {
        #expect(MonthMath.weekdayInitials(calendar: cal).count == 7)
    }
}
