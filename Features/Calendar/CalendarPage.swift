import SwiftUI
import SwiftData

/// Full-page calendar for reaching a day's notes. Pushed inside Home's navigation stack (system
/// back button).
///
/// Tapping a day does not navigate anywhere: the notes written that day appear **below the grid**,
/// and tapping one opens it from here — so Back comes home to the calendar, with the same day still
/// selected, rather than dumping the reader somewhere else (docs/03-design-system.md §4.6).
///
/// The day list is navigation, not a second place to browse: rows only, no search, no grouping, no
/// pagination, same `NoteRow` as Home (RULES.md §1 — the calendar is not a second database UI).
///
/// **One vertical scroll for the whole page** (2026-08-31). The grid used to sit above a `List` that
/// scrolled inside it, so a day with eleven notes gave the reader two scrolling surfaces stacked on
/// top of each other and no way to tell which one a drag would move. The month, the heading, the
/// notes, and the way past the cap are all in the same `ScrollView` now.
struct CalendarPage: View {
    @Environment(\.modelContext) private var context

    @State private var visibleMonth = AppClock.now
    @State private var selectedDay = Calendar.current.startOfDay(for: AppClock.now)
    /// Visible notes per day of `visibleMonth`, for the density dots.
    @State private var noteCounts: [Date: Int] = [:]
    @State private var editingNote: Note?
    /// Whether the reader has taken the selected day past its cap. Reset whenever the selection
    /// moves — a new day is a new question, and it starts by being asked briefly.
    @State private var dayExpanded = false

    private let calendar = Calendar.current

    private var monthTitle: String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"
        return df.string(from: visibleMonth)
    }

    var body: some View {
        ZStack {
            Color.ds.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.s5) {
                    monthHeader

                    MonthGrid(month: visibleMonth, noteCounts: noteCounts, selectedDay: selectedDay) { day in
                        select(day)
                    }
                    .padding(.horizontal, DSSpacing.screenH)

                    daySection

                    Color.clear.frame(height: DSSpacing.s8)
                        .accessibilityHidden(true)
                }
                .padding(.top, DSSpacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        // Opening a note from here pushes onto the same stack, so Back returns to this screen.
        .navigationDestination(item: $editingNote) { note in
            EditorView(note: note, onClose: { editingNote = nil }, origin: .calendar)
        }
        // `.task(id:)` alone would not re-run after returning from a note that changed while open.
        .onAppear { reloadCounts() }
        .onChange(of: visibleMonth) { _, _ in reloadCounts() }
    }

    // MARK: Month

    private var monthHeader: some View {
        HStack {
            Text(monthTitle)
                .font(.ds.homeTitle)
                .foregroundStyle(Color.ds.textPrimary)
            Spacer()
            Button { step(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
                .padding(.trailing, DSSpacing.s3)
            Button { step(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next month")
        }
        // Sage, like every other control on this page — the arrows move the calendar, so they wear
        // the calendar's colour rather than the app's general accent.
        .foregroundStyle(Color.ds.calendarAccent)
        .padding(.horizontal, DSSpacing.screenH)
    }

    /// Stepping months moves the selection with it, so the list below always belongs to the month on
    /// screen: today when the new month contains it, otherwise that month's first day.
    private func step(_ months: Int) {
        let month = MonthMath.addMonths(months, to: visibleMonth, calendar: calendar)
        visibleMonth = month
        if calendar.isDate(month, equalTo: AppClock.now, toGranularity: .month) {
            select(calendar.startOfDay(for: AppClock.now))
        } else {
            select(MonthMath.startOfMonth(for: month, calendar: calendar))
        }
    }

    /// The one way the selection moves, so the cap is always re-applied with it.
    private func select(_ day: Date) {
        selectedDay = day
        dayExpanded = false
    }

    private func reloadCounts() {
        noteCounts = (try? SwiftDataNoteStore(context: context).noteDayCounts(in: visibleMonth)) ?? [:]
    }

    // MARK: Selected day

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(calendarDayHeading(for: selectedDay, calendar: calendar))
                .font(.ds.groupTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, DSSpacing.screenH)
                .padding(.bottom, DSSpacing.s2)

            CalendarDayNotes(day: selectedDay,
                             expanded: $dayExpanded,
                             onSelect: { editingNote = $0 })
        }
    }
}

/// The selected day's notes. A `@Query` so a note emptied in the editor disappears on the way
/// back, without the calendar having to re-fetch by hand.
///
/// **Flat rows with hairlines, not a grouped card.** Home wraps each period in a rounded surface
/// because it has several periods to tell apart; here the grid above already gives the page all the
/// structure it needs, and a second large container under it would only add weight
/// (docs/03-design-system.md §4.6).
private struct CalendarDayNotes: View {
    @Query private var notes: [Note]
    @Binding private var expanded: Bool
    private let onSelect: (Note) -> Void

    init(day: Date, expanded: Binding<Bool>, onSelect: @escaping (Note) -> Void) {
        self._expanded = expanded
        self.onSelect = onSelect
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        _notes = Query(FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil && $0.createdAt >= start && $0.createdAt < end },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        ))
    }

    /// An empty draft an open editor still owns is not a note anyone wrote on this day (`NoteVisibility`).
    private var visible: [Note] { userVisibleNotes(notes) }

    private var section: CalendarDaySection {
        CalendarDaySection.make(visible, expanded: expanded)
    }

    var body: some View {
        let section = section
        if visible.isEmpty {
            Text("Nothing written on this day.")
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textSecondary)
                .padding(.horizontal, DSSpacing.screenH)
                .padding(.top, DSSpacing.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // A plain stack, not a list: this page has one scrolling surface and it is above us.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(section.notes.enumerated()), id: \.element.id) { idx, note in
                    Button { onSelect(note) } label: { NoteRow(note: note) }
                        .buttonStyle(.plain)

                    if idx < section.notes.count - 1 {
                        Rectangle()
                            .fill(Color.ds.separator)
                            .frame(height: 0.5)
                            .accessibilityHidden(true)
                    }
                }

                if section.isCollapsible {
                    DayExpandToggle(section: section) {
                        withAnimation(DSMotion.standard) { expanded.toggle() }
                    }
                }
            }
            .padding(.horizontal, DSSpacing.screenH)
        }
    }
}

/// `Show all 11` ⇄ `Show less` for the selected day.
///
/// The same control Home uses, in the same words, for the same reason — a reader who has learned it
/// once on Home must not have to learn it again here (`HomeLibrarySection`, `CalendarDaySection`).
/// It names the whole day, never the remainder: "Show all 7 more" describes a batch, and a batch is
/// one `Load more` away from the pagination this product does not have (RULES.md §1).
private struct DayExpandToggle: View {
    let section: CalendarDaySection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(section.isExpanded ? "Show less" : "Show all \(section.total)")
                .font(.ds.preview)
                .foregroundStyle(Color.ds.accent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint(section.isExpanded ? "Collapses this day back"
                                              : "Shows the rest of this day")
    }
}
