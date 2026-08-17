import SwiftUI
import SwiftData

/// Month sheet for jumping to a date. Dots mark days with notes; selecting a day filters Home.
/// Secondary navigation only — not a second database UI (RULES.md §1).
struct CalendarSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var initialSelection: Date?
    var onSelectDay: (Date) -> Void

    @State private var visibleMonth: Date = Date()
    @State private var noteDays: Set<Date> = []

    private let calendar = Calendar.current

    private var monthTitle: String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"
        return df.string(from: visibleMonth)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSSpacing.s5) {
                HStack {
                    Text(monthTitle)
                        .font(.ds.groupTitle)
                        .foregroundStyle(Color.ds.textPrimary)
                    Spacer()
                    Button { step(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous month")
                    Button { step(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next month")
                }
                .foregroundStyle(Color.ds.accent)

                MonthGrid(month: visibleMonth, noteDays: noteDays, selectedDay: initialSelection) { day in
                    onSelectDay(day)
                    dismiss()
                }

                Divider()
                Button {
                    onSelectDay(calendar.startOfDay(for: .now))
                    dismiss()
                } label: {
                    Text("Go to Today")
                        .font(.body)
                        .foregroundStyle(Color.ds.accent)
                }
                Spacer()
            }
            .padding(.horizontal, DSSpacing.screenH)
            .padding(.top, DSSpacing.s6)
            .background(Color.ds.canvas)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
            .task(id: visibleMonth) { reloadDots() }
        }
    }

    private func step(_ months: Int) {
        visibleMonth = MonthMath.addMonths(months, to: visibleMonth, calendar: calendar)
    }

    private func reloadDots() {
        let store = SwiftDataNoteStore(context: context)
        noteDays = (try? store.noteDays(in: visibleMonth)) ?? []
    }
}
