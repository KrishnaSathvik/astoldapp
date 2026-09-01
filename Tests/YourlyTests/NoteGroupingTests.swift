import Testing
import Foundation
import SwiftUI
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

/// Home's relative-age buckets (RULES.md §1, amended 2026-08-30).
///
/// The boundaries are the whole point: 7 and 30 are *inclusive*, counted in calendar days, and a note
/// written one minute before midnight belongs to the day it was written on rather than to whatever
/// the clock says now.
struct NoteTimelineSectionTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }

    private var now: Date {
        cal.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 15, minute: 1))!
    }

    private func daysAgo(_ n: Int, hour: Int = 12) -> Date {
        let day = cal.date(byAdding: .day, value: -n, to: now)!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func period(_ date: Date) -> NoteTimelineSection.Period {
        timelinePeriod(for: date, calendar: cal, now: now)
    }

    @Test func todayCoversTheWholeCalendarDay() {
        #expect(period(daysAgo(0, hour: 0)) == .today)
        #expect(period(daysAgo(0, hour: 23)) == .today)
    }

    /// A minute past midnight is a *day* old, not an hour old. This is the difference between
    /// calendar arithmetic and 24-hour math, and it is what puts last night's note under
    /// "Previous 7 Days" the moment the date changes.
    @Test func lateLastNightIsNotToday() {
        let lastNight = cal.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 23, minute: 50))!
        #expect(period(lastNight) == .previous7Days)
    }

    @Test func sevenAndThirtyAreInclusiveBoundaries() {
        #expect(period(daysAgo(1)) == .previous7Days)
        #expect(period(daysAgo(7)) == .previous7Days)
        #expect(period(daysAgo(8)) == .previous30Days)
        #expect(period(daysAgo(30)) == .previous30Days)
        #expect(period(daysAgo(31)) == .older)
        #expect(period(daysAgo(400)) == .older)
    }

    /// A clock that moved backwards must not hide a note off the front of the timeline.
    @Test func aFutureDateStillLandsInToday() {
        #expect(period(cal.date(byAdding: .day, value: 3, to: now)!) == .today)
    }

    @Test func sectionsComeBackNewestFirstWithOrderPreservedInside() {
        let a = Note(body: "a", createdAt: daysAgo(0, hour: 9))
        let b = Note(body: "b", createdAt: daysAgo(0, hour: 8))
        let c = Note(body: "c", createdAt: daysAgo(3))
        let d = Note(body: "d", createdAt: daysAgo(90))
        let sections = timelineSections([a, b, c, d], calendar: cal, now: now)

        #expect(sections.map(\.title) == ["Today", "Previous 7 Days", "Older"])
        #expect(sections[0].notes.map(\.body) == ["a", "b"])   // same-bucket order preserved
        #expect(sections[2].notes.map(\.body) == ["d"])
    }

    /// A period nothing landed in draws no heading at all — an empty "Previous 30 Days" over nothing
    /// is a heading that says the library has a gap, which is not information anyone asked for.
    @Test func emptyPeriodsAreDropped() {
        let sections = timelineSections([Note(body: "only", createdAt: daysAgo(60))],
                                        calendar: cal, now: now)
        #expect(sections.map(\.title) == ["Older"])
    }

    @Test func noNotesTodayMeansNoTodaySection() {
        let sections = timelineSections([Note(body: "x", createdAt: daysAgo(2))],
                                        calendar: cal, now: now)
        #expect(!sections.contains { $0.period == .today })
    }
}

