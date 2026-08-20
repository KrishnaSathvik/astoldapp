import Testing
import Foundation
import SwiftData
@testable import Yourly

/// A note whose only content arrived by voice must survive leaving the editor.
///
/// Reported from device testing 2026-08-19: the transcript is visible in the editor after Done, and
/// the note is gone from the timeline after Back — but only for the first recording.
@MainActor
struct VoiceDraftPersistenceTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    /// A real on-disk store, like the app's. Delete-then-reinsert is exactly the operation under
    /// suspicion, and an in-memory container is not evidence about what SwiftData does on disk.
    private func makePersistentContext() throws -> ModelContext {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("astold-\(UUID().uuidString).store")
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    /// The device sequence for a first-ever recording, against a real on-disk store: a new empty
    /// draft is open, the microphone permission alert resigns active so the editor flushes, and the
    /// transcript lands afterwards into that same note.
    @Test func voiceTranscriptSurvivesAnInterruptionInAPersistentStore() throws {
        let context = try makePersistentContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.flush()                                   // interrupted while still empty

        model.insertVoiceTranscript("Hello from voice", atUTF16: 0)
        model.finish()

        let notes = try liveNotes(context)
        #expect(notes.count == 1)
        #expect(notes.first?.body.contains("Hello from voice") == true)
    }

    private func liveNotes(_ context: ModelContext) throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt == nil }))
    }

    /// The straightforward path: nothing has flushed yet when the transcript lands.
    @Test func voiceTranscriptIntoAFreshDraftSurvivesLeaving() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.insertVoiceTranscript("Hello from voice", atUTF16: 0)
        model.finish()

        let notes = try liveNotes(context)
        #expect(notes.count == 1)
        #expect(notes.first?.body.contains("Hello from voice") == true)
    }

    /// The path a real recording actually takes: the microphone permission alert resigns the app
    /// active while the note is still empty, so a flush runs before a single word exists.
    @Test func voiceTranscriptSurvivesAFlushWhileStillEmpty() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.flush()                                   // interrupted while still empty

        model.insertVoiceTranscript("Hello from voice", atUTF16: 0)
        model.finish()

        let notes = try liveNotes(context)
        #expect(notes.count == 1)
        #expect(notes.first?.body.contains("Hello from voice") == true)
    }

    /// The same shape, but for typing rather than voice — the body setter takes the same route.
    @Test func typingAfterAnInterruptionSurvivesLeaving() throws {
        let context = try makeContext()
        let note = Note(); context.insert(note)
        let model = EditorModel(note: note, context: context)

        model.flush()

        model.body = "typed after the interruption"
        model.finish()

        #expect(try liveNotes(context).count == 1)
    }
}
