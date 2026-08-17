import Foundation

/// Lexical, case- and diacritic-insensitive, Unicode-safe search over normalized title + body.
/// No embeddings, no semantic search (RULES.md §5). Empty query returns no results.
func noteMatches(_ note: Note, query: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return false }
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    if let title = normalizedTitle(note.title),
       title.range(of: q, options: options, range: nil, locale: .current) != nil {
        return true
    }
    return note.body.range(of: q, options: options, range: nil, locale: .current) != nil
}

/// Filters notes (already newest-first) to those matching the query, preserving order.
func searchNotes(_ notes: [Note], query: String) -> [Note] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }
    return notes.filter { noteMatches($0, query: q) }
}