/// What Home draws, and what it deliberately leaves to the archive.
///
/// **Home became a recent-library surface on 2026-08-31** (`RULES.md` §1, `README.md` §2). It had
/// been the entire timeline, which at a few hundred notes made the landing screen a database — and
/// made `Today` a wall of transcript whenever an afternoon's voice capture landed in it.
///
/// Every boundary below is checked here rather than on a screen, because a cap that is only correct
/// in a screenshot is a cap nobody can change safely.
struct HomeLibraryTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }

    private var now: Date {
        cal.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 10))!
    }

    private func note(_ body: String, daysAgo: Int, hour: Int = 9) -> Note {
        let day = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: now))!
        return Note(body: body, createdAt: cal.date(byAdding: .hour, value: hour, to: day)!)
    }

    // MARK: Scope

    @Test func homeDrawsOnlyTodayAndThePreviousSevenDays() {
        let notes = [note("today", daysAgo: 0), note("week", daysAgo: 3),
                     note("month", daysAgo: 20), note("old", daysAgo: 200)]
        let sections = HomeLibrary.sections(notes, calendar: cal, now: now)
        #expect(sections.map(\.period) == [.today, .previous7Days])
    }

    /// A period with nothing in it is a heading over nothing — chrome reporting on itself.
    @Test func anEmptyPeriodIsNotDrawn() {
        let sections = HomeLibrary.sections([note("week", daysAgo: 3)], calendar: cal, now: now)
        #expect(sections.map(\.period) == [.previous7Days])
    }

    // MARK: Caps

    @Test func todayIsCappedAtFourWithTheRestCounted() {
        let notes = (0..<7).map { note("n\($0)", daysAgo: 0, hour: 9 + $0) }
        let today = HomeLibrary.sections(notes, calendar: cal, now: now).first
        #expect(today?.notes.count == 4)
        #expect(today?.hidden == 3)
    }

    @Test func thePreviousSevenDaysIsCappedAtFive() {
        let notes = (0..<9).map { note("n\($0)", daysAgo: 2, hour: 1 + $0) }
        let week = HomeLibrary.sections(notes, calendar: cal, now: now).first
        #expect(week?.notes.count == 5)
        #expect(week?.hidden == 4)
    }

    /// A period inside its cap is fully drawn and offers nothing to expand — the affordance appears
    /// because something is actually hidden, never as permanent furniture.
    @Test func aPeriodInsideItsCapHidesNothing() {
        let notes = (0..<3).map { note("n\($0)", daysAgo: 0, hour: 9 + $0) }
        let today = HomeLibrary.sections(notes, calendar: cal, now: now).first
        #expect(today?.notes.count == 3)
        #expect(today?.hidden == 0)
    }

    @Test func expandingAPeriodShowsAllOfItAndOnlyIt() {
        let notes = (0..<7).map { note("t\($0)", daysAgo: 0, hour: 9 + $0) }
            + (0..<8).map { note("w\($0)", daysAgo: 3, hour: 1 + $0) }
        let sections = HomeLibrary.sections(notes, calendar: cal, now: now, expanded: [.today])
        #expect(sections.first { $0.period == .today }?.notes.count == 7)
        #expect(sections.first { $0.period == .today }?.hidden == 0)
        #expect(sections.first { $0.period == .previous7Days }?.notes.count == 5, "the other cap holds")
    }

    /// `Show all N` names the whole period, not the remainder. A remainder count describes a batch,
    /// and a batch is one `Load more` away from the pagination this product does not have
    /// (`RULES.md` §1).
    @Test func aCappedPeriodKnowsItsWholeSize() {
        let notes = (0..<7).map { note("n\($0)", daysAgo: 0, hour: 9 + $0) }
        let today = HomeLibrary.sections(notes, calendar: cal, now: now).first
        #expect(today?.total == 7, "the affordance says Show all 7, never Show all 3 more")
        #expect(today?.notes.count == 4)
    }

    /// The cap keeps the newest, because the reason to look at Home is what just happened.
    @Test func theCapKeepsTheNewest() {
        let notes = (0..<6).map { note("n\($0)", daysAgo: 0, hour: 14 - $0) }
        let today = HomeLibrary.sections(notes, calendar: cal, now: now).first
        #expect(today?.notes.map(\.body) == ["n0", "n1", "n2", "n3"])
    }

    // MARK: Collapsing again

    /// `Show all N` goes both ways (2026-08-31). A period the reader opened can be shut on the same
    /// visit — one-way expansion left a fourteen-row group open with no way back short of leaving
    /// Home, which made a glance feel like a commitment.
    @Test func anExpandedPeriodOffersItsWayBack() {
        let notes = (0..<7).map { note("n\($0)", daysAgo: 0, hour: 9 + $0) }
        let collapsed = HomeLibrary.sections(notes, calendar: cal, now: now).first
        #expect(collapsed?.isExpanded == false, "it draws Show all 7, not Show less")
        #expect(collapsed?.isCollapsible == true)

        let expanded = HomeLibrary.sections(notes, calendar: cal, now: now, expanded: [.today]).first
        #expect(expanded?.isExpanded == true, "and now Show less")
        #expect(expanded?.isCollapsible == true)
    }

    /// Collapsing restores the cap exactly — the same four notes, and the same offer to open again.
    /// Nothing about having looked once is remembered by the section.
    @Test func collapsingReturnsThePeriodToItsCap() {
        let notes = (0..<7).map { note("n\($0)", daysAgo: 0, hour: 9 + $0) }
        let reCollapsed = HomeLibrary.sections(notes, calendar: cal, now: now, expanded: []).first
        #expect(reCollapsed?.notes.count == 4)
        #expect(reCollapsed?.hidden == 3)
        #expect(reCollapsed?.isExpanded == false)
    }

    /// A period that never reached its cap has nothing to collapse back to, even if its period is
    /// somehow in the expanded set. `Show less` there would remove notes the cap was never holding.
    @Test func aPeriodInsideItsCapDrawsNoToggleEitherWay() {
        let notes = (0..<3).map { note("n\($0)", daysAgo: 0, hour: 9 + $0) }
        let today = HomeLibrary.sections(notes, calendar: cal, now: now, expanded: [.today]).first
        #expect(today?.isExpanded == false)
        #expect(today?.isCollapsible == false, "no Show all, and no Show less")
    }

    /// Expanding one period must not offer to collapse another.
    @Test func collapsibilityIsPerPeriod() {
        let notes = (0..<7).map { note("t\($0)", daysAgo: 0, hour: 9 + $0) }
            + (0..<8).map { note("w\($0)", daysAgo: 3, hour: 1 + $0) }
        let sections = HomeLibrary.sections(notes, calendar: cal, now: now, expanded: [.today])
        #expect(sections.first { $0.period == .today }?.isExpanded == true)
        #expect(sections.first { $0.period == .previous7Days }?.isExpanded == false)
        #expect(sections.first { $0.period == .previous7Days }?.total == 8, "still Show all 8")
    }

    // MARK: Browse older notes

    @Test func theArchiveIsOfferedWhenSomethingIsOlderThanHomeDraws() {
        #expect(HomeLibrary.hasOlderNotes([note("old", daysAgo: 40)], calendar: cal, now: now))
    }

    /// Offered only when it leads somewhere. A control that opens the same notes one screen further
    /// away is a control with nothing to do.
    @Test func theArchiveIsNotOfferedWhenHomeAlreadyShowsEverything() {
        let notes = [note("today", daysAgo: 0), note("week", daysAgo: 5)]
        #expect(HomeLibrary.hasOlderNotes(notes, calendar: cal, now: now) == false)
    }

    /// **The duplication this check exists to prevent** (2026-08-31). Fourteen notes, all recent:
    /// `Show all 14` already reaches every one of them, so an archive affordance beside it would be
    /// the same offer made twice, leading to the same fourteen notes one screen further away. A
    /// period being capped is emphatically *not* a reason to offer it.
    @Test func aCappedPeriodIsNotByItselfAReasonToOfferTheArchive() {
        let notes = (0..<14).map { note("n\($0)", daysAgo: $0 % 6, hour: 1 + $0 % 12) }
        let sections = HomeLibrary.sections(notes, calendar: cal, now: now)
        #expect(sections.contains { $0.hidden > 0 }, "something is capped")
        #expect(HomeLibrary.hasOlderNotes(notes, calendar: cal, now: now) == false,
                "and yet there is no archive, because Show all N already reaches all 14")
    }

    /// The seventh day back is still the week, and the eighth is not — the same inclusive calendar
    /// boundary `timelinePeriod` uses, checked from Home's side so the two cannot drift.
    @Test func theWeekBoundaryMatchesTheBucketing() {
        #expect(HomeLibrary.hasOlderNotes([note("edge", daysAgo: 7)], calendar: cal, now: now) == false)
        #expect(HomeLibrary.hasOlderNotes([note("past", daysAgo: 8)], calendar: cal, now: now))
    }

    /// A large library still resolves to two capped groups — the whole point of the change.
    @Test func aLargeLibraryStillDrawsAtMostNineRows() {
        let notes = (0..<400).map { note("n\($0)", daysAgo: $0 % 9, hour: 1) }
        let drawn = HomeLibrary.sections(notes, calendar: cal, now: now)
            .reduce(0) { $0 + $1.notes.count }
        #expect(drawn == 9, "4 from Today, 5 from the week — never 400")
    }
}

