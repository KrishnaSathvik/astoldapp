import SwiftUI
import SwiftData

/// The main browse timeline, loaded in batches via a growing `fetchLimit` (docs/05-architecture.md §8).
/// Stays reactive (new notes appear, deletes drop out) and never exposes page numbers.
struct PagedNotesList: View {
    @Query private var notes: [Note]
    private let limit: Int
    private let onSelect: (Note) -> Void
    private let onDelete: (Note) -> Void
    private let onLoadMore: () -> Void

    init(limit: Int,
         onSelect: @escaping (Note) -> Void,
         onDelete: @escaping (Note) -> Void,
         onLoadMore: @escaping () -> Void) {
        self.limit = limit
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onLoadMore = onLoadMore

        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        _notes = Query(descriptor)
    }

    var body: some View {
        if notes.isEmpty {
            EmptyHome()
        } else {
            HomeTimeline(notes: notes, onSelect: onSelect, onDelete: onDelete) {
                // Only ask for more when the current batch is full (there may be older notes).
                if notes.count >= limit { onLoadMore() }
            }
        }
    }
}

/// Empty Home state.
struct EmptyHome: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            Text(HomeDate.top)
                .font(.ds.dateLabel)
                .foregroundStyle(Color.ds.textTertiary)
            Text("Today")
                .font(.ds.homeTitle)
                .foregroundStyle(Color.ds.textPrimary)
            Spacer().frame(height: DSSpacing.s10)
            Text("Whatever you write will appear here.")
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSSpacing.screenH)
        .padding(.top, DSSpacing.s6)
    }
}
