import Foundation

// What leaves the app when someone taps Share, and nothing about how it leaves.
//
// Sharing one note is **not** the Pro Export & Restore feature (`docs/09-v2-roadmap.md` §2.2). That one
// is a library: selected notes, a versioned backup format, and a restore path. This is the note the
// person is looking at, handed to whatever they picked in the system sheet — the same thing Copy has
// always done, with a destination attached. It is free, it is local, and it needs no account
// (RULES.md §7, share exception, 2026-08-26).
//
// Two representations, because two kinds of destination exist and only the destination knows which it
// is. Mail and Notes can take HTML and keep the links and the indentation; Messages and WhatsApp want
// characters. Both are produced by `StructuredTextExport` — the same generator the pasteboard uses —
// because a second exporter is a second thing to keep in step, and the first divergence between them
// would be a note that copies correctly and shares wrongly.
//
// Nothing here mutates a note. It reads a snapshot and returns a value.

/// One note, ready to hand to the system share sheet.
struct NoteSharePayload: Equatable, Identifiable {

    /// Identity is the content, so presenting the sheet twice for the same note is the same
    /// presentation. Deliberately not a stored `UUID`: that would make two identical payloads unequal
    /// and turn `Equatable` into "was this the same object", which is not what any caller wants.
    var id: String { plainText }


    /// The note's title, or `nil` when it has none.
    ///
    /// Never the placeholder. "Title" is what an empty note *draws* to invite one, and shipping that
    /// word to somebody's Messages thread would be the interface leaking into the note (RULES.md §5).
    let title: String?

    /// The note as characters: what Messages, WhatsApp, and Copy receive.
    ///
    /// The page as it **reads**, not as it is stored — markers become their glyphs and a link becomes
    /// its words, exactly as on the pasteboard. A title, when there is one, leads and is followed by a
    /// blank line.
    let plainText: String

    /// The note as HTML: what Mail, Notes, and anything else that negotiates for it receive.
    ///
    /// Carries the links as `<a href>`, code and diagrams inside `<pre>` with their indentation, and a
    /// declared UTF-8 charset — which is the difference between an em dash arriving as "—" and as "â€”".
    let html: String?

    /// The note that produced this, as the sheet's own header should name it.
    ///
    /// The title when there is one; otherwise the note's first line, which is what every other surface
    /// in the app uses to stand in for an untitled note.
    var sheetTitle: String {
        if let title { return title }
        let firstLine = plainText.split(separator: "\n", omittingEmptySubsequences: true).first
        return firstLine.map(String.init) ?? ""
    }

    /// Builds the payload for a note, or `nil` when there is nothing to share.
    ///
    /// `nil` is the whole of the empty-note rule: an empty draft has no payload, so Share has nothing
    /// to be enabled for. Structure markers alone are not content — an abandoned `- ` is a note
    /// somebody started, not a note somebody wrote — which is the same test `Note.isEmptyDraft` applies.
    ///
    /// - Parameters:
    ///   - title: the note's title as stored. Blank or whitespace-only is no title.
    ///   - body: the note's source. **The editor's current text**, not the last autosaved copy — see
    ///     `BodyEditorActions.commitPendingEdits()`.
    static func make(title: String?, body: String) -> NoteSharePayload? {
        let trimmedTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedTitle.isEmpty ? nil : trimmedTitle

        let readable = StructuredTextExport.plainText(body)
        // Emptiness is judged on the note's **visible text**, exactly as `Note.isEmptyDraft` judges it —
        // not on the exported string. A body of "- " exports as "• ", which is not empty as a string and
        // is very much an empty note: the glyph is drawn by the marker, and nobody typed it.
        let hasBody = !MarkupDocument(body).visibleText()
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard name != nil || hasBody else { return nil }

        var plain = ""
        if let name { plain = hasBody ? name + "\n\n" + readable : name }
        else { plain = readable }

        return NoteSharePayload(title: name,
                                plainText: plain,
                                html: StructuredTextExport.html(body, title: name))
    }
}
