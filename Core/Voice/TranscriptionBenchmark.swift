import Foundation

/// Evaluation harness for the voice quality program (build-plan Phase 11, docs/04-voice-transcription.md
/// §15–16). Pure, deterministic scoring so a versioned corpus of consented recordings can be graded and
/// gated before release. The audio/transcription itself is produced elsewhere; this only scores results.

// MARK: - Scripts

enum TranscriptScript: Hashable, Sendable {
    case latin, telugu, devanagari, other
}

/// Scripts present in `text` (ignoring whitespace, digits, and punctuation).
func scripts(in text: String) -> Set<TranscriptScript> {
    var found: Set<TranscriptScript> = []
    for scalar in text.unicodeScalars {
        if CharacterSet.whitespacesAndNewlines.contains(scalar)
            || CharacterSet.punctuationCharacters.contains(scalar)
            || CharacterSet.decimalDigits.contains(scalar)
            || CharacterSet.symbols.contains(scalar) { continue }
        switch scalar.value {
        case 0x0C00...0x0C7F: found.insert(.telugu)
        case 0x0900...0x097F: found.insert(.devanagari)
        case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F: found.insert(.latin)
        default: found.insert(.other)
        }
    }
    return found
}

// MARK: - Error rates

/// Generic Levenshtein edit distance.
func editDistance<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }
    var dp = Array(0...b.count)
    for i in 1...a.count {
        var prev = dp[0]
        dp[0] = i
        for j in 1...b.count {
            let cur = dp[j]
            dp[j] = a[i - 1] == b[j - 1] ? prev : Swift.min(prev, dp[j], dp[j - 1]) + 1
            prev = cur
        }
    }
    return dp[b.count]
}

private func tokens(_ s: String) -> [Substring] {
    s.split(whereSeparator: { $0.isWhitespace })
}

/// Word Error Rate: word-level edit distance / reference word count. 0 = perfect.
func wordErrorRate(reference: String, hypothesis: String) -> Double {
    let ref = tokens(reference).map(String.init)
    let hyp = tokens(hypothesis).map(String.init)
    guard !ref.isEmpty else { return hyp.isEmpty ? 0 : 1 }
    return Double(editDistance(ref, hyp)) / Double(ref.count)
}

/// Character Error Rate: character-level edit distance / reference character count.
func characterErrorRate(reference: String, hypothesis: String) -> Double {
    let ref = Array(reference)
    let hyp = Array(hypothesis)
    guard !ref.isEmpty else { return hyp.isEmpty ? 0 : 1 }
    return Double(editDistance(ref, hyp)) / Double(ref.count)
}

/// Punctuation and case, which the transcription contract now *allows* the model to add
/// ("Preserve the words. Format the speech." — RULES.md §2).
private let formattingCharacters: CharacterSet = {
    var set = CharacterSet.punctuationCharacters
    set.formUnion(.symbols)
    return set
}()

/// Lowercased, punctuation-free tokens — what the speaker actually *said*.
private func contentTokens(_ s: String) -> [String] {
    var stripped = ""
    stripped.reserveCapacity(s.count)
    for scalar in s.lowercased().unicodeScalars {
        stripped.unicodeScalars.append(formattingCharacters.contains(scalar) ? " " : scalar)
    }
    return stripped.split(whereSeparator: { $0.isWhitespace }).map(String.init)
}

/// Word Error Rate over content words only — case and punctuation removed.
///
/// This is the **contract** metric. Raw `wordErrorRate` punishes a model for adding the commas and
/// full stops the product now wants; this one only moves when the model changes, drops, or invents
/// the speaker's actual words. A near-zero content WER with a higher raw WER means "formatted, not
/// rewritten" — exactly the intended behaviour.
func contentWordErrorRate(reference: String, hypothesis: String) -> Double {
    let ref = contentTokens(reference)
    let hyp = contentTokens(hypothesis)
    guard !ref.isEmpty else { return hyp.isEmpty ? 0 : 1 }
    return Double(editDistance(ref, hyp)) / Double(ref.count)
}

/// The ordered sequence of punctuation marks in a string.
private func punctuationSequence(_ s: String) -> [Character] {
    s.unicodeScalars.filter { CharacterSet.punctuationCharacters.contains($0) }.map(Character.init)
}