/// What a Home row shows, and at what weight.
///
/// The rule (`RULES.md` §1, tightened 2026-08-31): **a body never masquerades as a title.** Primary
/// semibold means the writer named this note, and nothing else earns it. Checked here rather than on
/// a screen, because the failure it guards against — a column of voice transcripts that all look
/// like chosen headlines — renders perfectly.
struct NoteRowContentTests {

    // MARK: The title line exists only when there is a title

    @Test func aChosenTitleIsCarriedAsTheTitle() {
        let row = NoteRowContent.make(title: "Alaska Road Trip",
                                      lines: ["A realistic 10-day route.", "Anchorage first."])
        #expect(row.title == "Alaska Road Trip")
        #expect(row.isTitled)
    }

    /// **The defect this rule exists for.** A titleless note's first body line must not be promoted
    /// into the title slot — there is no title, and the row draws no title line at all.
    @Test func aTitlelessNoteHasNoTitleAtAll() {
        let row = NoteRowContent.make(title: nil,
                                      lines: ["Okay, let's talk about that right now.",
                                              "Damian, does this make sense?"])
        #expect(row.title == nil, "the first body line must not become a title")
        #expect(!row.isTitled)
    }

    /// Never `Untitled`, never `Voice Note`, never a generated stand-in. The absence is the answer.
    @Test func nothingIsSubstitutedForAMissingTitle() {
        for lines in [["Something"], [], ["A", "B", "C"]] {
            #expect(NoteRowContent.make(title: nil, lines: lines).title == nil)
        }
    }

