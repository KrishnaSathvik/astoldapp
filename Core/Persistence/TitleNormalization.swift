import Foundation

/// The title as it is **stored**: a title of nothing but whitespace is no title, and anything else is
/// exactly what the writer typed (RULES.md §5 — "`title` normalized: whitespace-only → nil").
///
/// It does not trim. A title is the writer's words, and the space they just pressed is one of them —
/// briefly the last one, every single time, because a space is always trailing until the next letter
/// arrives. Trimming on every autosave is what ate it: the store rewrote `"Alaska "` to `"Alaska"`
/// 400 ms after the keystroke, the model published the shorter value back to the text field, and the
/// space vanished from under the caret (fixed 2026-08-20).
///
/// Applied when an edit *ends*, never while one is in progress.
func storedTitle(_ raw: String?) -> String? {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return raw
}

/// The title as it is **shown** — in a timeline row, a search result, a preview. Read-only: this
/// trims for layout's sake so a stray leading space cannot indent a row, and never writes back.
func normalizedTitle(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