/// Error rate over the punctuation sequence: edit distance / reference punctuation count.
///
/// Readability quality, **not** a contract breach — it is reported and compared between benchmark
/// arms, never used to block a release on its own.
func punctuationErrorRate(reference: String, hypothesis: String) -> Double {
    let ref = punctuationSequence(reference)
    let hyp = punctuationSequence(hypothesis)
    guard !ref.isEmpty else { return hyp.isEmpty ? 0 : 1 }
    return Double(editDistance(ref, hyp)) / Double(ref.count)
}

// MARK: - Case evaluation

struct BenchmarkCase: Sendable {
    let id: String
    /// "en", "te", "hi", "te-en", "hi-en", …
    let language: String
    /// Expected verbatim transcript (consented ground truth).
    let reference: String
}

struct CaseEvaluation: Sendable, Equatable {
    let wer: Double
    let cer: Double
    /// WER ignoring case and punctuation — the "did the words survive?" contract metric.
    let contentWER: Double
    /// Error rate of the punctuation sequence — readability, reported not gated.
    let punctuationER: Double
    /// Non-Latin scripts in the reference (Telugu/Devanagari) also appear in the hypothesis.
    let scriptPreserved: Bool
    /// Reference had a non-Latin script but the hypothesis is Latin-only → likely translated.
    let unwantedTranslation: Bool
    /// Reference mixed scripts (code-switch) and the hypothesis preserved that mix.
    let codeSwitchPreserved: Bool
    /// Hypothesis empty while the reference was not.
    let empty: Bool
}

func evaluate(reference: String, hypothesis: String) -> CaseEvaluation {
    let refScripts = scripts(in: reference)
    let hypScripts = scripts(in: hypothesis)
    let refNonLatin = refScripts.subtracting([.latin, .other])
    let hypIsEmpty = hypothesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let refIsEmpty = reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    let scriptPreserved = refNonLatin.isSubset(of: hypScripts)
    let unwantedTranslation = !refNonLatin.isEmpty && refNonLatin.isDisjoint(with: hypScripts) && !hypIsEmpty
    let isCodeSwitch = refScripts.intersection([.latin, .telugu, .devanagari]).count >= 2
    let codeSwitchPreserved = !isCodeSwitch || refScripts.isSubset(of: hypScripts)

    return CaseEvaluation(
        wer: wordErrorRate(reference: reference, hypothesis: hypothesis),
        cer: characterErrorRate(reference: reference, hypothesis: hypothesis),
        contentWER: contentWordErrorRate(reference: reference, hypothesis: hypothesis),
        punctuationER: punctuationErrorRate(reference: reference, hypothesis: hypothesis),
        scriptPreserved: scriptPreserved,
        unwantedTranslation: unwantedTranslation,
        codeSwitchPreserved: codeSwitchPreserved,
        empty: hypIsEmpty && !refIsEmpty
    )
}

// MARK: - Aggregate report + release gate

struct BenchmarkReport: Sendable {
    let count: Int
    let averageWER: Double
    let averageCER: Double
    let averageContentWER: Double
    let averagePunctuationER: Double
    let scriptPreservationRate: Double
    let unwantedTranslationRate: Double
    let codeSwitchPreservationRate: Double
    let emptyRate: Double
}

/// Release-blocking thresholds (docs/04-voice-transcription.md §16). Defaults are strict on the
/// contract-critical dimensions (no translation, preserve script/code-switch).
struct BenchmarkThresholds: Sendable {
    var maxAverageWER = 0.20
    /// The wording contract. Stricter than raw WER because punctuation no longer counts against it.
    var maxAverageContentWER = 0.15
    var minScriptPreservationRate = 0.98
    var maxUnwantedTranslationRate = 0.0
    var minCodeSwitchPreservationRate = 0.95
    var maxEmptyRate = 0.02
}

func makeReport(_ evaluations: [CaseEvaluation]) -> BenchmarkReport {
    let n = max(evaluations.count, 1)
    func rate(_ predicate: (CaseEvaluation) -> Bool) -> Double {
        Double(evaluations.filter(predicate).count) / Double(n)
    }
    return BenchmarkReport(
        count: evaluations.count,
        averageWER: evaluations.map(\.wer).reduce(0, +) / Double(n),
        averageCER: evaluations.map(\.cer).reduce(0, +) / Double(n),
        averageContentWER: evaluations.map(\.contentWER).reduce(0, +) / Double(n),
        averagePunctuationER: evaluations.map(\.punctuationER).reduce(0, +) / Double(n),
        scriptPreservationRate: rate { $0.scriptPreserved },
        unwantedTranslationRate: rate { $0.unwantedTranslation },
        codeSwitchPreservationRate: rate { $0.codeSwitchPreserved },
        emptyRate: rate { $0.empty }
    )
}

