import SwiftUI
import SwiftData

/// Full-page calendar for jumping to a date. Pushed inside Home's navigation stack (system back
/// button). Dots mark days with notes; selecting a day filters Home and pops back.
struct CalendarPage: View {
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
        VStack(alignment: .leading, spacing: DSSpacing.s6) {
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

            MonthGrid(month: visibleMonth, noteDays: noteDays, selectedDay: initialSelection) { day in
                onSelectDay(day)
                dismiss()
            }

            // No "Go to Today": back already returns to the timeline, which opens on today.
            // A second way out of one small screen is one control too many (RULES.md §4).

            Spacer()
        }
        .padding(.horizontal, DSSpacing.screenH)
        .padding(.top, DSSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: visibleMonth) { reloadDots() }
    }

    private func step(_ months: Int) {
        visibleMonth = MonthMath.addMonths(months, to: visibleMonth, calendar: calendar)
    }

    private func reloadDots() {
        noteDays = (try? SwiftDataNoteStore(context: context).noteDays(in: visibleMonth)) ?? []
    }
}
