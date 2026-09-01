import SwiftUI

/// The Home library: the **recent** notes, bucketed by relative age, each bucket drawn as one grouped
/// surface of dense rows (RULES.md §1 and §4, amended 2026-08-30 and again 2026-08-31).
///
/// An **inset-grouped `List`**, not a hand-built stack of rounded rectangles in a `ScrollView`. The
/// grouped container, the hairlines between rows, their inset, the section semantics VoiceOver
/// reads, and swipe-to-delete are all things the platform already draws correctly at every Dynamic
/// Type size — and swipe-to-delete is the one that cannot be got back once the list stops being a
/// list (RULES.md §4: prefer native controls where they already solve the interaction).
///
/// **Home stops at the recent periods.** `Today` and `Previous 7 Days`, each capped and each able to
/// be opened and shut again, then — *only if something is actually older* — a way into the archive.
/// Home used to be the entire archive, and at a few hundred notes that made the landing screen a
/// database rather than a place to land. Reaching a date is still the calendar's question; finding a
/// note is still search's; the complete timeline is one tap away and unchanged in shape.
struct HomeTimeline: View {
    let notes: [Note]
    /// Whether anything sits outside the periods Home draws. Passed in rather than derived: the
    /// notes this view was given are the recent window, so they cannot answer a question about what
    /// is older than they are (`HomeLibraryList.hasOlder`).
    let hasOlderNotes: Bool
    /// Which periods the reader has opened up, owned by the Home **visit** rather than by this view.
    ///
    /// Held above so it survives everything that happens without leaving Home: opening a note and
    /// coming back, a count refresh, the library changing under it. A period that re-collapsed
    /// because the reader read one of its notes would make the affordance feel like it had not
    /// worked. Deliberately not persisted across launches — it is a way of looking, not a setting.
    @Binding var expanded: Set<NoteTimelineSection.Period>
    var onSelect: (Note) -> Void
    var onDelete: (Note) -> Void
    var onBrowseOlder: () -> Void


    /// One reading of the clock for the whole pass. Taken here rather than inside the bucketing so a
    /// render that straddles midnight cannot sort its first note against one "today" and its last
    /// against the next.
    private let now = AppClock.now

    private var sections: [HomeLibrarySection] {
        HomeLibrary.sections(notes, now: now, expanded: expanded)
    }

    var body: some View {
        List {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
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
                    // Only the first heading carries the date; below it the reader is already
                    // oriented, and repeating it would be the screen telling the time twice.
                    SectionHeader(title: section.title, date: index == 0 ? HomeDate.top : nil)
                } footer: {
                    // The cap's own way past it — and back — under the group it belongs to rather
                    // than inside it: it is not a note and must not be drawn as a row (RULES.md §4).
                    if section.isCollapsible {
                        ExpandToggle(section: section) { toggle(section.period) }
                    }
                }
            }

            // Only when there is somewhere else to go. When Home already holds the whole library,
            // `Show all N` has exposed all of it and this would lead to the same notes one screen
            // further away (`HomeLibrary.hasOlderNotes`).
            if hasOlderNotes {
                Section {
                    BrowseOlderNotes(action: onBrowseOlder)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Tail inset clears the floating search field so the last row is never half-hidden
            // behind it (§6 — search must be available without dominating Home).
            Section {
                Color.clear.frame(height: 96)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .accessibilityHidden(true)
            }
        }
        .listStyle(.insetGrouped)
        .listRowSeparatorTint(Color.ds.separator)
        // Tighter than the platform default: the reference's gaps turn scrolling into whitespace at
        // this row density (docs/03-design-system.md §4.3).
        .listSectionSpacing(DSSpacing.s6)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)                   // quiet editorial: no visible scrollbar
        .environment(\.defaultMinListRowHeight, 8)   // let rows hug their content
        .background(Color.ds.groupedCanvas)
    }

    /// Open a capped period, or shut one that is open. The same control both ways, because from the
    /// reader's side it is one question — *am I looking at all of this or not*.
    private func toggle(_ period: NoteTimelineSection.Period) {
        withAnimation(DSMotion.standard) {
            if expanded.contains(period) { expanded.remove(period) } else { expanded.insert(period) }
        }
    }
}