    /// A whitespace-only title is no title, and must not take the title slot either.
    @Test func aWhitespaceTitleIsNotATitle() {
        let row = NoteRowContent.make(title: "   \n  ", lines: ["My name is Mark."])
        #expect(row.title == nil)
        #expect(row.preview == "My name is Mark.")
    }

    /// A title is trimmed for layout so a stray leading space cannot indent a row. It is never
    /// written back — that is `storedTitle`'s rule, and this side only reads.
    @Test func aTitleIsTrimmedForTheRowOnly() {
        #expect(NoteRowContent.make(title: "  Application Links  ", lines: []).title
                == "Application Links")
    }

    // MARK: Typography

    /// An empty title never receives title typography, because it never reaches a title line: the
    /// only thing drawn in `noteTitle` is `content.title`, and that is `nil` here.
    @Test func onlyATitleReadsAtTitleWeight() {
        let titled = NoteRowContent.make(title: "SQL Questions", lines: ["Find the two products."])
        let untitled = NoteRowContent.make(title: nil, lines: ["Find the two products."])
        #expect(titled.isTitled)
        #expect(!untitled.isTitled)
        // Neither excerpt is ever drawn at title weight, titled or not.
        #expect(titled.previewFont != .ds.noteTitle)
        #expect(untitled.previewFont != .ds.noteTitle)
    }

    /// The titleless excerpt is the row's whole content, so it reads at body size; under a real
    /// title it steps down to `subheadline`. Neither carries extra weight — weight is the title's.
    @Test func theExcerptStepsDownOnlyWhenATitleIsAboveIt() {
        #expect(NoteRowContent.make(title: nil, lines: ["x"]).previewFont == .ds.noteBody)
        #expect(NoteRowContent.make(title: "T", lines: ["x"]).previewFont == .ds.preview)
    }

    // MARK: The excerpt

    /// A titleless note no longer spends its first line paying for a title it never had, so the
    /// excerpt is the **whole** body either way.
    @Test func theExcerptIsTheWholeBodyWithOrWithoutATitle() {
        let lines = ["And the Buick is yours.", "You know, this is exactly what Dr. Fishbine said."]
        let expected = "And the Buick is yours.  You know, this is exactly what Dr. Fishbine said."
        #expect(NoteRowContent.make(title: nil, lines: lines).preview == expected)
        #expect(NoteRowContent.make(title: "Titled", lines: lines).preview == expected)
    }

    /// Two lines, the same number for every row, so truncation never depends on what happens to fit.
    @Test func everyRowGetsTheSameDeterministicLineLimit() {
        #expect(NoteRowContent.previewLineLimit == 2)
    }

    /// Structure is flattened to what the reader would have seen — no marker, fence, or table pipe
    /// reaches a row, and a checklist collapses onto the excerpt rather than showing one item.
    @Test func structureMarkersStayFlattenedIntoTheExcerpt() {
        let row = NoteRowContent.make(title: nil,
                                      lines: ["✓ Website", "✓ Voice V2", "○ Screenshots"])
        #expect(row.preview == "✓ Website  ✓ Voice V2  ○ Screenshots")
    }

    /// Title with nothing under it draws a title and no excerpt — not an empty second line.
    @Test func aTitleWithAnEmptyBodyStandsAlone() {
        let row = NoteRowContent.make(title: "Just a title", lines: [])
        #expect(row.title == "Just a title")
        #expect(row.preview.isEmpty)
    }

    /// An empty note is still a well-formed row — it is discarded elsewhere, and this must not be
    /// the code that decides that.
    @Test func anEmptyNoteIsStillAWellFormedRow() {
        let row = NoteRowContent.make(title: nil, lines: [])
        #expect(row.title == nil)
        #expect(row.preview.isEmpty)
    }

    // MARK: Voice

    /// A voice capture that earned a note is an **ordinary titleless note**. `QuickVoiceNote` gives
    /// it no title, so it takes exactly the same path as a typed note with no title — no badge, no
    /// generated headline, no separate row shape (`RULES.md` §1, §2).
    @Test func aVoiceNoteIsJustATitlelessNote() throws {
        let spoken = "Okay, let's talk about that right now. Damian, does this make sense?"
        let note = try #require(QuickVoiceNote.make(from: spoken))
        #expect(note.title == nil, "a transcript is never turned into a title")

        let row = NoteRowContent.make(title: note.title,
                                      lines: StructuredTextExport.previewLines(note.body))
        let typed = NoteRowContent.make(title: nil,
                                        lines: StructuredTextExport.previewLines(spoken))
        #expect(row == typed, "spoken and typed titleless notes draw identically")
        #expect(row.title == nil)
        #expect(row.previewFont == .ds.noteBody)
    }
}

