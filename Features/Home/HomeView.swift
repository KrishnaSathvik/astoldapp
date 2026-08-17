import SwiftUI
import SwiftData

/// Home is the complete chronological notes timeline. See docs/01-product-requirements.md §8.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Note> { $0.deletedAt == nil },
           sort: \Note.createdAt, order: .reverse)
    private var notes: [Note]

    @State private var editingNote: Note?
    @State private var recentlyDeleted: Note?
    @State private var undoDismiss: Task<Void, Never>?
    @State private var searchQuery = ""
    @State private var showingCalendar = false
    @State private var showingSettings = false
    @State private var selectedDay: Date?
    @Environment(AppLockModel.self) private var lock

    private let calendar = Calendar.current

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Notes shown in the timeline — all, or filtered to the selected calendar day.
    private var visibleNotes: [Note] {
        guard let selectedDay else { return notes }
        return notes.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDay) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.ds.canvas.ignoresSafeArea()
                if isSearching {
                    SearchResultsView(notes: notes, query: searchQuery) { editingNote = $0 }
                } else {
                    content
                    if recentlyDeleted != nil {
                        UndoBanner(onUndo: undoDelete)
                            .padding(.bottom, DSSpacing.s4)
                    }
                }
            }
            .searchable(text: $searchQuery, prompt: "Search notes")
            .sheet(isPresented: $showingCalendar) {
                CalendarSheet(initialSelection: selectedDay) { day in
                    selectedDay = calendar.isDateInToday(day) ? nil : day
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(lock: lock)
            }
            #if DEBUG
            .task {
                if let q = DebugLaunch.presetSearch { searchQuery = q }
                if DebugLaunch.openCalendar { showingCalendar = true }
                if DebugLaunch.openSettings { showingSettings = true }
            }
            #endif
            .animation(DSMotion.standard, value: recentlyDeleted != nil)
            .navigationDestination(item: $editingNote) { note in
                EditorView(note: note)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCalendar = true } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(selectedDay == nil ? Color.ds.textSecondary : Color.ds.accent)
                    }
                    .accessibilityLabel("Open calendar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newNote) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.ds.accent)
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

                if visibleNotes.isEmpty {
                    Spacer()
                    Text("No notes on this day.")
                        .font(.ds.preview)
                        .foregroundStyle(Color.ds.textSecondary)
                    Spacer()
                } else {
                    HomeTimeline(notes: visibleNotes, onSelect: { editingNote = $0 }, onDelete: deleteNote)
                }
            }
        } else if notes.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.s2) {
                Text(HomeDate.top)
                    .font(.ds.dateLabel)
                    .foregroundStyle(Color.ds.textTertiary)
                Text("Today")
                    .font(.ds.homeTitle)
                    .foregroundStyle(Color.ds.textPrimary)
                Spacer().frame(height: DSSpacing.s10)
                Text("Your thoughts will appear here.")
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.screenH)
            .padding(.top, DSSpacing.s6)
        } else {
            HomeTimeline(notes: notes, onSelect: { editingNote = $0 }, onDelete: deleteNote)
        }
    }

    private func newNote() {
        let note = Note()
        context.insert(note)
        editingNote = note
    }

    private func deleteNote(_ note: Note) {
        note.deletedAt = .now
        try? context.save()
        recentlyDeleted = note
        undoDismiss?.cancel()
        undoDismiss = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            recentlyDeleted = nil
        }
    }

    private func undoDelete() {
        undoDismiss?.cancel()
        recentlyDeleted?.deletedAt = nil
        try? context.save()
        recentlyDeleted = nil
    }
}
