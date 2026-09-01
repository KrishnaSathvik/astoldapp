import XCTest

/// Verifies the tap-driven navigation that screenshots can't: compose → editor → back → Home,
/// Calendar / Profile / Theme push and pop. Each interaction waits for its target to be hittable
/// first, so the flow is resilient to launch/animation timing.
final class NavigationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore", "-seedSampleNotes"]
        app.launch()
        // Home is ready when the New note button exists.
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    @discardableResult
    private func tap(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("missing element: \(message)")
            return false
        }
        element.tap()
        return true
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testComposeThenBackReturnsHome() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        tap(app.buttons["Back to notes"], "editor back button")
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 8), "Should return to Home")
        XCTAssertFalse(app.buttons["Back to notes"].exists, "Editor should be gone")
    }

    /// The Back button on a *brand-new* note is the chevron alone.
    ///
    /// Asserted on the rendered navigation bar, not on `EditorOrigin`: the enum's own unit tests pass
    /// happily while the button says "Notes", because what reaches the button is a separate question
    /// from what the enum returns. This test is the one that fails when the origin goes stale on its
    /// way through `navigationDestination`.
    func testANewNotesBackButtonIsTheChevronAlone() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8), "editor should open")
        let back = app.navigationBars.element(boundBy: 0).buttons.element(boundBy: 0)
        XCTAssertEqual(back.staticTexts.count, 0,
                       "A new note's Back button must carry no word beside the chevron")
    }

    /// The same for an *existing* note (changed 2026-08-26 — this previously asserted "Notes").
    /// The word is gone from every origin, so the one thing left to check is that no origin
    /// reintroduces it.
    func testAnExistingNotesBackButtonIsAlsoTheChevronAlone() {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8), "seeded note should exist")
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8), "editor should open")
        let back = app.navigationBars.element(boundBy: 0).buttons.element(boundBy: 0)
        XCTAssertEqual(back.staticTexts.count, 0,
                       "An existing note's Back button must carry no word either")
        XCTAssertEqual(back.label, "Back to notes",
                       "the spoken destination is all that survives the word being dropped")
    }

    /// A new note is a capture intent: the editor opens with the keyboard already up.
    func testNewNoteOpensWithTheKeyboard() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8),
                      "A new note should open ready to type")
    }

    /// An existing note is a reading intent: nothing takes first responder, so no keyboard.
    func testExistingNoteOpensForReadingWithoutTheKeyboard() {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8), "seeded note should exist")
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8), "Editor should open")
        XCTAssertFalse(app.keyboards.element.waitForExistence(timeout: 3),
                       "Opening an existing note must not raise the keyboard")
        // Autosave is the only save and the editor carries no completion control at all (RULES.md §4).
        XCTAssertFalse(app.buttons["Dismiss keyboard"].exists, "the editor must not offer Done")
        XCTAssertFalse(app.buttons["More actions"].exists, "the editor must not offer an overflow menu")
    }

    /// Tapping the body starts editing. There is no Done: the keyboard leaves by scrolling the body
    /// or by navigating Back, and autosave means neither is a save (RULES.md §4).
    func testTappingBodyStartsEditingAndOffersNoDoneButton() {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8))
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8))

        app.textViews.firstMatch.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8),
                      "Tapping the body should start editing")

        XCTAssertFalse(app.buttons["Dismiss keyboard"].exists,
                       "the editor must not offer a Done button while writing")
        // Back is the exit, and it saves. Nothing has to be pressed first.
        XCTAssertTrue(app.buttons["Back to notes"].exists)
    }

    func testSwipeToDeleteRemovesNote() {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8), "seeded note should exist")
        note.swipeLeft()
        tap(app.buttons["Delete"], "revealed Delete button")
        XCTAssertTrue(note.waitForNonExistence(timeout: 8), "note should be removed after delete")
    }

    func testCalendarPagePushesAndPops() {
        let app = launchedApp()
        tap(app.buttons["Open calendar"], "calendar button")
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 8), "Calendar should push")
        back(app)
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 8), "Should return to Home")
    }

    func testProfilePagePushesAndPops() {
        let app = launchedApp()
        tap(app.buttons["Profile"], "profile button")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8), "Profile should push")
        back(app)
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 8), "Should return to Home")
    }

    func testProfileAboutAndPrivacyPushAndPop() {
        let app = launchedApp()
        tap(app.buttons["Profile"], "profile button")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))

        tap(app.buttons["What is As Told"], "What is As Told row")
        XCTAssertTrue(app.navigationBars["What is As Told"].waitForExistence(timeout: 8), "About should push")
        back(app)
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8), "Back to Profile")

        tap(app.buttons["Privacy"], "Privacy row")
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8), "Privacy should push")

        // App Review 5.1.1(i) wants the policy reachable from inside the app, and the permanent
        // voice explanation has to be findable without waiting for the one-time disclosure.
        XCTAssertTrue(app.buttons["Privacy Policy"].waitForExistence(timeout: 8),
                      "Privacy should link out to the hosted policy")

        tap(app.buttons["Voice Transcription"], "Voice Transcription row")
        XCTAssertTrue(app.navigationBars["Voice Transcription"].waitForExistence(timeout: 8),
                      "Voice Transcription detail should push")
        back(app)
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8), "Back to Privacy")
    }

    /// Apple's automated audit, scoped to the types we enforce: hit-region size + sufficient element
    /// descriptions. (Contrast/Dynamic-Type are logged separately — the muted "Quiet Editorial"
    /// palette is a reviewed design choice; see docs/03-design-system.md §14.)
    private static let enforcedAudits: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription]

    @MainActor func testHomeAccessibilityAudit() throws {
        let app = launchedApp()
        try app.performAccessibilityAudit(for: Self.enforcedAudits)
    }

    @MainActor func testProfileAccessibilityAudit() throws {
        let app = launchedApp()
        tap(app.buttons["Profile"], "profile button")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))
        try app.performAccessibilityAudit(for: Self.enforcedAudits)
    }

    /// The editor in its reading state — the screen a user spends the most time looking at.
    @MainActor func testEditorAccessibilityAudit() throws {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8))
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8))
        try app.performAccessibilityAudit(for: Self.enforcedAudits)
    }

    func testThemePickerOpensAndSelectsDark() {
        let app = launchedApp()
        tap(app.buttons["Profile"], "profile button")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))

        tap(app.staticTexts["Theme"], "Theme row")
        XCTAssertTrue(app.navigationBars["Theme"].waitForExistence(timeout: 8), "Theme screen should push")

        tap(app.staticTexts["Dark"], "Dark option")
        back(app)
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8), "Back to Profile")
    }
}

