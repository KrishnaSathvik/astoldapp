import Testing
@testable import Yourly

/// `normalizedTitle` is the **display** spelling — a row, a search result, a preview. It trims so a
/// stray leading space cannot indent a row, and it never writes back to the note.
struct TitleNormalizationTests {
    @Test func whitespaceOnlyBecomesNil() {
        #expect(normalizedTitle("   \n ") == nil)
    }
    @Test func trimsSurroundingWhitespace() {
        #expect(normalizedTitle("  Alaska trip  ") == "Alaska trip")
    }
    @Test func emptyBecomesNil() {
        #expect(normalizedTitle("") == nil)
    }
    @Test func nilStaysNil() {
        #expect(normalizedTitle(nil) == nil)
    }
    @Test func keepsInnerContent() {
        #expect(normalizedTitle("a b") == "a b")
    }
}

/// `storedTitle` is the **stored** spelling, and the difference is the whole of the space bug: a space
/// is trailing whitespace from the moment it is typed until the next letter lands, so a store that
/// trims is a store that deletes the character the writer is in the middle of typing.
struct StoredTitleTests {
    @Test func whitespaceOnlyBecomesNoTitle() {
        #expect(storedTitle("   \n ") == nil)
        #expect(storedTitle("") == nil)
        #expect(storedTitle(nil) == nil)
    }

    @Test func theSpaceJustTypedSurvives() {
        #expect(storedTitle("Alaska ") == "Alaska ")
    }

    @Test func nothingAboutARealTitleIsTouched() {
        #expect(storedTitle("  Alaska  ") == "  Alaska  ")
        #expect(storedTitle("Alaska Road Trip") == "Alaska Road Trip")
        #expect(storedTitle("My  Summer Plan") == "My  Summer Plan")
        #expect(storedTitle(" Alaska") == " Alaska")
    }
}
