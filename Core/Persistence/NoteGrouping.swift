import Foundation

/// A day bucket of notes for the Home timeline. `day` is startOfDay.
struct NoteDayGroup: Identifiable {
    let day: Date
    let notes: [Note]
    var id: Date { day }
}

/// Localized Today / Yesterday / formatted date. Uses Calendar semantics — never 24h math.
/// See docs/05-architecture.md §9 and RULES.md §5.
func dayLabel(for date: Date, calendar: Calendar = .current, now: Date = .now) -> String {
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }
    let df = DateFormatter()
    df.calendar = calendar
    df.locale = .current
    let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
    df.setLocalizedDateFormatFromTemplate(sameYear ? "MMMMd" : "MMMMd yyyy")
    return df.string(from: date)
}

/// Groups notes (already newest-first) into day buckets, preserving order within and across days.
func groupedByDay(_ notes: [Note], calendar: Calendar = .current) -> [NoteDayGroup] {
    var order: [Date] = []
    var buckets: [Date: [Note]] = [:]
    for note in notes {
        let day = calendar.startOfDay(for: note.createdAt)
        if buckets[day] == nil { order.append(day) }
        buckets[day, default: []].append(note)
    }
    return order.map { NoteDayGroup(day: $0, notes: buckets[$0]!) }
}
