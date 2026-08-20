import SwiftUI
import SwiftData

/// Home is the complete chronological notes timeline. See docs/01-product-requirements.md §8.
struct HomeView: View {
    @Environment(\.modelContext) private var context

    @State private var editingNote: Note?
    @State private var deletion = NoteDeletion()
    @State private var searchQuery = ""
    @State private var showingCalendar = false
    @State private var showingProfile = false
    @State private var pageLimit = 40
    @AppStorage("profileName") private var profileName = ""
    @Environment(AppLockModel.self) private var lock

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            // Home's own screen owns Home's chrome. `.searchable` and the profile / calendar /
            // compose controls live *inside* it rather than on the view that also declares the
            // stack's destinations — otherwise they read as chrome belonging to the stack, and a
            // pushed editor spent the whole transition with Home's search field still anchored to
            // the bottom of it and Home's glass controls floating over its content.
            homeScreen
                .navigationDestination(item: $editingNote) { note in
                    // Deleting a note happens on the timeline, by swiping it. The editor deliberately
                    // carries no delete of its own — see RULES.md §4.
                    EditorView(note: note, onClose: { editingNote = nil })
                }
                .navigationDestination(isPresented: $showingCalendar) {
                    CalendarPage()
                }
                .navigationDestination(isPresented: $showingProfile) {
                    ProfileView(lock: lock)
                }
        }
    }

    private var homeScreen: some View {
        ZStack(alignment: .bottom) {
            Color.ds.canvas.ignoresSafeArea()
            if isSearching {
                SearchResultsView(query: searchQuery) { editingNote = $0 }
            } else {
                content
                if deletion.pending != nil {
                    UndoBanner { deletion.undo(in: context) }
                        .padding(.bottom, DSSpacing.s4)
                }
            }
        }
        .searchable(text: $searchQuery, prompt: "Search notes")
        #if DEBUG
        .task {
            if let q = DebugLaunch.presetSearch { searchQuery = q }
            if DebugLaunch.openCalendar { showingCalendar = true }
            if DebugLaunch.openSettings { showingProfile = true }
        }
        #endif
        .animation(DSMotion.standard, value: deletion.pending != nil)
        .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingProfile = true } label: {
                        if let profileInitial {
                            Text(profileInitial)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.ds.iconProfile)
                        } else {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(Color.ds.iconProfile)
                        }
                    }
                    .accessibilityLabel("Profile")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCalendar = true } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.ds.iconCalendar)
                    }
                    .accessibilityLabel("Open calendar")
                }
                // No ToolbarSpacer here: calendar and compose share one capsule, so the header
                // reads as two grouped controls rather than three unrelated floating islands (§5).
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newNote) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.ds.iconCompose)
                    }
                    .accessibilityLabel("New note")
                }
        }
    }

    private var profileInitial: String? {
        let t = profileName.trimmingCharacters(in: .whitespaces)
        guard let f = t.first else { return nil }
        return String(f).uppercased()
    }

    /// Home is always the whole timeline. Browsing a single day belongs to the calendar, which
    /// shows that day's notes under its own grid rather than sending the reader back here filtered.
    private var content: some View {
        PagedNotesList(
            limit: pageLimit,
            onSelect: { editingNote = $0 },
            onDelete: { deletion.delete($0, in: context) },
            onLoadMore: { pageLimit += 40 }
        )
    }

    private func newNote() {
        let note = Note()
        context.insert(note)
        editingNote = note
    }

}
