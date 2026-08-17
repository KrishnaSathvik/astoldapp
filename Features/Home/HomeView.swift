import SwiftUI
import SwiftData

/// Home is the complete chronological notes timeline. See docs/01-product-requirements.md §8.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Note> { $0.deletedAt == nil },
           sort: \Note.createdAt, order: .reverse)
    private var notes: [Note]

    @State private var editingNote: Note?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.ds.canvas.ignoresSafeArea()
                content
                FloatingNewNoteButton(action: newNote)
                    .padding(DSSpacing.s6)
            }
            .navigationDestination(item: $editingNote) { note in
                EditorView(note: note)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Calendar navigation — wired in the Calendar slice (Phase 6).
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.ds.textSecondary)
                        .accessibilityLabel("Open calendar")
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if notes.isEmpty {
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
            HomeTimeline(notes: notes) { editingNote = $0 }
        }
    }

    private func newNote() {
        let note = Note()
        context.insert(note)
        editingNote = note
    }
}