/// Home's date line (restored 2026-08-31).
///
/// It sits above the first period heading and orients rather than announces. The `As Told` title and
/// the note count that briefly replaced it are gone: the name of the app was on the icon the reader
/// just tapped, and the size of the library is a statistic Home does not report (`RULES.md` §4).
struct HomeDateTests {

    /// Bracketed rather than compared against one reading of the clock: a run that starts at 23:59
    /// would otherwise fail for no product reason when the two `.now`s land on different days.
    @Test func theTopDateIsTodaysDateInCaps() {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        let before = df.string(from: .now).uppercased()
        let actual = HomeDate.top
        let after = df.string(from: .now).uppercased()
        #expect(actual == before || actual == after)
    }

    /// All-caps and no leading zero: `AUGUST 3, 2026`, never `August 03, 2026`.
    @Test func theTopDateShoutsQuietlyAndDoesNotPadTheDay() {
        #expect(HomeDate.top == HomeDate.top.uppercased())
        #expect(!HomeDate.top.contains(" 0"))
    }
}


/// The month grid's density dots (added 2026-08-31).
///
/// Three levels, never more. The dots answer *quiet day or busy day* from across the screen; the
/// exact answer is one tap away underneath, and the accessibility value speaks the real number
/// because a reader who cannot see dots is not helped by an approximation of them.
struct CalendarDayDensityTests {

