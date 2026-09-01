import SwiftUI

/// The complete timeline, behind **Browse older notes**.
///
/// The archive Home used to be. All four periods, nothing capped, the same rows — and, deliberately,
/// **nothing else**. It is fenced exactly the way the calendar's day list is fenced (RULES.md §1):
/// rows and period headings, no search of its own, no sort, no filter, no counts, no second row
/// design. The moment it grows a control the calendar was not allowed, As Told has the second
/// browsing surface that fence exists to prevent.
///
/// Search reaches any note from Home, and the calendar reaches any date. This screen exists for the
/// one question neither answers: *show me everything, in order*.
struct AllNotesTimeline: View {
    let notes: [Note]
    var onSelect: (Note) -> Void
    var onDelete: (Note) -> Void
    /// Fired when the bottom of the list scrolls into view — used to load the next batch.
    var onReachEnd: (() -> Void)? = nil

    /// One reading of the clock for the whole pass, for the same reason Home takes one: a render that
    /// straddles midnight must not bucket its first note against one "today" and its last against
    /// the next.
    private let now = AppClock.now

    private var sections: [NoteTimelineSection] { timelineSections(notes, now: now) }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.notes) { note in
                        Button { onSelect(note) } label: { NoteRow(note: note) }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.ds.surface)
                            .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.s4,
                                                      bottom: 0, trailing: DSSpacing.s4))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { onDelete(note) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(section.title)
                        .font(.ds.groupTitle)
                        .foregroundStyle(Color.ds.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .textCase(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, DSSpacing.s1)
                        .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.s4,
                                                  bottom: 0, trailing: DSSpacing.s4))
                }
            }

            Section {
                Color.clear.frame(height: 96)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .accessibilityHidden(true)
                    .onAppear { onReachEnd?() }   // near the bottom → load the next batch
            }
        }
        .listStyle(.insetGrouped)
        .listRowSeparatorTint(Color.ds.separator)
        .listSectionSpacing(DSSpacing.s6)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .environment(\.defaultMinListRowHeight, 8)
        .background(Color.ds.groupedCanvas)
    }
}

/// The screen **Browse older notes** pushes.
///
/// Owns the batch limit and nothing else — the fence above is kept by having nothing here to keep it
/// from. Its own navigation title names it; Home's controls stay on Home.
struct AllNotesView: View {
    var onSelect: (Note) -> Void
    var onDelete: (Note) -> Void

    @State private var pageLimit = 40

    var body: some View {
        ZStack {
            Color.ds.groupedCanvas.ignoresSafeArea()
            AllNotesList(limit: pageLimit,
                         onSelect: onSelect,
                         onDelete: onDelete,
                         onLoadMore: { pageLimit += 40 })
        }
        .navigationTitle("All Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
