import Foundation

/// A single cell in the month grid. `date == nil` for leading blanks before the 1st.
struct MonthCell: Identifiable {
    let id: Int          // grid index
    let date: Date?      // startOfDay, or nil for a blank pad cell
}

/// Calendar-based month math — never manual 24h arithmetic (RULES.md §5, docs/05-architecture.md §9).
enum MonthMath {
    static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    static func addMonths(_ n: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: n, to: startOfMonth(for: date, calendar: calendar))!
    }

    /// Grid cells: leading blanks to align the 1st under its weekday, then one cell per day.
    static func gridCells(for month: Date, calendar: Calendar = .current) -> [MonthCell] {
        let first = startOfMonth(for: month, calendar: calendar)
        let range = calendar.range(of: .day, in: .month, for: first)!
        let weekdayOfFirst = calendar.component(.weekday, from: first)          // 1...7
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [MonthCell] = []
        for i in 0..<leadingBlanks { cells.append(MonthCell(id: i, date: nil)) }
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: first)!
            cells.append(MonthCell(id: leadingBlanks + day - 1, date: calendar.startOfDay(for: date)))
        }
        return cells
    }

    /// Localized short weekday symbols starting at the calendar's firstWeekday (e.g. S M T W T F S).
    static func weekdayInitials(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