    @Test func theFourBands() {
        #expect(CalendarDayDensity.dotCount(forNotes: 0) == 0)
        #expect(CalendarDayDensity.dotCount(forNotes: 1) == 1)
        #expect(CalendarDayDensity.dotCount(forNotes: 2) == 2)
        #expect(CalendarDayDensity.dotCount(forNotes: 3) == 2)
        #expect(CalendarDayDensity.dotCount(forNotes: 4) == 3)
    }

    /// A busy day is not a bar chart. Eleven notes and four hundred both read as "busy".
    @Test func theDotsNeverBecomeACount() {
        for n in [4, 7, 11, 400] {
            #expect(CalendarDayDensity.dotCount(forNotes: n) == CalendarDayDensity.maxDots)
        }
        #expect(CalendarDayDensity.maxDots == 3)
    }

    /// Monotonic: a busier day never shows fewer dots than a quieter one.
    @Test func moreNotesNeverMeansFewerDots() {
        let counts = (0...30).map { CalendarDayDensity.dotCount(forNotes: $0) }
        #expect(zip(counts, counts.dropFirst()).allSatisfy { $0 <= $1 })
    }

    /// A count that cannot happen answers "nothing" rather than trapping — a grid cell is not the
    /// place to discover a corrupt count.
    @Test func aNegativeCountDrawsNothing() {
        #expect(CalendarDayDensity.dotCount(forNotes: -1) == 0)
    }

    /// State is never carried by colour alone (RULES.md §4): the cell speaks the **exact** number,
    /// not the number of dots drawn.
    @Test func theSpokenValueCarriesTheRealCountNotTheDots() {
        #expect(MonthGrid.spokenValue(noteCount: 0, isToday: false) == "No notes")
        #expect(MonthGrid.spokenValue(noteCount: 1, isToday: false) == "1 note")
        #expect(MonthGrid.spokenValue(noteCount: 11, isToday: false) == "11 notes")
        #expect(MonthGrid.spokenValue(noteCount: 2, isToday: true) == "Today, 2 notes")
    }
}

/// The calendar's selected-day cap — Home's interaction, scoped to one day.
///
/// Eleven notes under the grid used to push the calendar itself several screens up, so the calendar
/// stopped being a calendar. Four is the cap because the grid above it is tall.
struct CalendarDaySectionTests {
    private func notes(_ n: Int) -> [Note] {
        (0..<n).map { Note(body: "n\($0)", createdAt: Date(timeIntervalSince1970: Double(1000 - $0))) }
    }

    @Test func aDayIsCappedAtFour() {
        let s = CalendarDaySection.make(notes(11), expanded: false)
        #expect(CalendarDaySection.cap == 4)
        #expect(s.notes.count == 4)
        #expect(s.hidden == 7)
        #expect(s.total == 11, "the affordance says Show all 11, never Show all 7 more")
    }

