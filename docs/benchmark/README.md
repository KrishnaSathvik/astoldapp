# Voice Quality Benchmark (Phase 11)

The evaluation harness that grades transcription quality before release. Contract: transcription must
be **verbatim** — never translate/rewrite, preserve script and code-switching (`../04-voice-transcription.md`
§15–16, `../../RULES.md` §2, §8).

The scoring code is `Core/Voice/TranscriptionBenchmark.swift`; its tests are
`Tests/YourlyTests/TranscriptionBenchmarkTests.swift`. **What it scores is provided by you** — a
versioned corpus of consented recordings and their ground-truth transcripts. The harness never records
or transcribes; it only grades hypotheses against references.

## What it measures (per recording)

| Metric | Meaning |
|---|---|
| `wer` / `cer` | Word / character error rate vs. the reference (0 = perfect). |
| `scriptPreserved` | Non-Latin scripts in the reference (Telugu/Devanagari) also appear in the hypothesis. |
| `unwantedTranslation` | Reference had a non-Latin script but the hypothesis is Latin-only → translated. **Release-blocking.** |
| `codeSwitchPreserved` | A mixed-script reference (e.g. Telugu+English) stayed mixed. |
| `empty` | Hypothesis empty while the reference wasn't. |

`makeReport(_:)` aggregates these into rates; `report.meetsReleaseGate()` checks them against
`BenchmarkThresholds` (default: WER ≤ 0.20, script-preservation ≥ 0.98, **unwanted-translation = 0**,
code-switch ≥ 0.95, empty ≤ 0.02).

## Building the corpus (your part)

1. Record **consented** clips (never production notes) covering the groups in
   `../04-voice-transcription.md` §15: English, Indian English, Telugu, Hindi, Telugu+English,
   Hindi+English — plus names, India/US places, slang, fast/quiet speech, background noise,
   fillers/repetition, numbers. Aim for ≥ 20 per group, growing over time.
2. For each clip, store the audio and its verbatim ground-truth transcript, e.g.:

   ```json
   [
     { "id": "te-001", "language": "te", "reference": "నాకు Alaska trip గురించి ఒక idea వచ్చింది." },
     { "id": "teen-014", "language": "te-en", "reference": "మనం Anchorage లో stay చేద్దాం." }
   ]
   ```

3. Run each clip through the relay (real `gpt-transcribe`) to get a hypothesis, then:

   ```swift
   let evals = corpus.map { evaluate(reference: $0.reference, hypothesis: hypotheses[$0.id]!) }
   let report = makeReport(evals)
   precondition(report.meetsReleaseGate(), "voice quality gate not met: \(report)")
   ```

4. Compare prompt/language-hint configurations (`../04-voice-transcription.md` §10, Phase 11) and pick
   the one with the best measured results. **Do not** add a text-cleanup model.

## Release gate

Even with acceptable WER, block release if the system frequently translates Telugu/Hindi to English,
collapses mixed-language speech, invents content during silence, "improves" meaning, or drops large
sections (`../04-voice-transcription.md` §16). The harness's `unwantedTranslation`, `codeSwitchPreserved`,
and `empty` flags map directly to these.
