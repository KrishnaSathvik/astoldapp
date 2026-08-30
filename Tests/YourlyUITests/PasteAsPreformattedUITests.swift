import XCTest
import UIKit
import UniformTypeIdentifiers

/// The path a writer actually takes: a diagram on the clipboard, a long press, **Paste as Preformatted**.
///
/// Everything else about this feature was verified from the inside — the parser, the layout, the card,
/// the export. None of it proves the one thing a writer touches: that the verb is in the menu and that
/// tapping it does what it says. The menu is built in
/// `textView(_:editMenuForTextIn:suggestedActions:)`, which no unit test can reach.
///
/// One thing this pinned that nothing else could: the compact edit menu fits three items, so with two
/// paste verbs **Paste as Preformatted** sits behind the `›` chevron while **Paste as Code** does not.
/// It is reachable, and it is one tap deeper. That is a real difference in discoverability between two
/// verbs that are meant to be siblings, and it is recorded here rather than assumed away.
final class PasteAsPreformattedUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func body(_ app: XCUIApplication) -> XCUIElement { app.textViews.firstMatch }

    private let diagram = "DOL / USCIS\n    │\n    ▼\nAirflow detects new release"

    /// Puts `text` on the clipboard, or skips the test when this device will not allow it.
    ///
    /// On the **simulator** the test runner shares a pasteboard with the app, so seeding it works. On a
    /// **physical device** it does not: the write is silently dropped and the clipboard keeps whatever
    /// was already there — which made these tests assert against someone else's diagram and fail for a
    /// reason that had nothing to do with the app. Checking the write rather than assuming it means
    /// these start running again by themselves if that ever changes.
    private func seedClipboard(_ text: String) throws {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]])
        try XCTSkipUnless(UIPasteboard.general.string == text,
                          "this device does not let the test runner set the clipboard")
    }

    private func launched() throws -> XCUIApplication {
        try seedClipboard(diagram)
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()
        return app
    }

    /// Taps through iOS's pasteboard-access prompt, when it appears.
    ///
    /// It appears because **Paste as Preformatted** reads `UIPasteboard.general.string` itself, which
    /// plain **Paste** never has to do — UIKit's own paste is system-mediated and carries the user's
    /// intent with it. Any clipboard filled by another app therefore costs one extra confirmation. That
    /// is not this feature's doing: **Paste as Code** has behaved this way since it shipped, and both
    /// verbs hit it identically. It is dismissed here so the test can go on to check the thing it is
    /// actually about — that the characters land.
    private func allowPasteIfAsked(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow Paste"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
    }

    /// Opens the edit menu and expands it past the three items the compact form shows.
    private func openExpandedEditMenu(in app: XCUIApplication, on field: XCUIElement) {
        field.press(forDuration: 1.2)
        XCTAssertTrue(app.menuItems["Paste as Code"].waitForExistence(timeout: 5),
                      "the edit menu did not open")
        // The chevron at the menu's right end. It carries no stable label of its own; UIKit exposes it
        // as "Forward", with a positional fallback in case that changes.
        let chevron = app.buttons["Forward"].firstMatch
        if chevron.exists {
            chevron.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.766, dy: 0.297)).tap()
        }
    }

    /// Both verbs are in the menu the writer already opens to paste.
    func testBothPasteVerbsAreReachableFromTheEditMenu() throws {
        let app = try launched()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        openExpandedEditMenu(in: app, on: field)

        XCTAssertTrue(app.buttons["Paste as Preformatted"].waitForExistence(timeout: 5),
                      "Paste as Preformatted is not reachable from the edit menu")
        XCTAssertTrue(app.buttons["Paste as Code"].exists,
                      "Paste as Code disappeared when Paste as Preformatted was added")
    }

    /// **Paste as Code** stays in the compact menu, without expanding. Pinned because it is the verb
    /// that shipped first and must not be demoted by the one that came after it.
    func testPasteAsCodeIsStillVisibleWithoutExpandingTheMenu() throws {
        let app = try launched()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        field.press(forDuration: 1.2)
        XCTAssertTrue(app.menuItems["Paste as Code"].waitForExistence(timeout: 5),
                      "Paste as Code left the compact edit menu")
    }

    /// Tapping it fences the clipboard as plain text, in `body`, exactly as copied.
    func testPastingADiagramAsPreformattedWritesATextFence() throws {
        let app = try launched()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        openExpandedEditMenu(in: app, on: field)

        let item = app.buttons["Paste as Preformatted"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Paste as Preformatted did not appear")
        item.tap()
        allowPasteIfAsked(in: app)

        // `-exposeSourceForTests` makes the body report its canonical source, fences included — so this
        // asserts every space and every box character of the clipboard landed unchanged.
        let expected = "```text\n\(diagram)\n```\n"
        let landed = expectation(for: NSPredicate(format: "value == %@", expected),
                                 evaluatedWith: field)
        wait(for: [landed], timeout: 5)
    }

    /// The case this feature exists for: an ordinary **Paste** of a diagram that no clipboard flavor
    /// described. Nothing states it is preformatted, so `PreformattedDetection` has to recognise it —
    /// otherwise it lands as prose and its alignment is gone the moment it is drawn.
    func testAnOrdinaryPasteOfADiagramIsRecognised() throws {
        let tree = "repo/\n│\n├── apps/\n│   ├── web/\n│   └── api/"
        try seedClipboard(tree)
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        field.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5), "the edit menu did not open")
        paste.tap()
        allowPasteIfAsked(in: app)

        let expected = "```text\n\(tree)\n```\n"
        let landed = expectation(for: NSPredicate(format: "value == %@", expected),
                                 evaluatedWith: field)
        wait(for: [landed], timeout: 10)
    }

    /// …and ordinary writing pasted the ordinary way is still ordinary writing.
    func testAnOrdinaryPasteOfProseIsStillProse() throws {
        let prose = "Eggs\nMilk\nBread\nCoffee"
        try seedClipboard(prose)
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        field.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5), "the edit menu did not open")
        paste.tap()
        allowPasteIfAsked(in: app)

        let landed = expectation(for: NSPredicate(format: "value == %@", prose), evaluatedWith: field)
        wait(for: [landed], timeout: 10)
    }

    /// And once nothing is being edited, the diagram is a card — the thing the writer came for.
    func testTheDiagramBecomesAPlainTextCard() throws {
        let app = try launched()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        openExpandedEditMenu(in: app, on: field)
        let item = app.buttons["Paste as Preformatted"]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Paste as Preformatted did not appear")
        item.tap()
        allowPasteIfAsked(in: app)

        let backToNotes = app.buttons["Back to notes"].firstMatch
        XCTAssertTrue(backToNotes.waitForExistence(timeout: 10), "the editor never came back")
        backToNotes.tap()

        let card = app.descendants(matching: .any)["Plain text block"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10),
                      "the pasted diagram never became a Plain text card")
    }
}
