import Testing
@testable import Yourly

struct TranscriptInsertionTests {
    @Test func insertIntoEmptyBody() {
        let (text, cursor) = insertTranscript("hello", into: "", at: 0)
        #expect(text == "hello")
        #expect(cursor == 5)
    }

    @Test func insertAtEndAddsBoundarySpaceBetweenWords() {
        let (text, _) = insertTranscript("world", into: "hello", at: 5)
        #expect(text == "hello world")
    }

    @Test func noDoubleSpaceWhenWhitespaceAlreadyPresent() {
        let (text, _) = insertTranscript("world", into: "hello ", at: 6)
        #expect(text == "hello world")
    }

    @Test func insertAtStartAddsTrailingBoundary() {
        let (text, cursor) = insertTranscript("hi", into: "there", at: 0)
        #expect(text == "hi there")
        #expect(cursor == 3)   // caret after "hi " boundary
    }

    @Test func insertInMiddleBothBoundaries() {
        let (text, _) = insertTranscript("big", into: "ab", at: 1)
        #expect(text == "a big b")
    }

    @Test func teluguPreservedVerbatim() {
        let transcript = "నాకు idea వచ్చింది"
        let (text, _) = insertTranscript(transcript, into: "", at: 0)
        #expect(text == transcript)
    }

    @Test func emptyTranscriptIsNoop() {
        let (text, cursor) = insertTranscript("", into: "abc", at: 2)
        #expect(text == "abc")
        #expect(cursor == 2)
    }

    @Test func offsetClampedIntoRange() {
        let (text, _) = insertTranscript("x", into: "ab", at: 99)
        #expect(text == "ab x")
    }

    @Test func insertAdjacentToNewlineNoExtraSpace() {
        let (text, _) = insertTranscript("world", into: "hello\n", at: 6)
        #expect(text == "hello\nworld")   // newline is whitespace → no boundary space
    }

    // UTF-16 → Character offset conversion (used by the UITextView cursor).
    @Test func characterOffsetForAsciiMatchesUTF16() {
        #expect("hello".characterOffset(fromUTF16: 3) == 3)
    }

    @Test func characterOffsetForTeluguRoundTrips() {
        // Telugu combines base+vowel-sign into grapheme clusters, so UTF-16 count > Character count.
        // A caret at the UTF-16 end must map to the Character count (not the UTF-16 count).
        let s = "నాకు"
        #expect(s.utf16.count > s.count)
        #expect(s.characterOffset(fromUTF16: s.utf16.count) == s.count)
    }

    @Test func insertAtTeluguCursorIsVerbatim() {
        let body = "నాకు idea"
        let offset = body.characterOffset(fromUTF16: body.utf16.count)   // end
        let (text, _) = insertTranscript("వచ్చింది", into: body, at: offset)
        #expect(text == "నాకు idea వచ్చింది")
    }

    @Test func characterOffsetClampsBeyondEnd() {
        #expect("ab".characterOffset(fromUTF16: 99) == 2)
    }
}
