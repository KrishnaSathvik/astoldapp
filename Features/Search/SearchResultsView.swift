import SwiftUI

/// Flat search results shown while searching. Lexical filter over title + body.
struct SearchResultsView: View {
    let notes: [Note]
    let query: String
    var onSelect: (Note) -> Void

    private var results: [Note] { searchNotes(notes, query: query) }

    var body: some View {
        Group {
            if results.isEmpty {
                VStack {
                    Spacer()
                    Text("No notes found.")
                        .font(.ds.preview)
                        .foregroundStyle(Color.ds.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(results) { note in
                        Button { onSelect(note) } label: { SearchResultRow(note: note) }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.ds.canvas)
                            .listRowInsets(EdgeInsets(top: DSSpacing.s4, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .background(Color.ds.canvas)
                .padding(.horizontal, DSSpacing.screenH)
            }
        }
        .background(Color.ds.canvas)
    }
}
