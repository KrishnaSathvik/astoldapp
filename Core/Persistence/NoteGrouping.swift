import Foundation

/// A day bucket of notes for the Home timeline. `day` is startOfDay.
struct NoteDayGroup: Identifiable {
    let day: Date
    let notes: [Note]
    var id: Date { day }
}

/// Localized Today / Yesterday / formatted date. Uses Calendar semantics — never 24h math.
/// See docs/05-architecture.md §9 and RULES.md §5.
func dayLabel(for date: Date, calendar: Calendar = .current, now: Date = AppClock.now) -> String {
    // Against `now`, not `isDateInToday`: the two read different clocks once `AppClock` is pinned.
    if calendar.isDate(date, inSameDayAs: now) { return "Today" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
       calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
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

// MARK: - Relative periods (Home)
//
// Home groups by *relative age* rather than by calendar day (RULES.md §1, amended 2026-08-30). Day
// buckets were correct and unscannable: a library of several hundred notes is several hundred rows
// under roughly as many date headings, and the heading stops being information once there is one of
// them per note. Four periods answer the question a reader actually arrives with — roughly when did
// I write this — and collapse the rest.
//
// `groupedByDay` and `dayLabel` are untouched: the calendar's day list still names a single day, and
// that is a different question from browsing a timeline.

/// One relative-age bucket of the Home timeline.
struct NoteTimelineSection: Identifiable {
    /// The four buckets, in the order Home draws them.
    enum Period: Int, CaseIterable {
        case today, previous7Days, previous30Days, older

        var title: String {
            switch self {
            case .today: return "Today"
            case .previous7Days: return "Previous 7 Days"
            case .previous30Days: return "Previous 30 Days"
            case .older: return "Older"
            }
        }
    }

    let period: Period
    let notes: [Note]
    var id: Int { period.rawValue }
    var title: String { period.title }
}

/// Which bucket a date falls in, counted in whole calendar days.
///
/// Calendar arithmetic, never 24-hour math (RULES.md §5): a note written at 23:50 yesterday is one
/// day old across a DST boundary just as it is on any other night. A date that is somehow ahead of
/// `now` lands in `today` rather than falling off the front of the list — a clock that moved
/// backwards must not hide a note.
func timelinePeriod(for date: Date,
                    calendar: Calendar = .current,
                    now: Date = AppClock.now) -> NoteTimelineSection.Period {
    let today = calendar.startOfDay(for: now)
    let day = calendar.startOfDay(for: date)
    let days = calendar.dateComponents([.day], from: day, to: today).day ?? 0
    if days <= 0 { return .today }
    if days <= 7 { return .previous7Days }
    if days <= 30 { return .previous30Days }
    return .older
}

/// Buckets notes (already newest-first) into the four periods, preserving order within each and
/// dropping any period nothing landed in.
///
/// `now` is a parameter rather than a read of the clock inside the loop, so one render pass cannot
/// bucket its first note against one "today" and its last against the next.
func timelineSections(_ notes: [Note],
                      calendar: Calendar = .current,
                      now: Date = AppClock.now) -> [NoteTimelineSection] {
    var buckets: [NoteTimelineSection.Period: [Note]] = [:]
    for note in notes {
        buckets[timelinePeriod(for: note.createdAt, calendar: calendar, now: now), default: []]
            .append(note)
    }
    return NoteTimelineSection.Period.allCases.compactMap { period in
        guard let notes = buckets[period], !notes.isEmpty else { return nil }
        return NoteTimelineSection(period: period, notes: notes)
    }
}

// MARK: - Home's recent library

/// One period as **Home** draws it: capped, with a count of what the cap is holding back.
///
/// Distinct from `NoteTimelineSection` because Home and the full library are answering different
/// questions. `NoteTimelineSection` is the whole of a period; this is the part of it that earns a
/// place on a landing screen (`HomeLibrary`).
struct HomeLibrarySection: Identifiable {
    let period: NoteTimelineSection.Period
    /// The rows drawn right now — the whole period once the reader has expanded it.
    let notes: [Note]
    /// How many the cap is still holding back. Zero when the period is fully drawn.
    let hidden: Int

    /// Whether the reader took this period past its cap on this visit.
    ///
    /// Not the same question as `hidden == 0`. A period that never reached its cap is also fully
    /// drawn, and it has nothing to collapse *back* to — offering it `Show less` would be a control
    /// that removes notes the cap was never holding.
    let isExpanded: Bool

    /// Everything the period holds, drawn or not. What `Show all N` names: the size of the period the
    /// reader can see the top of, not the size of the remainder — "Show all 7" describes a state,
    /// "Show all 3 more" describes a batch, and one of those sounds like pagination.
    var total: Int { notes.count + hidden }

    /// Whether the period draws a toggle at all, in either direction.
    ///
    /// The affordance is **reversible** (2026-08-31): a period the reader opened can be shut again
    /// on the same visit. `Show all N` that only ever went one way turned a fourteen-note `Previous
    /// 7 Days` into a wall with no way back short of leaving Home — which made expanding it feel
    /// like a decision rather than a look.
    var isCollapsible: Bool { hidden > 0 || isExpanded }

    var id: Int { period.rawValue }
    var title: String { period.title }
}

/// What Home shows, and what it deliberately does not.
///
/// **Home is a recent-library surface, not the archive** (changed 2026-08-31 — `RULES.md` §1, and
/// `README.md` §2). It answers *what was I working on recently*; the complete timeline moved to
/// **Browse older notes**, and reaching a date is still the calendar's question and finding a note is
/// still search's.
///
/// The caps exist because a period is not a useful unit of scanning once it is large. Seven untitled
/// voice notes under `Today` are seven rows of transcript at equal weight, which is a wall rather
/// than a library — and the cap turns it back into a glance with an explicit way past it.
///
/// Pure, and separate from the view, so every one of these boundaries is checkable without a screen.
enum HomeLibrary {

    /// The periods Home draws, in order. Everything older is behind **Browse older notes**.
    static let periods: [NoteTimelineSection.Period] = [.today, .previous7Days]

    /// How many rows a period shows before it asks.
    ///
    /// Today gets one fewer: it is the period most likely to be full of a single afternoon's
    /// capturing, and it is the one at the top of the screen, where a wall costs the most.
    static func cap(for period: NoteTimelineSection.Period) -> Int {
        period == .today ? 4 : 5
    }

    /// Home's sections: the recent periods, capped unless the reader has expanded them.
    ///
    /// A period with nothing in it is not drawn at all — an empty `Today` is a heading over nothing,
    /// which is chrome reporting on itself.
    static func sections(_ notes: [Note],
                         calendar: Calendar = .current,
                         now: Date = AppClock.now,
                         expanded: Set<NoteTimelineSection.Period> = []) -> [HomeLibrarySection] {
        let all = timelineSections(notes, calendar: calendar, now: now)
        return periods.compactMap { period in
            guard let section = all.first(where: { $0.period == period }) else { return nil }
            let cap = cap(for: period)
            // Over its cap *and* opened is the only combination that can be shut again. A period of
            // three notes stays a period of three notes whether or not its period is in the set.
            let overCap = section.notes.count > cap
            let showsAll = !overCap || expanded.contains(period)
            return HomeLibrarySection(
                period: period,
                notes: showsAll ? section.notes : Array(section.notes.prefix(cap)),
                hidden: showsAll ? 0 : section.notes.count - cap,
                isExpanded: overCap && expanded.contains(period)
            )
        }
    }

    /// Whether anything at all sits outside the periods Home draws.
    ///
    /// **The one question that decides whether Home offers the archive at all** (2026-08-31). It is
    /// not offered when Home is already showing everything there is: `Show all N` has then already
    /// exposed the complete library, and a second control leading to the same notes one screen
    /// further away is a control with nothing to do. It is deliberately *not* asked whether some
    /// period is currently capped — a cap is a way of looking at notes Home is already holding, and
    /// answering it with a push to another screen is the duplication this check exists to prevent.
    static func hasOlderNotes(_ notes: [Note],
                              calendar: Calendar = .current,
                              now: Date = AppClock.now) -> Bool {
        notes.contains { !periods.contains(timelinePeriod(for: $0.createdAt, calendar: calendar, now: now)) }
    }
}


// MARK: - The calendar's selected day

/// How busy a day looks on the month grid: **0 to 3 dots, never more.**
///
/// A *sense* of activity, not a count. Seven dots for seven notes is a bar chart, a number is a
/// badge, and both turn a calendar into a dashboard — the thing `RULES.md` §1 fences the calendar
/// off from being. Three levels answer the only question the grid is asked from across the screen —
/// *was that a quiet day or a busy one* — and the exact answer is one tap away underneath.
///
/// The dots carry no category and never will: a voice-created note is an ordinary note, and the
/// `Note` model owns no type, colour, or tag for anything here to render (`RULES.md` §2).
enum CalendarDayDensity {

    /// The most dots any day can show.
    static let maxDots = 3

    /// 0 → none · 1 → one · 2–3 → two · 4+ → three.
    ///
    /// A negative count cannot happen and answers zero rather than trapping: a grid cell is not the
    /// place to discover a corrupt count.
    static func dotCount(forNotes count: Int) -> Int {
        switch count {
        case ..<1: return 0
        case 1: return 1
        case 2...3: return 2
        default: return maxDots
        }
    }
}

/// The selected day's notes as the calendar draws them: capped, with a way past the cap and back.
///
/// The same interaction Home settled on, scoped to one day — because it is the same problem. Eleven
/// notes under the grid pushed the calendar itself several screens up, so the calendar stopped being
/// a calendar and became a timeline with a month glued to the top of it.
///
/// **Four, not five.** The grid above it is tall, and the question a reader arrives with — *what did
/// I write that day* — is answered by four. Home's `Today` gets four for the same reason and its week
/// gets five; there is nothing above Home's first group but a date line.
struct CalendarDaySection {
    /// The rows drawn right now — the whole day once the reader has expanded it.
    let notes: [Note]
    /// How many the cap is still holding back. Zero when the day is fully drawn.
    let hidden: Int
    /// Whether the reader took this day past its cap. Not the same as `hidden == 0`: a day of three
    /// notes is also fully drawn, and has nothing to collapse back to.
    let isExpanded: Bool

    /// Everything the day holds, drawn or not — what `Show all N` names. Never the remainder.
    var total: Int { notes.count + hidden }

    /// Whether the day draws a toggle at all, in either direction.
    var isCollapsible: Bool { hidden > 0 || isExpanded }

    /// How many notes a day shows before it asks.
    static let cap = 4

    static func make(_ notes: [Note], expanded: Bool) -> CalendarDaySection {
        let overCap = notes.count > cap
        let showsAll = !overCap || expanded
        return CalendarDaySection(
            notes: showsAll ? notes : Array(notes.prefix(cap)),
            hidden: showsAll ? 0 : notes.count - cap,
            isExpanded: overCap && expanded
        )
    }
}

/// The heading over the selected day's notes.
///
/// `Today` when today is selected — the reader is standing on it, and naming the date would be the
/// screen telling them something they just chose. Any other day gets its weekday **and** its date:
/// `Saturday, August 29` places the note in a week, which is context a bare `August 29` withholds
/// for no gain in quietness.
///
/// Deliberately **not** `dayLabel`, which the timeline uses and which answers `Yesterday`. On a
/// calendar the reader has a grid in front of them and has pointed at a square; "Yesterday" names a
/// relationship they did not ask about, and the square they tapped already says which day it is.
/// No count is appended — the notes are directly underneath, and Home reports no statistics either.
func calendarDayHeading(for day: Date, calendar: Calendar = .current, now: Date = AppClock.now) -> String {
    if calendar.isDate(day, inSameDayAs: now) { return "Today" }
    let df = DateFormatter()
    df.calendar = calendar
    df.locale = .current
    // Localized template rather than a literal format: the order of weekday, month and day is not
    // ours to fix (`RULES.md` §5).
    let sameYear = calendar.isDate(day, equalTo: now, toGranularity: .year)
    df.setLocalizedDateFormatFromTemplate(sameYear ? "EEEEMMMMd" : "EEEEMMMMd yyyy")
    return df.string(from: day)
}
