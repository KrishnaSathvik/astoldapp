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
    let scriptPreservationRate: Double
    let unwantedTranslationRate: Double
    let codeSwitchPreservationRate: Double
    let emptyRate: Double
}

/// Release-blocking thresholds (docs/04-voice-transcription.md §16). Defaults are strict on the
/// contract-critical dimensions (no translation, preserve script/code-switch).
struct BenchmarkThresholds: Sendable {
    var maxAverageWER = 0.20
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
            && scriptPreservationRate >= t.minScriptPreservationRate
            && unwantedTranslationRate <= t.maxUnwantedTranslationRate
            && codeSwitchPreservationRate >= t.minCodeSwitchPreservationRate
            && emptyRate <= t.maxEmptyRate
    }
}
