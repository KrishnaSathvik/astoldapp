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
struct CalendarPage: View {
    @Environment(\.modelContext) private var context

    @State private var visibleMonth = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var noteDays: Set<Date> = []
    @State private var editingNote: Note?
    @State private var deletion = NoteDeletion()

    private let calendar = Calendar.current

    private var monthTitle: String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"
        return df.string(from: visibleMonth)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ds.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: DSSpacing.s5) {
                monthHeader

                MonthGrid(month: visibleMonth, noteDays: noteDays, selectedDay: selectedDay) { day in
                    selectedDay = day
                }
                .padding(.horizontal, DSSpacing.screenH)

                daySection
            }
            .padding(.top, DSSpacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)

            if deletion.pending != nil {
                UndoBanner { deletion.undo(in: context) }
                    .padding(.bottom, DSSpacing.s4)
            }
        }
        .animation(DSMotion.standard, value: deletion.pending != nil)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        // Opening a note from here pushes onto the same stack, so Back returns to this screen.
        .navigationDestination(item: $editingNote) { note in
            EditorView(
                note: note,
                onClose: { editingNote = nil },
                onDelete: { note in
                    editingNote = nil
                    deletion.delete(note, in: context)
                }
            )
        }
        // `.task(id:)` alone would not re-run after returning from a note that was just deleted.
        .onAppear { reloadDots() }
        .onChange(of: visibleMonth) { _, _ in reloadDots() }
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
        .foregroundStyle(Color.ds.accent)
        .padding(.horizontal, DSSpacing.screenH)
    }

    /// Stepping months moves the selection with it, so the list below always belongs to the month on
    /// screen: today when the new month contains it, otherwise that month's first day.
    private func step(_ months: Int) {
        let month = MonthMath.addMonths(months, to: visibleMonth, calendar: calendar)
        visibleMonth = month
        if calendar.isDate(month, equalTo: .now, toGranularity: .month) {
            selectedDay = calendar.startOfDay(for: .now)
        } else {
            selectedDay = MonthMath.startOfMonth(for: month, calendar: calendar)
        }
    }

    private func reloadDots() {
        noteDays = (try? SwiftDataNoteStore(context: context).noteDays(in: visibleMonth)) ?? []
    }

    // MARK: Selected day

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(dayLabel(for: selectedDay, calendar: calendar))
                .font(.ds.groupTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, DSSpacing.screenH)
                .padding(.bottom, DSSpacing.s2)

            CalendarDayNotes(day: selectedDay) { editingNote = $0 }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// The selected day's notes. A `@Query` so a note deleted from the editor disappears on the way
/// back, without the calendar having to re-fetch by hand.
private struct CalendarDayNotes: View {
    @Query private var notes: [Note]
    private let onSelect: (Note) -> Void

    init(day: Date, onSelect: @escaping (Note) -> Void) {
        self.onSelect = onSelect
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        _notes = Query(FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil && $0.createdAt >= start && $0.createdAt < end },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        ))
    }

    var body: some View {
        if notes.isEmpty {
            Text("Nothing written on this day.")
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textSecondary)
                .padding(.horizontal, DSSpacing.screenH)
                .padding(.top, DSSpacing.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            List {
                ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                    Button { onSelect(note) } label: { NoteRow(note: note) }
                        .buttonStyle(.plain)
                        .plainCalendarRow(topInset: DSSpacing.s3)

                    if idx < notes.count - 1 {
                        Rectangle()
                            .fill(Color.ds.textTertiary.opacity(0.16))
                            .frame(height: 0.5)
                            .plainCalendarRow(topInset: DSSpacing.s3)
                            .accessibilityHidden(true)
                    }
                }

                Color.clear.frame(height: DSSpacing.s8)
                    .plainCalendarRow()
                    .accessibilityHidden(true)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .environment(\.defaultMinListRowHeight, 8)
            .background(Color.ds.canvas)
            .padding(.horizontal, DSSpacing.screenH)
        }
    }
}

private extension View {
    /// Chromeless list row, matching Home's rhythm.
    func plainCalendarRow(topInset: CGFloat = 0) -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(Color.ds.canvas)
            .listRowInsets(EdgeInsets(top: topInset, leading: 0, bottom: 0, trailing: 0))
    }
}