extension BenchmarkReport {
    /// True when the report clears every release-blocking threshold.
    func meetsReleaseGate(_ t: BenchmarkThresholds = .init()) -> Bool {
        averageWER <= t.maxAverageWER
            && averageContentWER <= t.maxAverageContentWER
            && scriptPreservationRate >= t.minScriptPreservationRate
            && unwantedTranslationRate <= t.maxUnwantedTranslationRate
            && codeSwitchPreservationRate >= t.minCodeSwitchPreservationRate
            && emptyRate <= t.maxEmptyRate
    }
}

// MARK: - Model / prompt comparison

/// One configuration under test: a model + prompt variant scored over the *same* corpus.
///
/// The V1 model decision is made from these numbers, never from a model being newer or generically
/// recommended (RULES.md §2, docs/benchmark/README.md). Producing the hypotheses needs the real
/// consented corpus and a relay run; this type only compares the results.
struct BenchmarkArm: Sendable {
    /// e.g. "gpt-4o-transcribe / punctuated"
    let name: String
    let model: String
    let promptVariant: String
    let report: BenchmarkReport
    /// Median end-to-end latency for the corpus, in seconds. Tie-breaker only.
    let medianLatencySeconds: Double
}

struct ArmComparison: Sendable {
    /// Arms that cleared every release-blocking threshold, best first.
    let passing: [String]
    /// Arms that failed the gate, with the reason recorded for the decision log.
    let failing: [(name: String, reasons: [String])]
    /// The arm to ship, or nil when nothing cleared the gate.
    let winner: String?
}

extension BenchmarkReport {
    /// Human-readable reasons this report misses the gate; empty when it passes.
    func gateFailures(_ t: BenchmarkThresholds = .init()) -> [String] {
        var reasons: [String] = []
        func check(_ ok: Bool, _ reason: @autoclosure () -> String) { if !ok { reasons.append(reason()) } }
        check(averageWER <= t.maxAverageWER, "WER \(averageWER) > \(t.maxAverageWER)")
        check(averageContentWER <= t.maxAverageContentWER,
              "content WER \(averageContentWER) > \(t.maxAverageContentWER)")
        check(scriptPreservationRate >= t.minScriptPreservationRate,
              "script preservation \(scriptPreservationRate) < \(t.minScriptPreservationRate)")
        check(unwantedTranslationRate <= t.maxUnwantedTranslationRate,
              "unwanted translation \(unwantedTranslationRate) > \(t.maxUnwantedTranslationRate)")
        check(codeSwitchPreservationRate >= t.minCodeSwitchPreservationRate,
              "code-switch preservation \(codeSwitchPreservationRate) < \(t.minCodeSwitchPreservationRate)")
        check(emptyRate <= t.maxEmptyRate, "empty transcripts \(emptyRate) > \(t.maxEmptyRate)")
        return reasons
    }
}

/// Ranks arms by measured product performance.
///
/// Order of preference, applied only to arms that clear the release gate:
///  1. lowest **content WER** — the user's words are the product;
///  2. lowest punctuation error rate — readability, once wording is equal;
///  3. lowest median latency.
///
/// Deliberately does **not** consider model recency or name.
func compareArms(_ arms: [BenchmarkArm], thresholds: BenchmarkThresholds = .init()) -> ArmComparison {
    var passing: [BenchmarkArm] = []
    var failing: [(name: String, reasons: [String])] = []

    for arm in arms {
        let reasons = arm.report.gateFailures(thresholds)
        if reasons.isEmpty { passing.append(arm) } else { failing.append((arm.name, reasons)) }
    }

    let ranked = passing.sorted { a, b in
        if a.report.averageContentWER != b.report.averageContentWER {
            return a.report.averageContentWER < b.report.averageContentWER
        }
        if a.report.averagePunctuationER != b.report.averagePunctuationER {
            return a.report.averagePunctuationER < b.report.averagePunctuationER
        }
        return a.medianLatencySeconds < b.medianLatencySeconds
    }

    return ArmComparison(
        passing: ranked.map(\.name),
        failing: failing,
        winner: ranked.first?.name
    )
}