/// What the editor does *not* show. The screen is Back, Style, and the note — no Done, no overflow,
/// no delete. Each of those was removed for a reason, and each would look like a harmless addition
/// to someone who did not know the reason, so their absence is asserted rather than assumed.
final class EditorChromeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore", "-seedSampleNotes"]
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    private func openSeededNote(_ app: XCUIApplication) {
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8), "seeded note should exist")
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8), "editor should open")
    }

    /// The editor carries no overflow menu. Deleting a note is done on the timeline, by swiping it —
    /// one place, one gesture. An overflow in here is how Export / Duplicate arrive (RULES.md §7), so
    /// its absence is the fence.
    ///
    /// **Share moved from forbidden to required** (2026-08-26). This test listed `Share` among the
    /// things that must not exist, which was true right up until §7 admitted per-note sharing and §4
    /// made Share part of the header: "Back, **the note's date**, **Share**, Style menu". The rule
    /// moved and the fence did not, so it was failing against correct code. Note what did *not* change:
    /// Share is one button, never the first item of an `…` menu, and everything the overflow would have
    /// carried is still forbidden below.
    func testTheEditorHasNoOverflowMenu() {
        let app = launchedApp()
        openSeededNote(app)

        XCTAssertTrue(app.buttons["Share"].exists,
                      "Share is a required header element (RULES.md §4)")
        XCTAssertFalse(app.buttons["More actions"].exists, "the editor must not offer an overflow menu")
        XCTAssertFalse(app.buttons["Delete Note"].exists, "delete belongs to the timeline, not the editor")
        for forbidden in ["Export", "Duplicate", "Word Count", "Pin"] {
            XCTAssertFalse(app.buttons[forbidden].exists, "\(forbidden) must not be in the editor")
        }
    }

    /// The only chrome the editor shows while writing: Back and Style. Everything else was either a
    /// save control the app does not need or an action that belongs somewhere else.
    func testEditorChromeIsBackAndStyleOnly() {
        let app = launchedApp()
        openSeededNote(app)
        app.textViews.firstMatch.tap()
        XCTAssertTrue(app.buttons["Style"].waitForExistence(timeout: 8), "Style should be available")

        XCTAssertFalse(app.buttons["Dismiss keyboard"].exists)
        XCTAssertFalse(app.buttons["More actions"].exists)
        XCTAssertTrue(app.buttons["Back to notes"].exists)
    }
}

