import SwiftUI

/// Continuous vertical timeline grouped by day, newest first. No visible pagination (RULES.md §1).
struct HomeTimeline: View {
    let notes: [Note]
    var onSelect: (Note) -> Void

    private var groups: [NoteDayGroup] { groupedByDay(notes) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpacing.s5) {
                Text(HomeDate.top)
                    .font(.ds.dateLabel)
                    .foregroundStyle(Color.ds.textTertiary)

                ForEach(groups) { group in
                    DateGroupHeader(day: group.day)
                    ForEach(group.notes) { note in
                        Button { onSelect(note) } label: { NoteRow(note: note) }
                            .buttonStyle(.plain)
                    }
                }
                Spacer().frame(height: 88) // clear the floating +
            }
            .padding(.horizontal, DSSpacing.screenH)
            .padding(.top, DSSpacing.s6)
        }
    }
}

/// Shared "AUGUST 17, 2026" top-date string for Home.
enum HomeDate {
    static var top: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        return df.string(from: .now).uppercased()
    }
}
