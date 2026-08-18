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

// MARK: - "Preserve the words. Format the speech." (RULES.md §2)

@Suite("Formatting vs rewriting")
struct FormattingContractTests {
    /// The §14 example. Adding punctuation and capitalization must not register as a wording change.
    private let spoken = "Actually I don't know maybe we can go Saturday but if Ravi is coming then Sunday is probably better what do you think"
    private let formatted = "Actually, I don't know. Maybe we can go Saturday, but if Ravi is coming, then Sunday is probably better. What do you think?"
    private let rewritten = "Ravi and I should probably go on Sunday instead of Saturday."

    @Test func punctuationAndCapitalizationCostNothingOnContentWER() {
        #expect(contentWordErrorRate(reference: formatted, hypothesis: spoken) == 0)
        #expect(contentWordErrorRate(reference: spoken, hypothesis: formatted) == 0)
    }

    @Test func rawWERStillSeesTheFormattingDifference() {
        // Raw WER is a readability signal, so it is *not* zero here — that separation is the point.
        #expect(wordErrorRate(reference: formatted, hypothesis: spoken) > 0)
    }

    @Test func rewritingIsCaughtByContentWER() {
        #expect(contentWordErrorRate(reference: formatted, hypothesis: rewritten) > 0.5)
    }

    @Test func addedPunctuationDoesNotAffectScriptOrTranslationChecks() {
        let te = "నాకు Alaska trip గురించి ఒక idea వచ్చింది"
        let tePunctuated = "నాకు Alaska trip గురించి ఒక idea వచ్చింది."
        let evaluation = evaluate(reference: te, hypothesis: tePunctuated)
        #expect(evaluation.contentWER == 0)
        #expect(evaluation.scriptPreserved)
        #expect(!evaluation.unwantedTranslation)
        #expect(evaluation.codeSwitchPreserved)
    }

    @Test func punctuationErrorRateRewardsMatchingPunctuation() {
        let none = punctuationErrorRate(reference: formatted, hypothesis: spoken)
        let exact = punctuationErrorRate(reference: formatted, hypothesis: formatted)
        #expect(exact == 0)
        #expect(none > exact)
    }
}

// MARK: - Model / prompt selection

@Suite("Arm comparison")
struct ArmComparisonTests {
    private func report(contentWER: Double,
                        punctuationER: Double = 0.1,
                        wer: Double = 0.10,
                        translation: Double = 0) -> BenchmarkReport {
        BenchmarkReport(
            count: 50,
            averageWER: wer,
            averageCER: 0.05,
            averageContentWER: contentWER,
            averagePunctuationER: punctuationER,
            scriptPreservationRate: 1.0,
            unwantedTranslationRate: translation,
            codeSwitchPreservationRate: 1.0,
            emptyRate: 0
        )
    }

    @Test func winnerIsTheLowestContentWERAmongPassingArms() {
        let arms = [
            BenchmarkArm(name: "b", model: "m2", promptVariant: "punctuated",
                         report: report(contentWER: 0.04), medianLatencySeconds: 1.0),
            BenchmarkArm(name: "a", model: "m1", promptVariant: "punctuated",
                         report: report(contentWER: 0.09), medianLatencySeconds: 0.5),
        ]
        let result = compareArms(arms)
        #expect(result.winner == "b")           // better wording wins over lower latency
        #expect(result.passing == ["b", "a"])
        #expect(result.failing.isEmpty)
    }

    @Test func anArmThatTranslatesCannotWinHoweverAccurateItIs() {
        let arms = [
            BenchmarkArm(name: "translates", model: "m2", promptVariant: "terse",
                         report: report(contentWER: 0.01, translation: 0.05),
                         medianLatencySeconds: 0.2),
            BenchmarkArm(name: "faithful", model: "m1", promptVariant: "punctuated",
                         report: report(contentWER: 0.12), medianLatencySeconds: 2.0),
        ]
        let result = compareArms(arms)
        #expect(result.winner == "faithful")
        #expect(result.failing.map(\.name) == ["translates"])
        #expect(result.failing.first?.reasons.contains { $0.contains("unwanted translation") } == true)
    }

    @Test func punctuationBreaksTiesOnceWordingIsEqual() {
        let arms = [
            BenchmarkArm(name: "scrappy", model: "m1", promptVariant: "strictVerbatim",
                         report: report(contentWER: 0.05, punctuationER: 0.8),
                         medianLatencySeconds: 0.5),
            BenchmarkArm(name: "readable", model: "m1", promptVariant: "punctuated",
                         report: report(contentWER: 0.05, punctuationER: 0.2),
                         medianLatencySeconds: 0.9),
        ]
        #expect(compareArms(arms).winner == "readable")
    }

    @Test func noWinnerWhenNothingClearsTheGate() {
        let arms = [
            BenchmarkArm(name: "bad", model: "m1", promptVariant: "punctuated",
                         report: report(contentWER: 0.9, wer: 0.9), medianLatencySeconds: 0.5),
        ]
        let result = compareArms(arms)
        #expect(result.winner == nil)
        #expect(result.passing.isEmpty)
    }
}