/// The calendar reaches a day's notes in place: tap a day, its notes appear under the grid, tap one
/// to open it — and Back comes home to the calendar, not to Home.
final class CalendarDayNotesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore", "-seedSampleNotes"]
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    private func openCalendar(_ app: XCUIApplication) {
        app.buttons["Open calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 8), "Calendar should push")
    }

    private static func dayIdentifier(daysAgo: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: -daysAgo, to: .now)!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "day-%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func note(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    /// The core of the change: a day's notes are listed on the calendar, not on another screen.
    func testTappingADayListsThatDaysNotesOnTheCalendar() {
        let app = launchedApp()
        openCalendar(app)

        // Two days ago the seed has "Work ideas"; yesterday it has "Random thoughts at night".
        app.buttons[Self.dayIdentifier(daysAgo: 2)].tap()
        XCTAssertTrue(note(app, "Work ideas").waitForExistence(timeout: 8),
                      "that day's note should be listed under the grid")
        XCTAssertFalse(note(app, "Random thoughts at night").exists,
                       "another day's note must not be listed")
        XCTAssertTrue(app.navigationBars["Calendar"].exists, "still on the calendar — no navigation")

        app.buttons[Self.dayIdentifier(daysAgo: 1)].tap()
        XCTAssertTrue(note(app, "Random thoughts at night").waitForExistence(timeout: 8),
                      "selecting another day swaps the list")
        XCTAssertFalse(note(app, "Work ideas").exists)
    }

    /// Opening a note from the calendar and coming back must land on the calendar, with the same
    /// day still selected — never on Home.
    func testOpeningANoteFromTheCalendarReturnsToTheCalendar() {
        let app = launchedApp()
        openCalendar(app)

        app.buttons[Self.dayIdentifier(daysAgo: 2)].tap()
        let row = note(app, "Work ideas")
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()

        // Back must *announce* Calendar, not Notes. It always went to the calendar — it just named a
        // screen the tap does not lead to, which is a back button breaking its one promise (fixed
        // 2026-08-25). Since 2026-08-26 the naming is spoken only: the button draws a bare chevron
        // from here too, so this label is the entire difference the origin still makes.
        let back = app.buttons["Back to calendar"]
        XCTAssertTrue(back.waitForExistence(timeout: 8), "editor should open with a Back to calendar")
        XCTAssertFalse(app.buttons["Back to notes"].exists,
                       "a note opened from the calendar must not offer Back to notes")
        XCTAssertEqual(back.staticTexts.count, 0,
                       "the calendar's Back button carries no word either")
        back.tap()

        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 8),
                      "Back should return to the calendar, not Home")
        XCTAssertTrue(note(app, "Work ideas").waitForExistence(timeout: 8),
                      "the same day should still be selected")
        XCTAssertFalse(app.buttons["New note"].exists, "should not have fallen through to Home")
    }

    /// A day with nothing on it says so, in place.
    func testADayWithNoNotesSaysSoInPlace() {
        let app = launchedApp()
        openCalendar(app)

        app.buttons[Self.dayIdentifier(daysAgo: 4)].tap()   // the seed stops at 2 days ago
        XCTAssertTrue(app.staticTexts["Nothing written on this day."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["Calendar"].exists, "still on the calendar")
    }

    /// A note opened from the calendar offers no delete either — the calendar is a way to reach a
    /// date, not a second place to manage notes (RULES.md §1). Back returns to the calendar.
    func testANoteOpenedFromTheCalendarOffersNoDeleteAndReturnsThere() {
        let app = launchedApp()
        openCalendar(app)

        app.buttons[Self.dayIdentifier(daysAgo: 2)].tap()
        let row = note(app, "Work ideas")
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()

        XCTAssertTrue(app.buttons["Back to calendar"].waitForExistence(timeout: 8),
                      "the note should open, offering Back to calendar")
        XCTAssertFalse(app.buttons["More actions"].exists, "no overflow in the editor")
        XCTAssertFalse(app.buttons["Delete Note"].exists, "no delete in the editor")

        app.buttons["Back to calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 8),
                      "Back should return to the calendar")
        XCTAssertTrue(note(app, "Work ideas").waitForExistence(timeout: 8),
                      "the note is still there — nothing deleted it")
    }
}