    /// The cap keeps the newest — the query hands them over newest-first and the prefix respects it.
    @Test func theCapKeepsTheOrderItWasGiven() {
        let all = notes(6)
        #expect(CalendarDaySection.make(all, expanded: false).notes.map(\.body)
                == ["n0", "n1", "n2", "n3"])
    }

    @Test func expandingShowsTheWholeDay() {
        let s = CalendarDaySection.make(notes(11), expanded: true)
        #expect(s.notes.count == 11)
        #expect(s.hidden == 0)
        #expect(s.isExpanded)
        #expect(s.isCollapsible, "and offers Show less")
    }

    /// Collapsing restores the cap exactly. Nothing about having looked once is remembered.
    @Test func collapsingReturnsToTheCap() {
        let s = CalendarDaySection.make(notes(11), expanded: false)
        #expect(s.notes.count == 4)
        #expect(!s.isExpanded)
    }

    /// A day inside its cap has nothing to expand and nothing to collapse back to, even if the page
    /// thinks it is expanded — `Show less` there would remove notes the cap was never holding.
    @Test func aDayInsideItsCapDrawsNoToggleEitherWay() {
        for expanded in [true, false] {
            let s = CalendarDaySection.make(notes(3), expanded: expanded)
            #expect(s.notes.count == 3)
            #expect(s.hidden == 0)
            #expect(!s.isExpanded)
            #expect(!s.isCollapsible)
        }
    }

    /// Exactly four is inside the cap: the affordance appears because something is hidden, never as
    /// permanent furniture.
    @Test func exactlyTheCapHidesNothing() {
        let s = CalendarDaySection.make(notes(4), expanded: false)
        #expect(s.hidden == 0)
        #expect(!s.isCollapsible)
        #expect(CalendarDaySection.make(notes(5), expanded: false).isCollapsible)
    }

    @Test func anEmptyDayIsWellFormed() {
        let s = CalendarDaySection.make([], expanded: false)
        #expect(s.notes.isEmpty)
        #expect(s.total == 0)
        #expect(!s.isCollapsible)
    }
}

/// The heading over the selected day's notes.
struct CalendarDayHeadingTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }
    private var now: Date {
        cal.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 10))!
    }
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    @Test func todayIsNamedToday() {
        #expect(calendarDayHeading(for: now, calendar: cal, now: now) == "Today")
        #expect(calendarDayHeading(for: day(2026, 8, 31), calendar: cal, now: now) == "Today")
    }

    /// Any other day gets its weekday **and** its date: the weekday places the note in a week, which
    /// a bare `August 29` withholds for no gain in quietness.
    @Test func anotherDayGetsItsWeekdayAndDate() {
        let h = calendarDayHeading(for: day(2026, 8, 29), calendar: cal, now: now)
        #expect(h.contains("Saturday"))
        #expect(h.contains("29"))
        #expect(h.contains("August"))
    }

    /// **Not `dayLabel`.** On a calendar the reader has pointed at a square, so "Yesterday" names a
    /// relationship they did not ask about — while the timeline's own label still answers it.
    @Test func yesterdayIsADateHereAndStillYesterdayOnTheTimeline() {
        let yesterday = day(2026, 8, 30)
        #expect(calendarDayHeading(for: yesterday, calendar: cal, now: now) != "Yesterday")
        #expect(calendarDayHeading(for: yesterday, calendar: cal, now: now).contains("Sunday"))
        #expect(dayLabel(for: yesterday, calendar: cal, now: now) == "Yesterday",
                "the timeline's label is untouched")
    }

    /// A day in another year still says which one, so a heading is never ambiguous.
    @Test func anotherYearCarriesTheYear() {
        #expect(calendarDayHeading(for: day(2025, 8, 29), calendar: cal, now: now).contains("2025"))
    }

    /// No count beside it — the notes are directly underneath, and Home reports no statistics either.
    @Test func theHeadingCarriesNoCount() {
        for d in [now, day(2026, 8, 29), day(2025, 1, 1)] {
            let h = calendarDayHeading(for: d, calendar: cal, now: now)
            #expect(!h.lowercased().contains("note"))
        }
    }
}