/// Shared "AUGUST 31, 2026" top-date string for Home.
enum HomeDate {
    static var top: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        return df.string(from: AppClock.now).uppercased()
    }
}

/// A period heading over its group, and — on the first one only — the current date above it.
///
/// Title case and primary ink for the heading: something a reader reads, not the small grey all-caps
/// label a settings screen uses to caption a block of switches. The date is the opposite on purpose —
/// small, tertiary, all-caps — because it orients rather than announces.
///
/// The date rides on the first heading rather than occupying a row or a section of its own. As its
/// own section the platform gave it a full section's spacing above *and* below, and the top of Home
/// was mostly empty before the first note (`docs/03-design-system.md` §4.3).
private struct SectionHeader: View {
    let title: String
    let date: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s1) {
            if let date {
                Text(date)
                    .font(.ds.dateLabel)
                    .foregroundStyle(Color.ds.textTertiary)
            }
            Text(title)
                .font(.ds.groupTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .textCase(nil)                               // never SHOUT a heading
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DSSpacing.s1)
        .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.s4,
                                  bottom: 0, trailing: DSSpacing.s4))
    }
}

/// `Show all 7` ⇄ `Show less` — the cap's way past itself, and back.
///
/// Names the **whole period**, never the remainder. "Show all 3 more" describes a batch and is one
/// `Load more` away from being pagination; "Show all 7" describes the state of something the reader
/// can already see the top of. Quiet, secondary, and left-aligned under its group: it is a way of
/// looking at what is on screen, not an action on a note.
///
/// **Reversible** (2026-08-31). One-way expansion left a fourteen-row `Previous 7 Days` open with no
/// way back short of leaving Home, which made a glance feel like a commitment. Same control, same
/// place, so the reader never has to look for the way back.
private struct ExpandToggle: View {
    let section: HomeLibrarySection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(section.isExpanded ? "Show less" : "Show all \(section.total)")
                .font(.ds.preview)
                .foregroundStyle(Color.ds.accent)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DSSpacing.s2)
        .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.s4, bottom: 0, trailing: DSSpacing.s4))
        .accessibilityHint(section.isExpanded ? "Collapses this group back"
                                             : "Shows the rest of this group")
    }
}

/// Where Home ends and the archive begins.
///
/// Named for **why you would tap it**, not for what the next screen is called (2026-08-31). `View
/// All Notes` sat under a `Show all 14` that led to the same fourteen notes, and the two read as the
/// same offer made twice; `Browse older notes` says the one thing `Show all N` cannot do. The screen
/// it opens is still titled `All Notes` — that title names where you have arrived, which is a
/// different job from naming a destination you have not chosen yet.
///
/// Drawn only when notes exist outside the periods Home holds, so it is never a control with nothing
/// to do (`HomeTimeline`).
private struct BrowseOlderNotes: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.s1) {
                Text("Browse older notes")
                // Punctuation, not a second thing to hear. Hidden here rather than by collapsing the
                // Button into one accessibility element: `.accessibilityElement(children: .ignore)`
                // on a `Button` publishes a *container* alongside the button, and the archive then
                // matches two elements — which is a real ambiguity for anything driving the screen,
                // not only for the test that caught it.
                Image(systemName: "chevron.right")
                    .font(.ds.caption)
                    .accessibilityHidden(true)
            }
            .font(.ds.preview)
            .foregroundStyle(Color.ds.accent)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.s4,
                                  bottom: 0, trailing: DSSpacing.s4))
        .accessibilityHint("Opens the complete timeline")
    }
}
