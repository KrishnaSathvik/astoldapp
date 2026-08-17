import Foundation

/// Whitespace-only titles normalize to nil; otherwise trimmed. See RULES.md §1 and §5.
func normalizedTitle(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
