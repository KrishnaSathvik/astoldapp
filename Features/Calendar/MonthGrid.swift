import SwiftUI

/// Month grid: weekday header + day cells. Days with notes show a dot; selected/today are marked.
struct MonthGrid: View {
    let month: Date
    let noteDays: Set<Date>
    let selectedDay: Date?
    var onSelect: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: DSSpacing.s2), count: 7)

    var body: some View {
        VStack(spacing: DSSpacing.s3) {
            LazyVGrid(columns: columns, spacing: DSSpacing.s2) {
                ForEach(Array(MonthMath.weekdayInitials(calendar: calendar).enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.ds.caption)
                        .foregroundStyle(Color.ds.textTertiary)
                }
            }
            LazyVGrid(columns: columns, spacing: DSSpacing.s2) {
                ForEach(MonthMath.gridCells(for: month, calendar: calendar)) { cell in
                    if let date = cell.date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    /// e.g. "day-2026-08-17".
    static func cellIdentifier(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "day-%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    @ViewBuilder private func dayCell(_ date: Date) -> some View {
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let hasNotes = noteDays.contains(calendar.startOfDay(for: date))

        Button { onSelect(date) } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.body)
                    .foregroundStyle(isSelected ? Color.ds.onAccent
                                     : (isToday ? Color.ds.accent : Color.ds.textPrimary))
                    .frame(width: 36, height: 36)
                    .background {
                        if isSelected { Circle().fill(Color.ds.accent) }
                    }
                Circle()
                    .fill(hasNotes ? Color.ds.accent : .clear)
                    .frame(width: 5, height: 5)
                    .opacity(isSelected ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        // Stable handle for UI tests; invisible to users, who hear the accessibility label.
        .accessibilityIdentifier(Self.cellIdentifier(for: date, calendar: calendar))
        .accessibilityLabel(Text(date, style: .date))
        .accessibilityValue(hasNotes ? "Has notes" : "No notes")
    }
}
