import Testing
import Foundation
@testable import Yourly

struct NoteSearchTests {
    private func note(_ title: String?, _ body: String) -> Note {
        Note(title: title, body: body)
    }

    @Test func caseInsensitiveLatin() {
        let n = note("Alaska trip idea", "Anchorage and Seward")
        #expect(noteMatches(n, query: "alaska"))
        #expect(noteMatches(n, query: "SEWARD"))
    }

    @Test func matchesBodyAndTitle() {
        let n = note("Work ideas", "New project direction")
        #expect(noteMatches(n, query: "work"))       // title
        #expect(noteMatches(n, query: "project"))    // body
        #expect(!noteMatches(n, query: "vacation"))
    }

    @Test func emptyQueryReturnsNothing() {
        let n = note("x", "y")
        #expect(!noteMatches(n, query: ""))
        #expect(!noteMatches(n, query: "   "))
        #expect(searchNotes([n], query: "").isEmpty)
    }

    @Test func teluguUnicodeQuery() {
        let n = note(nil, "నాకు Alaska trip గురించి ఒక idea వచ్చింది.")
        #expect(noteMatches(n, query: "గురించి"))
        #expect(noteMatches(n, query: "alaska"))     // mixed-language body
    }

    @Test func hindiUnicodeQuery() {
        let n = note("यात्रा", "मुझे कल फ़ोन करना है")
        #expect(noteMatches(n, query: "फ़ोन"))
        #expect(noteMatches(n, query: "यात्रा"))
    }

    @Test func diacriticInsensitive() {
        let n = note(nil, "café and résumé")
        #expect(noteMatches(n, query: "cafe"))
        #expect(noteMatches(n, query: "resume"))
    }

    @Test func filterPreservesOrder() {
        let a = note("Alaska", "trip")
        let b = note("Alabama", "road")
        let c = note("Boston", "trip")
        let results = searchNotes([a, b, c], query: "ala")
        #expect(results.map { $0.title } == ["Alaska", "Alabama"])
    }
}