/// Home's identity, as it reads after the 2026-08-30 library redesign and the 2026-08-31 refinements.
///
/// These originally locked down a defect where `Today` was printed by the day grouping rather than
/// by Home itself, so a day with nothing written on it opened on `Yesterday`. That defect is now
/// structurally impossible: `Today` is a *bucket* and `Yesterday` is not a heading at all.
///
/// What leads Home is the quiet current date over the first period heading. An `As Told` title over
/// a note count briefly replaced it and was removed the same day: the app's name was on the icon the
/// reader just tapped, and the size of the library is a statistic Home does not report (RULES.md §4).
final class TimelineHeaderUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp(seed: String? = "-seedSampleNotes") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore"]
        if let seed { app.launchArguments.append(seed) }
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    private static func todayLabel() -> String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        return df.string(from: .now).uppercased()
    }

    func testHomeLeadsWithTheDateOverTheFirstPeriodHeading() {
        let app = launchedApp()
        XCTAssertTrue(app.staticTexts[Self.todayLabel()].waitForExistence(timeout: 8),
                      "the current date should lead Home")
        XCTAssertTrue(app.staticTexts["Today"].exists, "today's notes sit under a Today heading")
        XCTAssertTrue(app.staticTexts["Previous 7 Days"].exists,
                      "the sample seed spans several days, so the next period should be drawn")
    }

    /// The date orients once. Repeating it over every group would be the screen telling the time
    /// again for notes the reader has already placed.
    func testTheDateAppearsOnceAndOnlyOnTheFirstHeading() {
        let app = launchedApp()
        XCTAssertTrue(app.staticTexts["Previous 7 Days"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts.matching(identifier: Self.todayLabel()).count, 1,
                       "the date belongs to the first heading, not to every one")
    }

    /// Home carries no name and no count of its own (removed 2026-08-31).
    func testHomeDoesNotPrintItsOwnNameOrACount() {
        let app = launchedApp()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8), "Home did not group")
        XCTAssertFalse(app.staticTexts["As Told"].exists,
                       "the app's name was on the icon the reader just tapped")
        XCTAssertFalse(app.staticTexts.element(matching: NSPredicate(format: "label MATCHES %@",
                                                                    "^[0-9]+ notes?$")).exists,
                       "the size of the library is a statistic, and Home reports none")
    }

    /// Home stops at the recent periods. Anything older is behind **Browse older notes**, which is
    /// the only route from Home into the complete timeline (RULES.md §1, changed 2026-08-31).
    func testHomeStopsAtTheRecentPeriodsAndOffersTheArchive() {
        let app = launchedApp(seed: "-seedOlderNotesOnly")
        XCTAssertTrue(app.buttons["Browse older notes"].waitForExistence(timeout: 8),
                      "older notes exist, so Home should offer the archive")
        XCTAssertFalse(app.staticTexts["Previous 30 Days"].exists,
                       "Home draws Today and Previous 7 Days and nothing older")
        XCTAssertFalse(app.staticTexts["Older"].exists)
    }

    func testBrowseOlderNotesOpensTheCompleteTimeline() {
        let app = launchedApp(seed: "-seedOlderNotesOnly")
        XCTAssertTrue(app.buttons["Browse older notes"].waitForExistence(timeout: 8))
        app.buttons["Browse older notes"].tap()
        XCTAssertTrue(app.navigationBars["All Notes"].waitForExistence(timeout: 8),
                      "Browse older notes should push the archive, which names itself All Notes")
    }

    /// **The duplication the conditional archive exists to kill** (2026-08-31). Seven notes, all of
    /// them today: `Show all 7` already reaches every note in the library, so an archive affordance
    /// beside it would lead to the same seven notes one screen further away.
    func testNoArchiveAffordanceWhenHomeAlreadyHoldsEveryNote() {
        let app = launchedApp(seed: "-seedCappedToday")
        XCTAssertTrue(app.buttons["Show all 7"].waitForExistence(timeout: 8),
                      "Today is over its cap, so the expander should be offered")
        XCTAssertFalse(app.buttons["Browse older notes"].exists,
                       "nothing is older than Home draws, so there is nothing to browse")
    }

    /// The buckets replaced day headings outright. A per-day heading reappearing means something
    /// reintroduced `groupedByDay` on Home.
    func testHomeDoesNotDrawPerDayHeadings() {
        let app = launchedApp()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8), "Home did not group")
        XCTAssertFalse(app.staticTexts["Yesterday"].exists,
                       "Home groups by period now — Yesterday is not one of them")
    }

    /// With nothing written today there is simply no `Today` group, and the date still leads. The old
    /// failure mode — Home *opening* on `Yesterday` — cannot recur, because no day is ever a heading.
    func testNoTodayGroupWhenNothingWasWrittenToday() {
        let app = launchedApp(seed: "-seedOlderNotesOnly")
        XCTAssertTrue(app.staticTexts[Self.todayLabel()].waitForExistence(timeout: 8),
                      "the date still leads Home")
        XCTAssertFalse(app.staticTexts["Today"].exists,
                       "nothing was written today, so no Today group should be drawn")
    }

    /// The cap, and the way past it. Seven notes today, four drawn, and the affordance names the
    /// whole period rather than being permanent furniture.
    func testACappedPeriodExpandsInPlace() {
        let app = launchedApp(seed: "-seedCappedToday")
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8), "Home did not group")
        XCTAssertTrue(app.staticTexts["Capped note 7"].exists, "the newest is drawn")
        XCTAssertFalse(app.staticTexts["Capped note 3"].exists, "the fifth-newest is capped away")

        let expand = app.buttons["Show all 7"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5), "the cap should offer a way past itself")
        expand.tap()

        XCTAssertTrue(app.staticTexts["Capped note 3"].waitForExistence(timeout: 5),
                      "expanding should reveal the rest of the group in place")
        XCTAssertFalse(app.buttons["Show all 7"].exists,
                       "and the affordance stops offering what is already shown")
    }

    /// **`Show all N` goes both ways** (2026-08-31). One-way expansion left a group open with no way
    /// back short of leaving Home, which made a glance feel like a commitment.
    func testAnExpandedPeriodCanBeCollapsedAgain() {
        let app = launchedApp(seed: "-seedCappedToday")
        XCTAssertTrue(app.buttons["Show all 7"].waitForExistence(timeout: 8))
        app.buttons["Show all 7"].tap()

        let collapse = app.buttons["Show less"]
        XCTAssertTrue(collapse.waitForExistence(timeout: 5),
                      "an expanded group must offer its own way back")
        collapse.tap()

        XCTAssertTrue(app.buttons["Show all 7"].waitForExistence(timeout: 5),
                      "collapsing should restore the cap and the offer to open it again")
        XCTAssertFalse(app.staticTexts["Capped note 3"].exists,
                       "and the capped notes should be back behind the cap")
        XCTAssertTrue(app.staticTexts["Capped note 7"].exists, "the newest four still stand")
    }

    /// Expansion belongs to the visit, not to the list. A period that re-collapsed because the reader
    /// opened one of its notes would make the affordance feel like it had not worked (RULES.md §1).
    func testAnExpandedPeriodSurvivesOpeningANote() {
        let app = launchedApp(seed: "-seedCappedToday")
        XCTAssertTrue(app.buttons["Show all 7"].waitForExistence(timeout: 8))
        app.buttons["Show all 7"].tap()
        XCTAssertTrue(app.staticTexts["Capped note 1"].waitForExistence(timeout: 5),
                      "the oldest of the seven should now be drawn")

        app.staticTexts["Capped note 1"].tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8), "the editor never opened")
        app.buttons["Back to notes"].tap()

        XCTAssertTrue(app.staticTexts["Capped note 1"].waitForExistence(timeout: 8),
                      "Today should still be expanded after coming back from a note")
        XCTAssertTrue(app.buttons["Show less"].exists, "and must not have re-collapsed")
    }

    /// An empty library shows the mark and the tagline — no group, no date line, no creation control
    /// duplicating the header's, and no archive to open.
    func testEmptyHomeShowsTheMarkAndTagline() {
        let app = launchedApp(seed: nil)
        XCTAssertTrue(app.staticTexts["Nothing here yet."].waitForExistence(timeout: 8),
                      "an empty library should name its state")
        XCTAssertTrue(app.staticTexts["Write it. Say it. Keep it."].exists,
                      "the tagline is the second line")
        XCTAssertTrue(app.buttons["New note"].exists, "creation still lives in the header")
        XCTAssertFalse(app.buttons["Browse older notes"].exists,
                       "there is no archive to open when there are no notes")
    }
}
