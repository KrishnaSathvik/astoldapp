import Testing
@testable import Yourly

struct TranscriptionBenchmarkTests {
    @Test func scriptsDetectsTeluguLatinAndCodeSwitch() {
        #expect(scripts(in: "hello") == [.latin])
        #expect(scripts(in: "నాకు") == [.telugu])
        #expect(scripts(in: "मुझे") == [.devanagari])
        #expect(scripts(in: "నాకు idea").isSuperset(of: [.telugu, .latin]))
    }

    @Test func werAndCerPerfectAndImperfect() {
        #expect(wordErrorRate(reference: "a b c", hypothesis: "a b c") == 0)
        #expect(wordErrorRate(reference: "a b c", hypothesis: "a x c") == Double(1) / 3)
        #expect(characterErrorRate(reference: "abc", hypothesis: "abc") == 0)
        #expect(characterErrorRate(reference: "abc", hypothesis: "abx") == Double(1) / 3)
    }

    @Test func verbatimTeluguMixIsClean() {
        let ref = "నాకు Alaska trip గురించి ఒక idea వచ్చింది."
        let e = evaluate(reference: ref, hypothesis: ref)
        #expect(e.wer == 0)
        #expect(e.scriptPreserved)
        #expect(!e.unwantedTranslation)
        #expect(e.codeSwitchPreserved)
        #expect(!e.empty)
    }

    @Test func translationToEnglishIsFlagged() {
        // Telugu reference transcribed as English → unwanted translation, script lost, code-switch lost.
        let e = evaluate(reference: "నాకు idea వచ్చింది", hypothesis: "I had an idea")
        #expect(e.unwantedTranslation)
        #expect(!e.scriptPreserved)
    }

    @Test func emptyHypothesisIsFlagged() {
        let e = evaluate(reference: "నాకు idea", hypothesis: "   ")
        #expect(e.empty)
        #expect(!e.unwantedTranslation)   // empty is a separate failure, not translation
    }

    @Test func codeSwitchCollapsedIsFlagged() {
        // Reference mixes Telugu+Latin; hypothesis keeps only Latin → code-switch not preserved.
        let e = evaluate(reference: "నాకు idea వచ్చింది today", hypothesis: "idea today")
        #expect(!e.codeSwitchPreserved)
    }

    @Test func releaseGatePassesForCleanCorpus() {
        let refs = [
            "I keep thinking about the trip",
            "నాకు Alaska idea వచ్చింది",
            "मुझे कल फ़ोन करना है",
        ]
        let report = makeReport(refs.map { evaluate(reference: $0, hypothesis: $0) })
        #expect(report.meetsReleaseGate())
        #expect(report.unwantedTranslationRate == 0)
        #expect(report.averageWER == 0)
    }

    @Test func releaseGateFailsWhenTranslating() {
        let evals = [
            evaluate(reference: "నాకు idea వచ్చింది", hypothesis: "I had an idea"),
            evaluate(reference: "మంచి రోజు", hypothesis: "good day"),
        ]
        let report = makeReport(evals)
        #expect(report.unwantedTranslationRate == 1.0)
        #expect(!report.meetsReleaseGate())
    }
}
