import SwiftUI
import SwiftData

/// Home's list: the **recent** window, and the one count that decides whether the archive is offered.
///
/// Bounded by a date predicate rather than by a page size (changed 2026-08-31). Home draws `Today`
/// and `Previous 7 Days` and nothing older, so fetching in growing batches was fetching notes it had
/// already decided not to show — and a batch boundary that fell inside the window would have capped
/// a period by accident rather than by the rule that is supposed to cap it (`HomeLibrary`).
struct HomeLibraryList: View {
    @Environment(\.modelContext) private var context
    @Query private var recent: [Note]

    private let onSelect: (Note) -> Void
    private let onDelete: (Note) -> Void
    private let onBrowseOlder: () -> Void
    /// Owned by the Home screen, so expanding a period outlives opening a note from it.
    @Binding private var expanded: Set<NoteTimelineSection.Period>

    /// The size of the whole library, which by design is not what this view fetched.
    ///
    /// Counted rather than loaded: `fetchCount` is a `COUNT(*)`, so knowing whether an archive
    /// exists does not cost a materialised note per note. It is refreshed when Home appears and
    /// whenever the recent window changes, which is every moment a reader could have caused it to
    /// move. It is never *shown*: the size of the library is a statistic, and Home does not report
    /// statistics (RULES.md §4).
    @State private var total = 0

    init(now: Date = AppClock.now,
         calendar: Calendar = .current,
         expanded: Binding<Set<NoteTimelineSection.Period>>,
         onSelect: @escaping (Note) -> Void,
         onDelete: @escaping (Note) -> Void,
         onBrowseOlder: @escaping () -> Void) {
        self._expanded = expanded
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onBrowseOlder = onBrowseOlder

        // Inclusive of the whole seventh day back, matching `timelinePeriod`'s calendar-day
        // boundaries — the predicate and the bucketing MUST agree, or a note arrives on Home with
        // nowhere to be drawn.
        let cutoff = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))
            ?? calendar.startOfDay(for: now)
        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil && $0.createdAt >= cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        )
        descriptor.includePendingChanges = true
        _recent = Query(descriptor)
    }

    /// What the timeline actually renders. An editor may legitimately own an empty draft while it is
    /// open — Home must not put a row (or the separator that comes with one) under it in the
    /// meantime. See `NoteVisibility`.
    private var visible: [Note] { userVisibleNotes(recent) }

    /// Whether anything sits outside the window this view fetched — and so whether Home offers the
    /// archive at all (2026-08-31).
    ///
    /// Counted, not looked for. `HomeLibrary.hasOlderNotes` is the definition of the boundary and is
    /// tested as such, but it cannot be asked *here*: the query already excluded everything older
    /// than seven days, so searching the result for an older note would always answer no and the
    /// archive would never be offered. The two counts are both of undeleted notes over the same
    /// store, so their difference is exactly what the window left out.
    private var hasOlder: Bool { total > recent.count }

    var body: some View {
        Group {
            // Nothing recent is not nothing at all. A library whose newest note is a month old still
            // has a library behind it, and answering that with "Nothing here yet." would be telling
            // the reader their notes are gone.
            if visible.isEmpty && !hasOlder {
                EmptyHome()
            } else {
                HomeTimeline(notes: visible,
                             hasOlderNotes: hasOlder,
                             expanded: $expanded,
                             onSelect: onSelect,
                             onDelete: onDelete,
                             onBrowseOlder: onBrowseOlder)
            }
        }
        .task { refreshCount() }
        .onAppear { refreshCount() }
        .onChange(of: visible.count) { _, _ in refreshCount() }
    }

    private func refreshCount() {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt == nil })
        total = (try? context.fetchCount(descriptor)) ?? visible.count
    }
}

/// The complete timeline, loaded in batches via a growing `fetchLimit` (docs/05-architecture.md §8).
///
/// This is where Home's old behavior went. It stays reactive (new notes appear, deletes drop out) and
/// still never exposes a page number or a "Load more": the next batch arrives because the reader
/// scrolled, which is not a control (RULES.md §1).
struct AllNotesList: View {
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

    private var visible: [Note] { userVisibleNotes(notes) }

    var body: some View {
        if visible.isEmpty {
            EmptyHome()
        } else {
            AllNotesTimeline(notes: visible, onSelect: onSelect, onDelete: onDelete) {
                // Only ask for more when the current batch is full (there may be older notes). Counted
                // on the *fetched* notes, not the visible ones: the batch is what the query returned.
                if notes.count >= limit { onLoadMore() }
            }
        }
    }
}

/// Empty Home state.
///
/// The mark, one line naming the state, and the tagline. No card, no illustration panel, and no
/// call to action: the header already carries both ways into a note, and a second creation control
/// here would be the same verb twice. The second line is the locked tagline rather than new copy —
/// interface text must not encourage or coach the user (RULES.md §1, §4).
struct EmptyHome: View {
    var body: some View {
        VStack(spacing: DSSpacing.s4) {
            Spacer()
            // The one place brand colour is allowed on Home: the mark is identity, not content.
            FeatherMark(size: 44)
            VStack(spacing: DSSpacing.s2) {
                Text("Nothing here yet.")
                    .font(.ds.noteTitle)
                    .foregroundStyle(Color.ds.textPrimary)
                Text("Write it. Say it. Keep it.")
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DSSpacing.screenH)
    }
}
