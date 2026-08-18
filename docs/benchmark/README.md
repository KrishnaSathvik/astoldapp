# Voice Quality Benchmark (Phase 11)

The evaluation harness that grades transcription quality before release. Contract:
**preserve the words, format the speech** — punctuation and capitalization are allowed, changing the
speaker's words is not, and translation/rewriting never is (`../04-voice-transcription.md` §2, §15–16,
`../../RULES.md` §2, §8).

The scoring code is `Core/Voice/TranscriptionBenchmark.swift`; its tests are
`Tests/YourlyTests/TranscriptionBenchmarkTests.swift`. **What it scores is provided by you** — a
versioned corpus of consented recordings and their ground-truth transcripts. The harness never records
or transcribes; it only grades hypotheses against references.

> Structure commands have their own manual pass — see [`structure-commands.md`](./structure-commands.md).
> It grades false positives on real speech, not wording accuracy, and is separate from this harness.

## What it measures (per recording)

| Metric | Meaning |
|---|---|
| `contentWER` | WER ignoring case and punctuation — **the wording contract.** Gated. |
| `wer` / `cer` | Raw word / character error rate vs. the reference (0 = perfect). Readability. |
| `punctuationER` | Error rate of the punctuation sequence. Readability — reported, not gated. |
| `scriptPreserved` | Non-Latin scripts in the reference (Telugu/Devanagari) also appear in the hypothesis. |
| `unwantedTranslation` | Reference had a non-Latin script but the hypothesis is Latin-only → translated. **Release-blocking.** |
| `codeSwitchPreserved` | A mixed-script reference (e.g. Telugu+English) stayed mixed. |
| `empty` | Hypothesis empty while the reference wasn't. |

`makeReport(_:)` aggregates these into rates; `report.meetsReleaseGate()` checks them against
`BenchmarkThresholds` (default: content WER ≤ 0.15, raw WER ≤ 0.20, script-preservation ≥ 0.98,
**unwanted-translation = 0**, code-switch ≥ 0.95, empty ≤ 0.02). `report.gateFailures()` returns the
reasons in words, for the decision log.

### Why two WERs

Punctuation is allowed now, and raw WER cannot tell punctuation from paraphrase — both move it. So:

| | raw WER | content WER | verdict |
|---|---|---|---|
| Model adds commas and full stops | up | **0** | formatted — good |
| Model swaps words / paraphrases | up | **up** | rewritten — contract breach |

Only content WER (with script preservation and unwanted translation) gates a release.

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

   References are written the way a person would write that sentence down — **with** punctuation.
   That is what the product now aims to produce, and `contentWER` ignores the punctuation anyway.

3. Run each clip through the relay to get a hypothesis, then:

   ```swift
   let evals = corpus.map { evaluate(reference: $0.reference, hypothesis: hypotheses[$0.id]!) }
   let report = makeReport(evals)
   precondition(report.meetsReleaseGate(), "voice quality gate not met: \(report.gateFailures())")
   ```

4. Compare configurations instead of guessing. One `BenchmarkArm` per (model × prompt variant),
   every arm over the *same* corpus:

   ```swift
   let comparison = compareArms([
       BenchmarkArm(name: "gpt-4o-transcribe / punctuated", model: "gpt-4o-transcribe",
                    promptVariant: "punctuated", report: reportA, medianLatencySeconds: latencyA),
       BenchmarkArm(name: "<alternative> / punctuated", model: "<alternative>",
                    promptVariant: "punctuated", report: reportB, medianLatencySeconds: latencyB),
       BenchmarkArm(name: "gpt-4o-transcribe / strictVerbatim", model: "gpt-4o-transcribe",
                    promptVariant: "strictVerbatim", report: reportC, medianLatencySeconds: latencyC),
   ])
   // comparison.winner → set TRANSCRIBE_MODEL / TRANSCRIBE_PROMPT_VARIANT on the relay
   ```

   Ranking is content WER → punctuation error rate → median latency, among arms that clear the gate.
   Model **recency and name are not inputs.** Record `comparison.failing` reasons alongside the
   decision. **Do not** add a text-cleanup model to close a gap — that breaks the contract the
   benchmark exists to protect.

### Status

The scorer, the arm comparison, and the prompt variants are implemented and unit-tested. The A/B
itself is **not run**: it needs the consented corpus (which does not exist in this repo) and a relay
run against real API credentials. Until then `TRANSCRIBE_MODEL` stays `gpt-4o-transcribe` and
`TRANSCRIBE_PROMPT_VARIANT` stays `punctuated`.

## Release gate

Even with acceptable WER, block release if the system frequently translates Telugu/Hindi to English,
collapses mixed-language speech, invents content during silence, "improves" meaning, or drops large
sections (`../04-voice-transcription.md` §16). The harness's `unwantedTranslation`, `codeSwitchPreserved`,
and `empty` flags map directly to these.
