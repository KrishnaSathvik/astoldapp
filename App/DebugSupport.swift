#if DEBUG
import Foundation
import SwiftData

/// Launch-argument hooks used only for local verification / screenshots. Never compiled for release.
///  -seedSampleNotes   inserts a small demo timeline (idempotent within a fresh store)
///  -openSampleEditor  routes straight into a new Editor
///  -hasCompletedWelcome YES   (handled automatically by UserDefaults launch args)
enum DebugLaunch {
    static var seedSampleNotes: Bool { args.contains("-seedSampleNotes") }
    /// Seeds the sample timeline shifted back a week, so nothing lands on today — the case where
    /// Home must still anchor on `Today` rather than opening on `Yesterday`.
    static var seedOlderNotesOnly: Bool { args.contains("-seedOlderNotesOnly") }
    static var openSampleEditor: Bool { args.contains("-openSampleEditor") }
    /// Seeds a single note exercising every structure type — for verifying live-styled rendering.
    static var seedStructuredDemo: Bool { args.contains("-seedStructuredDemo") }
    /// Seeds a single spoken, code-switched note — for the multilingual voice screenshot.
    static var seedVoiceDemo: Bool { args.contains("-seedVoiceDemo") }
    /// Opens the newest seeded note in the editor — the *existing note* (reading) path.
    static var openSeededNote: Bool { args.contains("-openSeededNote") }
    static var openCalendar: Bool { args.contains("-openCalendar") }
    static var openSettings: Bool { args.contains("-openSettings") }
    static var autoStartVoice: Bool { args.contains("-autoStartVoice") }
    static var openAbout: Bool { args.contains("-openAbout") }
    static var openPrivacy: Bool { args.contains("-openPrivacy") }
    static var openTheme: Bool { args.contains("-openTheme") }
    static var forceLocked: Bool { args.contains("-forceLocked") }
    /// Wipe all notes on launch — used by UI tests so each starts from a clean, seeded store.
    static var resetStore: Bool { args.contains("-resetStore") }
    /// Value after `-searchQuery` — presets the Home search field for screenshots.
    static var presetSearch: String? {
        guard let i = args.firstIndex(of: "-searchQuery"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        if resetStore {
            for note in (try? context.fetch(FetchDescriptor<Note>())) ?? [] { context.delete(note) }
            try? context.save()
        }
        if seedVoiceDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                నాకు Alaska trip గురించి ఒక idea వచ్చింది. Maybe మనం Anchorage లో whole week stay చేయకుండా, Seward లో two nights stay చేస్తే better ఉంటుంది.

                Rest of the days రోడ్డు మీద ఉంటాం — that way we actually see something.
                """
                context.insert(Note(title: "Alaska trip idea", body: body))
                try? context.save()
            }
            return
        }

        if seedStructuredDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                # Why winter feels different

                I visited in January and the first thing I noticed was how quiet it felt.

                ## What to pack

                - warm layers
                - empty roads

                Launch checklist

                - [ ] Finish screenshots
                - [x] Privacy page
                - [ ] TestFlight

                1. Anchorage
                2. Seward
                3. Denali
                """
                context.insert(Note(title: "Yellowstone notes", body: body))
                try? context.save()
            }
            return
        }

        guard seedSampleNotes || seedOlderNotesOnly else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
        guard existing == 0 else { return }

        let cal = Calendar.current
        // Shifted a week back when only older notes are wanted, so no sample lands on today.
        let shift = seedOlderNotesOnly ? 7 : 0
        func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = cal.date(byAdding: .day, value: -(daysAgo + shift), to: .now)!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }

        let samples: [(String?, String, Date)] = [
            ("Alaska trip idea",
             "I keep thinking maybe instead of staying the entire week in Anchorage we could rent a car and drive down toward Seward for a couple of nights.",
             at(0, 9, 12)),
            ("Something I remembered",
             "Need to call them tomorrow and ask about what happened with the paperwork before it gets too late in the week.",
             at(0, 8, 40)),
            (nil,
             "I don't know why but today I suddenly started thinking about that summer and how quiet everything felt.",
             at(0, 7, 5)),
            ("Random thoughts at night",
             "It's weird how some songs take you back to a place you didn't even realize you missed.",
             at(1, 22, 30)),
            ("Work ideas",
             "New project direction looks promising. Need to research a couple of the tradeoffs before the sync.",
             at(2, 14, 15)),
        ]

        for (title, body, date) in samples {
            let note = Note(title: title, body: body, createdAt: date, updatedAt: date)
            context.insert(note)
        }
        try? context.save()
    }
}
#endif
