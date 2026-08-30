import XCTest
import UIKit
import UniformTypeIdentifiers

/// The two editor defects a phone found, driven with real touches.
///
/// Both were measured from the inside first and both are covered by unit tests, but neither of those
/// proves the thing a writer touches: that a tap under a block reaches the gesture that continues the
/// note, and that a block stays put when the title takes the keyboard. The gesture is decided in
/// `gestureRecognizerShouldBegin`, which no unit test goes through.
final class TerminalBlockUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func body(_ app: XCUIApplication) -> XCUIElement { app.textViews.firstMatch }

    private let query = """
        SELECT product_name, SUM(quantity) AS total_quantity_sold
        FROM order_items
        JOIN products ON products.id = order_items.product_id
        GROUP BY product_name
        ORDER BY total_quantity_sold DESC
        LIMIT 2;
        """

    /// Puts `text` on the clipboard, or skips when this device will not allow it — see
    /// `PasteAsPreformattedUITests`, which learned this the hard way on a real phone.
    private func seedClipboard(_ text: String) throws {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]])
        try XCTSkipUnless(UIPasteboard.general.string == text,
                          "this device does not let the test runner set the clipboard")
    }

    private func allowPasteIfAsked(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow Paste"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
    }

    /// A note whose **last line is a closing fence** — the shape that had no room after it.
    ///
    /// Built the way a writer would: paste the query as code, then delete the blank line the paste
    /// leaves behind. `pasteAsCodeEdit` writes that line precisely because a block at the end of a note
    /// has nowhere outside it for the caret to be; taking it away is what puts the note back into the
    /// state this file is about, and it is one backspace away for anybody tidying up.
    private func noteEndingInACodeBlock() throws -> (XCUIApplication, XCUIElement) {
        try seedClipboard(query)
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        field.press(forDuration: 1.2)
        XCTAssertTrue(app.menuItems["Paste as Code"].waitForExistence(timeout: 5),
                      "the edit menu did not open")
        app.menuItems["Paste as Code"].tap()
        allowPasteIfAsked(in: app)

        let pasted = "```\n\(query)\n```\n"
        wait(for: [expectation(for: NSPredicate(format: "value == %@", pasted), evaluatedWith: field)],
             timeout: 10)

        field.typeText(XCUIKeyboardKey.delete.rawValue)
        let terminal = "```\n\(query)\n```"
        wait(for: [expectation(for: NSPredicate(format: "value == %@", terminal), evaluatedWith: field)],
             timeout: 5)
        return (app, field)
    }

    /// Bug 1: a tap under a block that ends the note opens a paragraph after it, and the writer types.
    func testTappingBelowATerminalCodeBlockContinuesTheNote() throws {
        let (app, field) = try noteEndingInACodeBlock()

        // The card's own geometry, read while the block is drawn as one.
        app.textFields["Title"].tap()
        let card = app.descendants(matching: .any)["Code block"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the code card is not on the page")

        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: card.frame.midX, dy: card.frame.maxY + 30))
            .tap()

        app.typeText("This returns the top two products.")
        let expected = "```\n\(query)\n```\nThis returns the top two products."
        wait(for: [expectation(for: NSPredicate(format: "value == %@", expected), evaluatedWith: field)],
             timeout: 5)
        // The block is still a block, and its fences never came back on screen.
        XCTAssertTrue(app.buttons["Copy Code"].exists, "the card de-rendered")
    }

    /// Bug 2: moving focus between the title and the code MUST NOT open a gap before the block.
    ///
    /// Measured as the distance from the **title** down to the card's header, not as the card's
    /// position on screen. Both ride the same scroll (`NotePageView`), so their distance is the block's
    /// position *in the note* — which is the thing that must not move. The card's screen position by
    /// itself is not: the keyboard and the writing toolbar change how much of the page is visible, so
    /// the note legitimately scrolls under them, and asserting on screen position measures that instead
    /// of the defect. Verified while writing this: the card sat 17pt lower with the title focused, and
    /// the title had moved 16pt of it.
    func testFocusingTheTitleDoesNotOpenAGapBeforeTheCodeCard() throws {
        let (app, _) = try noteEndingInACodeBlock()

        // `Copy Code` sits in the card's header in both presentations, so it is the one thing on the
        // page whose position can be compared across the flip.
        let copy = app.buttons["Copy Code"]
        let title = app.textFields["Title"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 5), "the card header is not on the page")
        let whileEditing = copy.frame.minY - title.frame.minY

        app.textFields["Title"].tap()
        let whileReading = copy.frame.minY - title.frame.minY
        // Two element frames, each rounded to whole points by the accessibility layer, so a point of
        // disagreement is the rounding rather than the block. The defect was 15pt at its smallest.
        XCTAssertEqual(whileReading, whileEditing, accuracy: 2.0,
                       "the block dropped \(whileReading - whileEditing)pt below the title when the title took focus")

        // …and back, so nothing has merely settled somewhere new.
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: copy.frame.midX - 120, dy: copy.frame.maxY + 30))
            .tap()
        XCTAssertEqual(copy.frame.minY - title.frame.minY, whileEditing, accuracy: 2.0,
                       "the block did not return to where it was")
    }
}
