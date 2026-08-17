import Foundation

/// Inserts a transcript verbatim into the body at a character offset, adding a single boundary space
/// only when needed to avoid gluing words together. Never rewrites/trims internal content (RULES.md §2,
/// docs/04-voice-transcription.md §8). Returns the new body and the caret position after the insertion.
func insertTranscript(_ transcript: String, into body: String, at offset: Int) -> (text: String, cursor: Int) {
    guard !transcript.isEmpty else { return (body, min(max(offset, 0), body.count)) }

    let clamped = min(max(offset, 0), body.count)
    let idx = body.index(body.startIndex, offsetBy: clamped)
    let before = String(body[body.startIndex..<idx])
    let after = String(body[idx..<body.endIndex])

    func isWordJoin(_ left: Character?, _ right: Character?) -> Bool {
        guard let left, let right else { return false }
        return !left.isWhitespace && !right.isWhitespace
    }

    let leadPad = isWordJoin(before.last, transcript.first) ? " " : ""
    let trailPad = isWordJoin(transcript.last, after.first) ? " " : ""

    let inserted = leadPad + transcript + trailPad
    let newText = before + inserted + after
    let cursor = before.count + inserted.count
    return (newText, cursor)
}
