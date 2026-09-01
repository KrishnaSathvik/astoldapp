import SwiftUI

/// Month grid: weekday header + day cells.
///
/// **One accent, used to mean things** (2026-08-31). Every piece of interaction state on this page
/// is `calendarAccent` — the sage the Calendar glyph wears — so the page reads as belonging to the
/// icon that opened it, and so colour here carries state rather than decorating:
///
/// | State | Treatment |
/// |---|---|
/// | Ordinary day | plain `textPrimary` |
/// | Has notes | 1–3 sage density dots beneath |
/// | Today, unselected | thin sage ring |
/// | Selected | solid sage circle, `onAccent` number |
/// | Empty day | nothing at all |
///
/// Today's ring and the selected fill are deliberately different shapes, not different colours: one
/// says *you are here in time* and the other says *you are looking at this*, and a reader has to be
/// able to see both at once on the day they are both true.
struct MonthGrid: View {
    let month: Date
    /// Visible notes per day (`SwiftDataNoteStore.noteDayCounts`). Absent means none.
    let noteCounts: [Date: Int]
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
        let isToday = calendar.isDate(date, inSameDayAs: AppClock.now)
        let count = noteCounts[calendar.startOfDay(for: date)] ?? 0
        let dots = CalendarDayDensity.dotCount(forNotes: count)

        Button { onSelect(date) } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.body)
                    .foregroundStyle(isSelected ? Color.ds.onAccent : Color.ds.textPrimary)
                    .frame(width: 36, height: 36)
                    .background {
                        if isSelected {
                            Circle().fill(Color.ds.calendarAccent)
                        } else if isToday {
                            // A ring, not a fill: today is a fact about the clock, and it must stay
                            // legible on the day it is also the selection.
                            Circle().strokeBorder(Color.ds.calendarAccent, lineWidth: 1.5)
                        }
                    }
                DensityDots(count: dots)
                    // The selection has already claimed the cell, and its notes are listed directly
                    // below — dots under a filled circle would be the same fact drawn twice.
                    .opacity(isSelected ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        // Stable handle for UI tests; invisible to users, who hear the accessibility label.
        .accessibilityIdentifier(Self.cellIdentifier(for: date, calendar: calendar))
        .accessibilityLabel(Text(date, style: .date))
        // State is never carried by colour alone (RULES.md §4). The *exact* count is spoken here
        // even though the grid only ever draws three dots: a reader who cannot see the dots is not
        // helped by hearing an approximation of them.
        .accessibilityValue(Self.spokenValue(noteCount: count, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// What a day cell says. Density is a visual shorthand; speech gets the real number.
    static func spokenValue(noteCount: Int, isToday: Bool) -> String {
        let notes = switch noteCount {
        case 0: "No notes"
        case 1: "1 note"
        default: "\(noteCount) notes"
        }
        return isToday ? "Today, \(notes)" : notes
    }
}

/// Up to three small sage dots under a day.
///
/// Drawn as `count` dots rather than a fixed row with some hidden, so the group stays centred at one,
/// two, and three. The reserved height keeps every cell the same size whether or not it has notes —
/// a grid whose rows shift by three points depending on what was written is a grid that ripples.
private struct DensityDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<count, id: \.self) { _ in
                Circle()
                    .fill(Color.ds.calendarAccent)
                    .frame(width: 4.5, height: 4.5)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)   // the cell speaks the real count
    }
}
