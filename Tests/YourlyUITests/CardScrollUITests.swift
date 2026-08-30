import XCTest

/// The gesture, driven with real touches — because a scroll rule that has only ever been reasoned
/// about is a rule nobody has checked.
///
/// The defect this closes: a wide preformatted card measured wider than its viewport, refused to wrap,
/// drew a scroll indicator, and could not be moved by a finger, because the card hands every touch
/// through so a tap can still reach the source underneath. Two identical screenshots either side of a
/// real drag were what proved it.
final class CardScrollUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launched(_ diagram: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedDiagramDemo", "-diagram", diagram,
                               "-openSeededNote", "-hasCompletedWelcome", "YES"]
        app.launch()
        return app
    }

    private func card(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["Plain text block"].firstMatch
    }

    private func pixels(_ app: XCUIApplication) -> Data {
        XCUIScreen.main.screenshot().pngRepresentation
    }

    /// Where the drawing itself sits, in screen points.
    ///
    /// The card's accessibility element is the code view, which lives inside the card's scroller and is
    /// sized to the diagram's full width — so scrolling the card moves this, and nothing else on the
    /// page moving can fake it. Comparing whole screenshots was the first version of these assertions
    /// and it was measuring the wrong thing: on a real phone a note that can scroll vertically settles
    /// by a pixel or two after any drag, which failed a test whose actual claim was "the diagram did
    /// not move sideways". Simulators are steadier, so only the device caught it.
    private func drawingOriginX(_ app: XCUIApplication) -> CGFloat {
        card(app).frame.origin.x
    }

    /// Drags in the **app's** coordinate space, not the card element's.
    ///
    /// The card's accessibility element is the code view, which is sized to the diagram's full width —
    /// 465 pt of it on a 402 pt screen. A normalized offset of 0.85 on that element lands *off the
    /// right edge of the device* and touches nothing at all, which is what made the first version of
    /// this test report a working gesture as broken.
    ///
    /// `dy` must also clear the header: a drag beginning on **Copy Text** is a cancelled tap, not a
    /// scroll, and the gesture is supposed to refuse it.
    private func dragAcross(_ app: XCUIApplication, dy: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: dy))
            .press(forDuration: 0.1,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: dy)),
                   withVelocity: 800, thenHoldForDuration: 0.1)
        Thread.sleep(forTimeInterval: 1.0)
    }

    /// The fix itself: a sideways drag over a diagram wider than the page moves it.
    func testAHorizontalDragScrollsAWideDiagram() {
        let app = launched("junction")
        let card = card(app)
        XCTAssertTrue(card.waitForExistence(timeout: 15), "the preformatted card never appeared")

        let before = drawingOriginX(app)
        dragAcross(app, dy: 0.45)
        XCTAssertLessThan(drawingOriginX(app), before - 20,
                          "a horizontal drag over a wide diagram did not move it")
    }

    /// …and a diagram that already fits must not move, or every sideways twitch would fight the page.
    func testAHorizontalDragOverADiagramThatFitsChangesNothing() {
        let app = launched("tree")
        let card = card(app)
        XCTAssertTrue(card.waitForExistence(timeout: 15), "the preformatted card never appeared")

        let before = drawingOriginX(app)
        dragAcross(app, dy: 0.45)
        XCTAssertEqual(drawingOriginX(app), before, accuracy: 0.5,
                       "a diagram narrower than the page moved when it should have stayed put")
    }

    /// A vertical drag over a card must still scroll the **note**, not the diagram.
    ///
    /// This is the half that could have been broken by the fix and would never have shown up in a
    /// screenshot of the diagram: if the card claimed every drag, reading a long note would stop
    /// working wherever a diagram happened to be under the thumb.
    func testAVerticalDragOverACardStillScrollsTheNote() {
        let app = launched("all")           // three diagrams and prose — far longer than a screen
        XCTAssertTrue(card(app).waitForExistence(timeout: 15))

        let before = pixels(app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            .press(forDuration: 0.1,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)),
                   withVelocity: 800, thenHoldForDuration: 0.1)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertNotEqual(before, pixels(app),
                          "a vertical drag over a card did not scroll the note")
    }

    /// Copy Text still works — a card's one directly interactive element.
    func testCopyTextStillCopies() {
        let app = launched("junction")
        XCTAssertTrue(card(app).waitForExistence(timeout: 15))
        let copy = app.buttons["Copy Text"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "Copy Text is missing from the card")
        copy.tap()
        XCTAssertTrue(app.buttons["Copied"].waitForExistence(timeout: 5),
                      "Copy Text did not confirm")
    }
}
