import SwiftUI

/// Continuous day-grouped timeline as a chromeless List so native swipe-to-delete works.
/// No visible pagination, no separators, canvas row backgrounds (RULES.md §1, §4).
struct HomeTimeline: View {
    let notes: [Note]
    var onSelect: (Note) -> Void
    var onDelete: (Note) -> Void

    private var groups: [NoteDayGroup] { groupedByDay(notes) }

    var body: some View {
        List {
            Text(HomeDate.top)
                .font(.ds.dateLabel)
                .foregroundStyle(Color.ds.textTertiary)
                .plainRow(topInset: DSSpacing.s2)

            ForEach(groups) { group in
                DateGroupHeader(day: group.day)
                    .plainRow(topInset: DSSpacing.s5)

                ForEach(Array(group.notes.enumerated()), id: \.element.id) { idx, note in
                    Button { onSelect(note) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            NoteRow(note: note)
                            if idx < group.notes.count - 1 {
                                Rectangle()
                                    .fill(Color.ds.textTertiary.opacity(0.16))
                                    .frame(height: 0.5)
                                    .padding(.top, DSSpacing.s4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .plainRow(topInset: DSSpacing.s4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { onDelete(note) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Color.clear.frame(height: 72).plainRow()   // clear the floating +
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)                    // quiet editorial: no visible scrollbar
        .environment(\.defaultMinListRowHeight, 8)   // let rows hug their content
        .background(Color.ds.canvas)
        .padding(.horizontal, DSSpacing.screenH)
    }
}

/// Shared "AUGUST 17, 2026" top-date string for Home.
enum HomeDate {
    static var top: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        return df.string(from: .now).uppercased()
    }
}

private extension View {
    /// Chromeless list row: no separator, canvas background, tight insets.
    func plainRow(topInset: CGFloat = 0) -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(Color.ds.canvas)
            .listRowInsets(EdgeInsets(top: topInset, leading: 0, bottom: 0, trailing: 0))
    }
}
