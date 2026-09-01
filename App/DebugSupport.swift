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
    /// Seeds more notes into today than Home's cap draws, so the `Show all N` affordance exists to
    /// be tapped. Seven, because seven untitled captures in one afternoon is the wall the cap was
    /// added for (`HomeLibrary`).
    static var seedCappedToday: Bool { args.contains("-seedCappedToday") }
    static var openSampleEditor: Bool { args.contains("-openSampleEditor") }
    /// Seeds a single note exercising every structure type — for verifying live-styled rendering.
    static var seedStructuredDemo: Bool { args.contains("-seedStructuredDemo") }
    /// Seeds a note holding a pasted table — for verifying how a table reads on the page.
    static var seedTableDemo: Bool { args.contains("-seedTableDemo") }
    /// Seeds a note holding a pasted code block between two paragraphs, plus a table — for verifying
    /// that editing one structured block leaves every other one rendered.
    static var seedCodeDemo: Bool { args.contains("-seedCodeDemo") }
    /// Seeds one note holding the three real diagrams — a pipeline, a wide decision flow, and a
    /// directory tree — as preformatted blocks. For looking at what a diagram actually renders as,
    /// which is the one thing a measurement cannot tell you.
    static var seedDiagramDemo: Bool { args.contains("-seedDiagramDemo") }
    /// Which diagram to seed on its own — `pipeline`, `flow`, or `tree`. Absent seeds all three.
    static var diagramChoice: String? {
        guard let i = args.firstIndex(of: "-diagram"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    /// Seeds one ordinary note that happens to use every structure — for the marketing capture that
    /// has to look like a note somebody wrote, not like a fixture exercising a feature list.
    static var seedSeattleDemo: Bool { args.contains("-seedSeattleDemo") }
    /// Seeds a short pasted note whose table is small enough to read at marketing scale.
    static var seedBudgetDemo: Bool { args.contains("-seedBudgetDemo") }
    /// Seeds a note somebody kept a query in — the marketing counterpart to `-seedCodeDemo`, which is
    /// a parser fixture the code-block tests drive and reads like one.
    static var seedQueryDemo: Bool { args.contains("-seedQueryDemo") }
    /// Seeds a single spoken Hindi/English note — the Devanagari counterpart to `-seedVoiceDemo`.
    static var seedHindiDemo: Bool { args.contains("-seedHindiDemo") }

    // MARK: The App Store raw library (added 2026-08-29)
    //
    // Seven seeds whose only job is to be *believable* — a library and six notes that read like
    // somebody's, not like fixtures. The older seeds above stay: the tests drive them, and a
    // fixture that has to survive an assertion is not free to read well.

    /// Seeds a Home timeline of ordinary notes with distinct names and short previews — the library
    /// screenshot, where the point is that a real person has been using this for a while.
    static var seedShowcaseNotes: Bool { args.contains("-seedShowcaseNotes") }
    /// Seeds one note carrying heading, subheading, bullets, a numbered list, a checklist and a link
    /// — every structure at once, still reading as a trip somebody is planning.
    static var seedAlaskaDemo: Bool { args.contains("-seedAlaskaDemo") }
    /// Seeds prose, a SQL card, then more prose — the point being that writing continues *after* a
    /// code block, which is the thing a code-block screenshot usually fails to show.
    static var seedSQLDemo: Bool { args.contains("-seedSQLDemo") }
    /// Seeds a small, legible planning table with words and a link around it.
    static var seedJapanDemo: Bool { args.contains("-seedJapanDemo") }
    /// Seeds a preformatted architecture diagram between two paragraphs — pasted structure that is
    /// visibly not code.
    static var seedArchitectureDemo: Bool { args.contains("-seedArchitectureDemo") }
    /// Seeds a spoken note that moves between languages mid-sentence and still reads as a Saturday.
    static var seedWeekendThoughtsDemo: Bool { args.contains("-seedWeekendThoughtsDemo") }
    /// Seeds an ordinary, beautiful, entirely unstructured note — no table, no code, no gimmick.
    static var seedSundayDemo: Bool { args.contains("-seedSundayDemo") }

    // MARK: Marketing refresh raw library (2026-08-31)

    /// Seeds the redesigned Home with two notes today and eleven in Previous 7 Days. The latter is
    /// intentionally over its five-row cap so the raw shows the real `Show all 11` affordance.
    static var seedMarketingHome: Bool { args.contains("-seedMarketingHome") }
    /// Seeds the titleless, multi-paragraph result of a natural Quick Voice capture.
    static var seedMarketingVoiceNote: Bool { args.contains("-seedMarketingVoiceNote") }
    /// Seeds the structured Japan Trip note used for the clean, toolbar, Light and Dark raws.
    static var seedMarketingJapan: Bool { args.contains("-seedMarketingJapan") }
    /// Seeds the realistic pasted trip budget requested for the marketing refresh.
    static var seedMarketingBudget: Bool { args.contains("-seedMarketingBudget") }
    /// Seeds the SQL note requested for the marketing refresh.
    static var seedMarketingSQL: Bool { args.contains("-seedMarketingSQL") }
    /// Seeds August 31 with four notes and surrounding dates with one-to-three activity dots.
    static var seedMarketingCalendar: Bool { args.contains("-seedMarketingCalendar") }

    // MARK: The canonical demo library (2026-09-01) — see `library` below

    /// Seeds the whole library as Home draws it. `-pinnedNow` decides which day is today.
    static var seedLibraryHome: Bool { args.contains("-seedLibraryHome") }
    /// Seeds the same library redistributed over the visible month, for the calendar raw.
    static var seedLibraryCalendar: Bool { args.contains("-seedLibraryCalendar") }
    /// Value after `-seedLibraryNote`: the key of one library note to seed alone, at `demoNoteDate`,
    /// for an editor raw. Titled notes are keyed by title; the titleless voice note is `voice`.
    static var seedLibraryNote: String? { value(after: "-seedLibraryNote") }
    /// Value after `-pinnedNow`, `yyyy-MM-dd'T'HH:mm:ss` in the simulator's own time zone — what
    /// `AppClock.now` answers for the whole launch. Parsed once: the grid asks per cell.
    static let pinnedNow: Date? = {
        guard let raw = value(after: "-pinnedNow") else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: raw)
    }()
    private static func value(after flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    /// Seeds one note far longer than a screen — for verifying that the writing toolbar never covers
    /// the line being written. Pair with `-openSeededNote -caretAtEnd`.
    static var seedLongNote: Bool { args.contains("-seedLongNote") }
    /// Opens the note with the body focused and the caret on its last line, which is the state the
    /// floating toolbar has to stay out of the way of.
    static var caretAtEnd: Bool { args.contains("-caretAtEnd") }
    /// Opens an existing note with the body focused at its first character. Used by the keyboard-up
    /// marketing raw so the note's title and opening structure stay visible above the keyboard.
    static var caretAtStart: Bool { args.contains("-caretAtStart") }
    /// Seeds a single spoken, code-switched note — for the multilingual voice screenshot.
    static var seedVoiceDemo: Bool { args.contains("-seedVoiceDemo") }
    /// Opens the newest seeded note in the editor — the *existing note* (reading) path.
    static var openSeededNote: Bool { args.contains("-openSeededNote") }
    static var openCalendar: Bool { args.contains("-openCalendar") }
    static var openSettings: Bool { args.contains("-openSettings") }
    static var autoStartVoice: Bool { args.contains("-autoStartVoice") }
    /// Opens Home's Quick Voice capture on launch, already recording — the marketing capture of the
    /// microphone entry point, which no other flag can reach because it lives behind a tap on Home.
    static var openQuickVoice: Bool { args.contains("-openQuickVoice") }
    /// Pauses a recording shortly after it starts, so the **Paused** state can be captured. It is
    /// the same `pause()` the button calls; nothing about the state is faked.
    static var voiceAutoPause: Bool { args.contains("-voiceAutoPause") }
    /// How long `-voiceAutoPause` records before pausing, in seconds. Default 1.5, which is all a
    /// UI test needs; a screenshot wants a timer that does not read as staged, so the capture script
    /// passes the number it wants to see on the clock.
    static var voicePauseAfter: TimeInterval {
        guard let i = args.firstIndex(of: "-voicePauseAfter"), i + 1 < args.count,
              let value = TimeInterval(args[i + 1]) else { return 1.5 }
        return value
    }
    /// Holds an in-note recording open indefinitely instead of finishing it after 1.5s. The
    /// counterpart to `-voiceAutoPause` for the *recording* state — Quick Voice already holds, but
    /// the in-note panel auto-finishes, and a screenshot cannot outrun that.
    static var voiceHold: Bool { args.contains("-voiceHold") }
    /// Drives the waveform from a speech-shaped level rather than the simulator's silent microphone.
    ///
    /// A simulator has no audio input, so the real recorder reports the floor and `WaveformView`
    /// draws a flat dashed line — a screenshot of a recorder that is visibly hearing nothing. This
    /// swaps in the stand-in recorder (a real file, the real state machine, the real view) with a
    /// level that moves the way a voice does. It changes what the microphone reports, and nothing
    /// else. On a device, capture without it.
    static var voiceDemoLevels: Bool { args.contains("-voiceDemoLevels") }
    /// Presents the system Share sheet over the open note — the only way to capture it, since the
    /// sheet is iOS's own view and appears on a tap.
    static var openShare: Bool { args.contains("-openShare") }
    /// Drives a capture with a stand-in recorder and a transcription that always fails the way a
    /// dropped connection does — so the retained-recording surface can be touched by a UI test
    /// without a microphone, a network, or a permission alert (`docs/10-voice-v2.md` §13).
    static var voiceFakeFailure: Bool { args.contains("-voiceFakeFailure") }
    /// The same, except the *second* attempt succeeds — the Retry path, end to end.
    static var voiceFakeRetrySucceeds: Bool { args.contains("-voiceFakeRetrySucceeds") }
    /// A transcription that works first time — for driving a recovered recording straight to a note.
    static var voiceFakeSuccess: Bool { args.contains("-voiceFakeSuccess") }
    /// Plants one retained recording, as if a capture had failed before the app was last closed, so
    /// the recovery surface can be touched by a UI test without killing the app mid-flow.
    static var seedRetainedRecording: Bool { args.contains("-seedRetainedRecording") }
    /// A transcription slow enough to leave the note *during* it — the one state a UI test cannot
    /// otherwise catch, because a fast fake is over before a tap can land.
    static var voiceFakeSlow: Bool { args.contains("-voiceFakeSlow") }
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

    /// Creation stamp for every single-note demo seed.
    ///
    /// The editor caption renders the note's own `createdAt`, and every screenshot capture pins the
    /// status bar to 9:41 (`docs/appstore/README.md`). A note created at the wall-clock moment of
    /// capture therefore puts two different times in one frame — a 9:41 status bar above an
    /// "AUGUST 21, 2026 · 22:31" caption — which reads as a bug in the product rather than in the
    /// screenshot. Pinning the seed to 9:41 makes the frame agree with itself, and it agrees in
    /// both hour cycles: a 24-hour simulator renders it "09:41" and a 12-hour one "9:41 AM".
    ///
    /// Today's date, not a fixed one: a demo note dated months ago would contradict the timeline
    /// these captures also show.
    static var demoNoteDate: Date {
        Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: AppClock.now) ?? AppClock.now
    }

    // MARK: The canonical demo library (2026-09-01)
    //
    // One catalogue of notes a person could plausibly have written, dated three ways: as Home draws
    // it (two today, nine across the previous seven days, so the week shows its real `Show all 9`),
    // as the calendar draws it (four on the selected day, one to three dots on the days around it),
    // and one note at a time at `demoNoteDate` for the editor raws. The same words everywhere, so a
    // Home row, a calendar row and the open note never disagree about what a note says.

    /// The library, newest-first as Home would list it. `key` names a note on the command line;
    /// `title == nil` is a titleless note, which is what a Quick Voice capture produces.
    private static let library: [(key: String, title: String?, body: String)] = [
        ("Weekend Plan", "Weekend Plan", """
        Coffee near the trail Saturday morning, then the market on the way back.

        Sunday stays open unless the weather turns. If it does, the afternoon goes to the book and the next trip.
        """),
        ("voice", nil, """
        I think Saturday should stay pretty simple. Start early, grab coffee near the trail, and hike before it gets too warm.

        After that I want to stop at the market and pick up a few things for dinner.

        Sunday can stay open. If the weather changes, I'll use the afternoon to finish the book and plan the next trip.
        """),
        ("Japan Trip", "Japan Trip", """
        # Before we book

        A few things to settle before we start reserving anything.

        - [ ] Choose travel dates
        - [x] Compare flights
        - [ ] Reserve hotels
        - [ ] Book rail passes

        # Route

        1. Tokyo — 4 nights
        2. Kyoto — 3 nights
        3. Osaka — 2 nights

        # Pack

        - Rain jacket
        - Camera
        - Portable charger
        """),
        ("Launch Checklist", "Launch Checklist", """
        Choose screenshots, update the website, final device pass, then submit.

        - [ ] Capture new Home screenshots
        - [x] Finish Voice device pass
        - [x] Update marketing site
        - [ ] Prepare App Store metadata
        - [ ] Upload final build

        Nothing goes out until the last device pass is clean.
        """),
        ("Monthly Units Query", "Monthly Units Query", """
        Keep this here until the dashboard is finished.

        ```sql
        SELECT
            product_id,
            SUM(units) AS total_units
        FROM orders
        WHERE ordered_at >= '2026-08-01'
        GROUP BY product_id
        HAVING SUM(units) > 100
        ORDER BY total_units DESC;
        ```

        Runs against the August partition.
        """),
        ("Ideas for Sunday", nil, """
        One thing I want to remember before next week is to keep Sunday light. A slow morning, a long walk, and nothing booked after lunch.
        """),
        ("Book Notes", "Book Notes", """
        A few ideas from the chapter that stood out, mostly about attention.

        The argument is that focus is less a matter of discipline than of arrangement. What sits within reach gets used; what takes three steps to find quietly stops existing. So the question is never “how do I concentrate” but “what have I put in front of myself”.

        The second idea follows from the first. A short list written the night before does more than a long one written in the morning, because the morning list is really a negotiation.

        Worth trying for a week before deciding anything.
        """),
        ("Trip Budget", "Trip Budget", """
        A rough estimate before we book anything.

        | Item | Estimate |
        | --- | ---: |
        | Flights | $980 |
        | Hotel | $1,400 |
        | Rental car | $650 |
        | Activities | $340 |

        # Still to price

        - Train tickets
        - Parking
        - Museum passes
        """),
        ("Packing List", "Packing List", """
        Light, and only one bag.

        - [x] Rain jacket
        - [ ] Camera
        - [ ] Portable charger
        - [ ] Small day pack
        - [ ] Walking shoes
        """),
        ("Garden", nil, "Move the basil inside and give the tomatoes another week."),
        ("Trail", nil, "The trail starts shaded, but bring enough water for the ridge."),
    ]

    /// When each library note was written, as **Home** shows the library: two notes today, nine
    /// across the previous seven days. `(days ago, hour, minute)`, against `AppClock.now`.
    private static let libraryHomeDates: [String: (Int, Int, Int)] = [
        "Weekend Plan": (0, 9, 20), "voice": (0, 8, 45),
        "Japan Trip": (1, 19, 10), "Launch Checklist": (1, 14, 30),
        "Monthly Units Query": (2, 16, 5), "Ideas for Sunday": (2, 11, 20),
        "Book Notes": (3, 21, 15), "Trip Budget": (4, 18, 40), "Packing List": (5, 9, 5),
        "Garden": (6, 17, 50), "Trail": (6, 7, 40),
    ]

    /// The same library as the **calendar** shows it: three notes on the selected day, and one, two,
    /// one and four notes on the days before it — one, two and three dots, the grid's whole range
    /// (`CalendarDayDensity`: three dots need four notes).
    private static let libraryCalendarDates: [String: (Int, Int, Int)] = [
        "Weekend Plan": (0, 9, 20), "voice": (0, 8, 45), "Japan Trip": (0, 8, 10),
        "Garden": (1, 18, 15),
        "Monthly Units Query": (2, 16, 5), "Ideas for Sunday": (2, 11, 20),
        "Trip Budget": (2, 9, 30), "Launch Checklist": (2, 8, 15),
        "Book Notes": (4, 21, 15), "Trail": (4, 7, 40),
        "Packing List": (5, 9, 5),
    ]

    @MainActor
    private static func insertLibrary(_ context: ModelContext, dates: [String: (Int, Int, Int)]) {
        let cal = Calendar.current
        for entry in library {
            let (daysAgo, hour, minute) = dates[entry.key] ?? (0, 9, 41)
            let day = cal.date(byAdding: .day, value: -daysAgo, to: AppClock.now)!
            let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
            context.insert(Note(title: entry.title, body: entry.body, createdAt: date, updatedAt: date))
        }
        try? context.save()
    }

    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        if resetStore {
            for note in (try? context.fetch(FetchDescriptor<Note>())) ?? [] { context.delete(note) }
            try? context.save()
            // A retained recording is state exactly like a note is, and a test that left one behind
            // would greet the *next* test with a recovery sheet over Home. Reset means reset.
            UserDefaultsRetainedRecording().forget()
            AVAudioRecorderService.purgeAbandonedRecordings()
        }
        if seedRetainedRecording { DebugVoice.plantRetainedRecording() }
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
                context.insert(Note(title: "Alaska trip idea", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
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
                context.insert(Note(title: "Weekend plan", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        // MARK: The App Store raw library
        //
        // Each of these is one note, pinned to `demoNoteDate` so the editor caption agrees with the
        // 9:41 status bar the capture script sets. Guarded on an empty store for the same reason the
        // seeds above are: a second launch must not double the library.

        if seedShowcaseNotes {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let cal = Calendar.current
                func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
                    let day = cal.date(byAdding: .day, value: -daysAgo, to: AppClock.now)!
                    return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
                }
                // Short first lines on purpose: a Home row shows three lines of preview, and three
                // full ones per note is four notes on a screen. The library has to look *used*.
                let samples: [(String, String, Date)] = [
                    ("Japan Trip",
                     "Tokyo, then Kyoto, then Osaka. Two weeks in April if the flights hold.",
                     at(0, 9, 12)),
                    ("Launch Checklist",
                     """
                     - [x] App Store screenshots
                     - [ ] Update the website
                     - [ ] Final pass on a real phone
                     """,
                     at(0, 8, 40)),
                    ("SQL Questions",
                     "Find the two products with the highest total units sold.",
                     at(0, 7, 55)),
                    ("Book Ideas",
                     "The Creative Act. Someone has recommended it twice this week now.",
                     at(0, 7, 5)),
                    ("Weekend Plans",
                     "Mackinac Island, if the ferry still runs that late in the season.",
                     at(1, 21, 40)),
                    ("Alaska Trip",
                     "Anchorage, Seward, Denali. Nothing booked yet except the cruise.",
                     at(1, 18, 20)),
                    ("Recipes to try",
                     "The lemon pasta from Sunday. Mostly butter, apparently.",
                     at(1, 16, 5)),
                ]
                for (title, body, date) in samples {
                    context.insert(Note(title: title, body: body, createdAt: date, updatedAt: date))
                }
                try? context.save()
            }
            return
        }

        if seedAlaskaDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                # Before we book

                Two weeks in June. Shuttle times: https://www.nps.gov/dena

                ## Look into

                - Check flight options
                - Compare Anchorage hotels
                - Look at rental car prices

                ## The route

                1. Anchorage
                2. Seward
                3. Denali
                4. Fairbanks

                ## Still to do

                - [x] Choose travel dates
                - [x] Check flights
                - [ ] Reserve hotel
                - [ ] Book rental car
                """
                context.insert(Note(title: "Alaska Trip", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedSQLDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                Find the two products with the highest total units sold.

                ```sql
                SELECT product_id,
                       SUM(unit) AS total_units
                FROM Orders
                GROUP BY product_id
                ORDER BY total_units DESC
                LIMIT 2;
                ```

                This groups every order by product before ranking the totals.
                """
                context.insert(Note(title: "SQL Questions", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedJapanDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                A rough plan before we start booking.

                | City | Nights | Plan |
                | --- | --- | --- |
                | Tokyo | 4 | Food + neighbourhoods |
                | Kyoto | 3 | Temples + Arashiyama |
                | Osaka | 2 | Food + a day trip |

                Two weeks total, so there is a spare day somewhere in there.

                Rail passes: https://www.japan-guide.com/e/e2361.html
                """
                context.insert(Note(title: "Japan Trip", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedArchitectureDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                // A line array, not a multi-line literal: the leading spaces are the content.
                let diagram = [
                    "iPhone",
                    "  │",
                    "  ├── SwiftData",
                    "  │",
                    "  └── Voice Capture",
                    "        │",
                    "        ▼",
                    "     Relay API",
                    "        │",
                    "        ▼",
                    "   Transcription",
                ].joined(separator: "\n")
                let body = ([
                    "Current serving path:",
                    "",
                    CodeBlock.preformattedSource(text: diagram),
                    "",
                    "The key only ever lives on the relay, so the phone talks to one endpoint and nothing else.",
                ]).joined(separator: "\n")
                context.insert(Note(title: "App Architecture", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedWeekendThoughtsDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                Tomorrow morning I need to finish a few things before we leave.

                Temple ki vellali, then groceries teesukovali before lunch.

                Después de eso, I want to spend some time planning the trip.

                Maybe we can keep Saturday completely open and decide that morning.
                """
                context.insert(Note(title: "Weekend thoughts", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedSundayDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                Nothing planned, which is more or less the point. If it stays dry we could walk the long way around the lake and stop somewhere for lunch on the way back.

                There is a market near the bridge on Sunday mornings. Worth getting there early — the good bread is gone by ten.

                Otherwise: finish the book, cook something that takes a while, and leave the whole afternoon open.
                """
                context.insert(Note(title: "Ideas for Sunday", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedLibraryHome || seedLibraryCalendar {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                insertLibrary(context, dates: seedLibraryHome ? libraryHomeDates : libraryCalendarDates)
            }
            return
        }

        if let key = seedLibraryNote {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0, let entry = library.first(where: { $0.key == key }) {
                context.insert(Note(title: entry.title, body: entry.body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedMarketingHome {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let cal = Calendar.current
                func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
                    let day = cal.date(byAdding: .day, value: -daysAgo, to: AppClock.now)!
                    return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
                }
                let samples: [(String?, String, Date)] = [
                    ("Weekend plans",
                     "Pick up the rental car Friday afternoon, then leave before dinner.",
                     at(0, 10, 30)),
                    (nil,
                     "Tokyo → Kyoto → Osaka. Still deciding whether to add a day in Nara.",
                     at(0, 9, 15)),
                    ("Launch Checklist",
                     "Finish screenshots, update the website, and do one final device pass.",
                     at(1, 18, 40)),
                    ("SQL Questions",
                     "Find the two products with the highest total units sold this month.",
                     at(1, 14, 10)),
                    (nil,
                     "A few ideas I want to remember from the book before I return it.",
                     at(2, 20, 5)),
                    ("Packing List",
                     "Rain jacket, camera, portable charger, and the small day pack.",
                     at(2, 8, 45)),
                    ("Recipe Ideas",
                     "Lemon pasta, crispy potatoes, and the tomato soup from Sunday.",
                     at(3, 19, 20)),
                    (nil,
                     "I was thinking we could leave early Saturday and stop at the market on the way back.",
                     at(3, 11, 30)),
                    ("Books to find",
                     "The Creative Act, North Woods, and the essay collection Mira mentioned.",
                     at(4, 16, 10)),
                    (nil,
                     "Call the shop before lunch and ask whether the print is ready to collect.",
                     at(5, 12, 25)),
                    ("Dinner Friday",
                     "Book the table by the window if the earlier time is still open.",
                     at(5, 9, 5)),
                    (nil,
                     "The trail starts shaded, but bring enough water for the ridge.",
                     at(6, 17, 50)),
                    ("Garden notes",
                     "Move the basil inside and give the tomatoes another week.",
                     at(7, 7, 40)),
                ]
                for (title, body, date) in samples {
                    context.insert(Note(title: title, body: body, createdAt: date, updatedAt: date))
                }
                try? context.save()
            }
            return
        }

        if seedMarketingVoiceNote {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                Okay, here's what I want to do this weekend. Saturday morning, get coffee near the trail and hike before it gets too hot. Then stop at the market on the way back.

                Sunday can stay open. If the weather turns, I'll use that time to finish the book and plan the next trip.

                I also want to make a short list tonight so I don't forget anything.
                """
                context.insert(Note(body: body, createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedMarketingJapan {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                # Before we book

                A few things to settle before we start reserving anything.

                - [x] Choose travel dates
                - [x] Compare flights
                - [ ] Reserve hotels
                - [ ] Book rail passes

                # Route

                1. Tokyo — 4 nights
                2. Kyoto — 3 nights
                3. Osaka — 2 nights

                # Pack

                - Rain jacket
                - Camera
                - Portable charger
                """
                context.insert(Note(title: "Japan Trip", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedMarketingBudget {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                | Item | Estimate |
                | --- | ---: |
                | Hotel | $1,400 |
                | Rental car | $650 |
                | Boat tour | $229 |
                | Flights | $980 |

                # Still to price

                - Ferry
                - Parking
                - Museum passes
                """
                context.insert(Note(title: "Trip budget", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedMarketingSQL {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                Keep this here until the dashboard is finished.

                ```sql
                SELECT product_id,
                       SUM(units) AS total_units
                FROM orders
                WHERE ordered_at >= '2026-08-01'
                GROUP BY product_id
                HAVING SUM(units) > 100
                ORDER BY total_units DESC;
                ```

                Runs against the August partition.
                """
                context.insert(Note(title: "Monthly units query", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedMarketingCalendar {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let cal = Calendar.current
                func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
                    let day = cal.date(byAdding: .day, value: -daysAgo, to: AppClock.now)!
                    return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
                }
                let samples: [(String?, String, Date)] = [
                    ("Weekend plans", "Pick up the rental car before dinner, then pack tonight.", at(0, 12, 20)),
                    ("Japan Trip", "Tokyo → Kyoto → Osaka. Still deciding whether to add Nara.", at(0, 11, 10)),
                    (nil, "I was thinking we could leave early Saturday and stop at the market on the way back.", at(0, 10, 5)),
                    ("Launch Checklist", "Screenshots, website, final device pass, then submit.", at(0, 9, 0)),
                    (nil, "Move the basil inside before the temperature drops tonight.", at(1, 18, 15)),
                    ("Book Notes", "Three ideas about making time for work that matters.", at(2, 16, 40)),
                    (nil, "The last train leaves earlier than I remembered.", at(2, 13, 20)),
                    ("Packing List", "Rain jacket, camera, and portable charger.", at(2, 8, 10)),
                    (nil, "Save the museum map before we leave the hotel.", at(2, 7, 35)),
                    ("Recipe Ideas", "Lemon pasta and crispy potatoes.", at(4, 15, 30)),
                    (nil, "Ask whether the print is ready to collect.", at(4, 10, 0)),
                    ("Trail notes", "Start early; the ridge has no shade.", at(5, 9, 45)),
                ]
                for (title, body, date) in samples {
                    context.insert(Note(title: title, body: body, createdAt: date, updatedAt: date))
                }
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
                context.insert(Note(title: "Weekend in Seattle", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedQueryDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                The one Priya sent over. Keep it here until the dashboard exists.

                ```sql
                SELECT product_id,
                       SUM(units) AS total_units
                FROM orders
                WHERE ordered_at >= '2026-08-01'
                GROUP BY product_id
                HAVING SUM(units) > 100
                ORDER BY total_units DESC;
                ```

                Runs in about two seconds against the August partition.
                """
                context.insert(Note(title: "Monthly units query", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
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
                context.insert(Note(title: "Trip budget", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
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
                context.insert(Note(title: "Alaska planning", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
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
                context.insert(Note(title: "Alaska itinerary", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedDiagramDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                // Line arrays, not a multi-line literal: the leading spaces are the content.
                let pipeline = [
                    "DOL / USCIS",
                    "     │",
                    "     ▼",
                    "Airflow detects new release",
                    "     │",
                    "     ▼",
                    "Download",
                    "     │",
                    "     ▼",
                    "ADLS raw",
                    "     │",
                    "     ▼",
                    "Bronze Delta",
                    "     │",
                    "     ▼",
                    "PySpark",
                    "     │",
                    "     ▼",
                    "Silver",
                    "     │",
                    "     ├── employers",
                    "     ├── roles",
                    "     ├── wages",
                    "     ├── geography",
                    "     └── USCIS activity",
                    "     │",
                    "     ▼",
                    "dbt",
                    "     │",
                    "     ▼",
                    "Gold marts",
                    "     │",
                    "     ▼",
                    "Data quality checks",
                    "     │",
                    "     ▼",
                    "Publish",
                    "     │",
                    "     ▼",
                    "PostgreSQL",
                    "     │",
                    "     ▼",
                    "Website now uses new data",
                ].joined(separator: "\n")
                let flow = [
                    "                    USER FINDS JOB",
                    "                           │",
                    "                           ▼",
                    "                     CHECK A JOB",
                    "                           │",
                    "                           ▼",
                    "              Paste details / description",
                    "                           │",
                    "                           ▼",
                    "                   Posting parser",
                    "                           │",
                    "                           ▼",
                    "                    Confirm details",
                    "                           │",
                    "                           ▼",
                    "                  Employer resolver",
                    "                           │",
                    "                    Role resolver",
                    "                           │",
                    "                 Location resolver",
                    "                           │",
                    "                           ▼",
                    "                Historical evidence",
                    "                           │",
                    "        ┌──────────────────┼──────────────────┐",
                    "        ▼                  ▼                  ▼",
                    "     Company              Role             Location",
                    "      history            match              match",
                    "        │                  │                  │",
                    "        └──────────────────┼──────────────────┘",
                    "                           ▼",
                    "                         Recency",
                    "                           │",
                    "                           ▼",
                    "                    Decision engine",
                    "                           │",
                    "          ┌────────────────┴───────────────┐",
                    "          ▼                                ▼",
                    " Current posting evidence        Historical evidence",
                    "          │                                │",
                    "          └────────────────┬───────────────┘",
                    "                           ▼",
                    "                       RESULT",
                    "                           │",
                    "                           ▼",
                    "                Worth investigating?",
                    "                           │",
                    "              ┌────────────┼────────────┐",
                    "              ▼            ▼            ▼",
                    "          Company      Evidence      Similar",
                    "          profile      filings       sponsors",
                ].joined(separator: "\n")
                let tree = [
                    "sponsor-intelligence/",
                    "│",
                    "├── apps/",
                    "│   ├── web/",
                    "│   │   └── Next.js",
                    "│   │",
                    "│   └── api/",
                    "│       └── FastAPI",
                    "│",
                    "├── data/",
                    "│   ├── ingestion/",
                    "│   │   ├── dol/",
                    "│   │   └── uscis/",
                    "│   │",
                    "│   ├── spark/",
                    "│   │   ├── bronze/",
                    "│   │   ├── silver/",
                    "│   │   └── enrichment/",
                    "│   │",
                    "│   └── dbt/",
                    "│       ├── staging/",
                    "│       ├── intermediate/",
                    "│       └── marts/",
                    "│",
                    "├── services/",
                    "│   ├── employer_resolution/",
                    "│   ├── role_resolution/",
                    "│   ├── location_resolution/",
                    "│   ├── job_parser/",
                    "│   └── scoring/",
                    "│",
                    "├── airflow/",
                    "├── terraform/",
                    "├── tests/",
                    "├── docs/",
                    "└── .github/",
                ].joined(separator: "\n")
                let picked: [String]
                switch diagramChoice {
                case "pipeline":
                    picked = ["The ingestion pipeline, end to end.", "",
                              CodeBlock.preformattedSource(text: pipeline)]
                case "flow":
                    picked = ["How a check actually resolves.", "",
                              CodeBlock.preformattedSource(text: flow)]
                case "junction":
                    let junction = [
                        "                Historical evidence",
                        "                           │",
                        "        ┌──────────────────┼──────────────────┐",
                        "        ▼                  ▼                  ▼",
                        "     Company              Role             Location",
                        "      history            match              match",
                        "        │                  │                  │",
                        "        └──────────────────┼──────────────────┘",
                        "                           ▼",
                        "                         Recency",
                    ].joined(separator: "\n")
                    picked = ["The three-way branch.", "",
                              CodeBlock.preformattedSource(text: junction)]
                case "tree":
                    picked = ["And the repo it all lives in.", "",
                              CodeBlock.preformattedSource(text: tree)]
                default:
                    picked = ["The ingestion pipeline, end to end.", "",
                              CodeBlock.preformattedSource(text: pipeline), "",
                              "How a check actually resolves.", "",
                              CodeBlock.preformattedSource(text: flow), "",
                              "And the repo it all lives in.", "",
                              CodeBlock.preformattedSource(text: tree)]
                }
                let body = (picked + ["",
                    "A closing paragraph, so a tap down here is a tap on prose.",
                ]).joined(separator: "\n")
                context.insert(Note(title: "Sponsor intelligence", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedCodeDemo {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            if existing == 0 {
                let body = """
                Notes on the parser.

                ```python
                def hello(name):
                    print(name)
                ```

                Between the two blocks.

                | Stage | Cost |
                | --- | --- |
                | Parse | fast |
                | Render | slower |

                One more paragraph, well below both blocks, so a tap here is a tap on prose.

                And another, so the page scrolls.
                """
                context.insert(Note(title: "Parser notes", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
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
                context.insert(Note(title: "Yellowstone notes", body: body,
                                    createdAt: demoNoteDate, updatedAt: demoNoteDate))
                try? context.save()
            }
            return
        }

        if seedCappedToday {
            let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
            guard existing == 0 else { return }
            let cal = Calendar.current
            for i in 0..<7 {
                let date = cal.date(bySettingHour: 9 + i, minute: 0, second: 0, of: AppClock.now)!
                context.insert(Note(title: "Capped note \(i + 1)",
                                    body: "Body for capped note \(i + 1).",
                                    createdAt: date, updatedAt: date))
            }
            try? context.save()
            return
        }

        guard seedSampleNotes || seedOlderNotesOnly else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
        guard existing == 0 else { return }

        let cal = Calendar.current
        // Shifted a week back when only older notes are wanted, so no sample lands on today.
        let shift = seedOlderNotesOnly ? 7 : 0
        func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = cal.date(byAdding: .day, value: -(daysAgo + shift), to: AppClock.now)!
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

// MARK: - Voice stand-ins

/// A capture that behaves like the real one everywhere except the two places a UI test cannot go: the
/// microphone and the network.
///
/// It exists so the durability surface — *"Your recording is still on this iPhone."*, **Retry**,
/// **Delete Recording** — can be driven by real taps. Everything under it is the shipping code: the
/// same `VoiceCaptureModel`, the same phases, the same retention rule, the same copy. Only the two
/// injected seams `docs/10-voice-v2.md` §4 already requires are swapped, and only in DEBUG.
@MainActor
enum DebugVoice {
    static var isEnabled: Bool {
        DebugLaunch.voiceFakeFailure || DebugLaunch.voiceFakeRetrySucceeds
            || DebugLaunch.voiceFakeSuccess || DebugLaunch.voiceFakeSlow
            || DebugLaunch.voiceDemoLevels
    }

    static func recorder() -> AudioRecording? { isEnabled ? DebugRecorder() : nil }

    static func service() -> TranscriptionService? {
        guard isEnabled else { return nil }
        return DebugTranscription(succeedsOnRetry: DebugLaunch.voiceFakeRetrySucceeds,
                                  alwaysSucceeds: DebugLaunch.voiceFakeSuccess,
                                  delay: DebugLaunch.voiceFakeSlow ? .seconds(8) : .milliseconds(300))
    }

    /// Writes one temporary recording and remembers it, as if a capture had failed shortly before the
    /// app was last closed. Nothing about the recovery path is stubbed — the file and the memory of it
    /// are the real ones.
    static func plantRetainedRecording(origin: RetainedVoiceRecording.Origin = .quickVoice) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AVAudioRecorderService.tempPrefix)\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        try? Data("debug audio".utf8).write(to: url)
        UserDefaultsRetainedRecording().remember(
            RetainedVoiceRecording(url: url, retainedAt: .now, origin: origin)
        )
    }

    /// A whole capture, or `nil` when no stand-in was asked for.
    static func captureModel(onTranscript: @escaping (String) -> Void) -> VoiceCaptureModel? {
        guard let recorder = recorder(), let service = service() else { return nil }
        return VoiceCaptureModel(recorder: recorder, service: service, onTranscript: onTranscript)
    }

    /// Writes a real temporary file with the real prefix, so deletion is a real deletion.
    @MainActor
    private final class DebugRecorder: AudioRecording {
        private var url: URL?
        private var startedAt: Date?
        var onCaptureEnded: ((RecordingStop) -> Void)?

        /// The stand-in is open for exactly as long as it holds a file.
        var isCapturing: Bool { url != nil }

        /// A flat 0.4 by default — a test asserts on phases, not on pixels.
        ///
        /// Under `-voiceDemoLevels` it moves instead, because a simulator has no audio input and the
        /// real recorder therefore reports the floor: `WaveformView` draws a straight dashed line,
        /// and a screenshot of a recorder that is hearing nothing is a screenshot of a broken
        /// recorder. The shape is a syllable ripple inside a phrase swell, every period shorter than
        /// the waveform's own 3.2s window — a slower one fills the whole strip with a single slope
        /// and reads as a ramp rather than as a voice. It is the *microphone* that is standing in here;
        /// everything the waveform does with the number is the shipping view.
        var level: Float {
            guard DebugLaunch.voiceDemoLevels, let startedAt else { return 0.4 }
            let t = Date.now.timeIntervalSince(startedAt)
            let syllable = sin(t * 8.1) * 0.5 + 0.5
            let overtone = sin(t * 3.3 + 1.9) * 0.5 + 0.5
            let phrase = sin(t * 2.6 + 0.7) * 0.5 + 0.5
            let breath = sin(t * 0.9 + 2.1) * 0.5 + 0.5
            let value = 0.10 + 0.5 * syllable * (0.3 + 0.7 * phrase) + 0.22 * overtone * breath
            return Float(min(1, max(0.05, value)))
        }

        func requestPermission() async -> Bool { true }

        func start() throws -> URL {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(AVAudioRecorderService.tempPrefix)\(UUID().uuidString)")
                .appendingPathExtension("m4a")
            try? Data("debug audio".utf8).write(to: url)
            self.url = url
            startedAt = .now
            return url
        }

        func pause() {}
        func resume() {}
        /// Measured like the real one, so a debug capture exercises the same `.finishing` gate: the
        /// stand-in bytes are not a real container, so they measure as one second of nothing rather
        /// than as unmeasurable, which would send every debug capture down the no-speech path.
        func finish() async -> FinishedRecording? {
            guard let url else { return nil }
            let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int
            return FinishedRecording(url: url, assetSeconds: 1, bytes: bytes)
        }
        func cancel() { if let url { cleanup(url) } }
        func cleanup(_ url: URL) {
            try? FileManager.default.removeItem(at: url)
            if self.url == url { self.url = nil }
        }
    }

    /// Fails the first attempt the way a dropped connection does, which is the failure the retained
    /// recording exists for. Whether the second attempt succeeds is the launch argument's choice.
    private struct DebugTranscription: TranscriptionService {
        let succeedsOnRetry: Bool
        var alwaysSucceeds = false
        var delay: Duration = .milliseconds(300)
        /// Local, so the one-time disclosure does not stand between a UI test and the failure state.
        var sendsAudioOffDevice: Bool { false }

        static let text = "This is what the recording said."
        private static let attempts = Counter()

        func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
            try? await Task.sleep(for: delay)
            let attempt = Self.attempts.next()
            guard alwaysSucceeds || (succeedsOnRetry && attempt > 1) else {
                throw TranscriptionError.offline
            }
            return TranscriptionResult(text: Self.text, detectedLanguages: ["en"])
        }
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func next() -> Int { lock.withLock { value += 1; return value } }
    }
}

#endif
