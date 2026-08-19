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
    @State private var selectedDay: Date?
    @State private var pageLimit = 40
    @AppStorage("profileName") private var profileName = ""
    @Environment(AppLockModel.self) private var lock

    private let calendar = Calendar.current

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
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
            .navigationDestination(item: $editingNote) { note in
                EditorView(
                    note: note,
                    onClose: { editingNote = nil },
                    // Same soft-delete + Undo path as a swipe on Home; the banner appears here,
                    // where the user lands.
                    onDelete: { note in
                        editingNote = nil
                        deletion.delete(note, in: context)
                    }
                )
            }
            .navigationDestination(isPresented: $showingCalendar) {
                CalendarPage(initialSelection: selectedDay) { day in
                    selectedDay = calendar.isDateInToday(day) ? nil : day
                }
            }
            .navigationDestination(isPresented: $showingProfile) {
                ProfileView(lock: lock)
            }
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
                            .symbolVariant(selectedDay == nil ? .none : .fill)
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
    }

    private var filterDateText: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        return df.string(from: selectedDay ?? .now)
    }

    private var profileInitial: String? {
        let t = profileName.trimmingCharacters(in: .whitespaces)
        guard let f = t.first else { return nil }
        return String(f).uppercased()
    }

    @ViewBuilder private var content: some View {
        if let selectedDay {
            VStack(spacing: 0) {
                HStack {
                    Text(filterDateText)
                        .font(.ds.groupTitle)
                        .foregroundStyle(Color.ds.textPrimary)
                    Spacer()
                    Button("Return to Today") { self.selectedDay = nil }
                        .font(.ds.preview)
                        .foregroundStyle(Color.ds.accent)
                }
                .padding(.horizontal, DSSpacing.screenH)
                .padding(.top, DSSpacing.s6)

                DayNotesList(day: selectedDay, onSelect: { editingNote = $0 },
                             onDelete: { deletion.delete($0, in: context) })
            }
        } else {
            PagedNotesList(
                limit: pageLimit,
                onSelect: { editingNote = $0 },
                onDelete: { deletion.delete($0, in: context) },
                onLoadMore: { pageLimit += 40 }
            )
        }
    }

    private func newNote() {
        let note = Note()
        context.insert(note)
        editingNote = note
    }

}
