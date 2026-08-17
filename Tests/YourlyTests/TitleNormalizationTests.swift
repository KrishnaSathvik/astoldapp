import Testing
@testable import Yourly

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
