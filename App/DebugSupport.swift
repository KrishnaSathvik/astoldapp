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
    /// Seeds a note holding a pasted table — for verifying how a table reads on the page.
    static var seedTableDemo: Bool { args.contains("-seedTableDemo") }
    /// Seeds one ordinary note that happens to use every structure — for the marketing capture that
    /// has to look like a note somebody wrote, not like a fixture exercising a feature list.
    static var seedSeattleDemo: Bool { args.contains("-seedSeattleDemo") }
    /// Seeds a short pasted note whose table is small enough to read at marketing scale.
    static var seedBudgetDemo: Bool { args.contains("-seedBudgetDemo") }
    /// Seeds a single spoken Hindi/English note — the Devanagari counterpart to `-seedVoiceDemo`.
    static var seedHindiDemo: Bool { args.contains("-seedHindiDemo") }
    /// Seeds one note far longer than a screen — for verifying that the writing toolbar never covers
    /// the line being written. Pair with `-openSeededNote -caretAtEnd`.
    static var seedLongNote: Bool { args.contains("-seedLongNote") }
    /// Opens the note with the body focused and the caret on its last line, which is the state the
    /// floating toolbar has to stay out of the way of.
    static var caretAtEnd: Bool { args.contains("-caretAtEnd") }
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

                Kenai Fjords cruise ఒకటి book చేయాలి, and Denali కి వెళ్లే day ని weather బట్టి decide చేద్దాం.

                Flights ఇంకా చూడలేదు. Next week rates check చేసి, cheaper ఉంటే dates కొంచెం మార్చుకుందాం.

                Camping option కూడా ఒకసారి చూద్దాం. Gear rent చేసుకుంటే two nights బయటే ఉండొచ్చు.

                అమ్మకి ముందే చెప్పాలి. లేకపోతే last minute లో మళ్ళీ అదే గోల.
                """
                context.insert(Note(title: "Alaska trip idea", body: body))
                try? context.save()
            }
            return
        }

        if seedHindiDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                इस weekend घर जाने का plan है, but Saturday meeting हुई तो Sunday morning निकलूँगा. Tickets अभी तक book नहीं की.

                घर पहुँचकर सबसे पहले अम्मा से बात करनी है — पिछली बार बहुत short call हुई थी.

                वापसी की train Monday early morning वाली ठीक रहेगी, so office भी miss नहीं होगा.

                अगर plan बदला तो अगले हफ़्ते try करेंगे. वैसे भी अभी तक कुछ भी confirm नहीं है.

                जाते वक़्त वो किताब साथ ले जानी है जो पिछली बार छूट गई थी.

                और हाँ, chacha ji के यहाँ भी एक बार हो आना चाहिए. बहुत दिन हो गए.
                """
                context.insert(Note(title: "Weekend plan", body: body))
                try? context.save()
            }
            return
        }

        if seedSeattleDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                # Three days, no schedule

                A relaxed few days with enough time to wander.

                ## Before we go

                - [ ] Book hotel
                - [x] Reserve dinner
                - [ ] Download offline maps

                ## Saturday

                1. Pike Place Market
                2. Ferry to Bainbridge
                3. Dinner near Capitol Hill

                ## Pack

                - Rain jacket
                - Camera
                - Portable charger
                """
                context.insert(Note(title: "Weekend in Seattle", body: body))
                try? context.save()
            }
            return
        }

        if seedBudgetDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                Pasted from the planning doc.

                ## Fixed costs

                | Item | Estimate |
                | --- | --- |
                | Hotel | $1,400 |
                | Rental car | $650 |
                | Boat tour | $229 |
                | Flights | $980 |

                ## Still to price

                - [ ] Ferry to Bainbridge
                - [ ] Parking downtown
                - [x] Museum passes

                The numbers move once the dates are fixed.
                """
                context.insert(Note(title: "Trip budget", body: body))
                try? context.save()
            }
            return
        }

        if seedLongNote {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let paragraphs = (1...14).map {
                    "Line \($0) of a long note that keeps going and going so the page has to scroll well past one screen."
                }
                let body = paragraphs.joined(separator: "\n\n") + "\n\nthen build the actual day-by-day itinerary only after we've loc"
                context.insert(Note(title: "Alaska planning", body: body))
                try? context.save()
            }
            return
        }

        if seedTableDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                Pasted from the trip plan.

                | Day | Date | Schedule | Park | Travel | Overnight | Meals |
                | --- | --- | --- | --- | --- | --- | --- |
                | 1 | Sat | Arrive & settle | — | 20 min | Anchorage | Dinner out |
                | 2 | Sun | Kenai Fjords cruise | Kenai Fjords | 5 hrs | Seward | Packed lunch |
                | 3 | Mon | Recovery day | — | 2 hrs | Anchorage | Groceries |

                Costs so far.

                | Expense | 2 people |
                | --- | --- |
                | 9 nights lodging | $2,400-$3,600 |
                | Rental car | $1,500-$2,000 |
                | Kenai Fjords cruise | $525-$625 |
                | Estimated total | $6,425-$9,275 |

                Still need to book the flight.

                One more paragraph so the page scrolls past a table and the card has to travel with the
                words rather than stay where it was first drawn.

                And another, for the same reason.
                """
                context.insert(Note(title: "Alaska itinerary", body: body))
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
