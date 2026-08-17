# Yourly Slice 3 (Phase 8) — Voice capture UX with a fake transcription service

> **For Claude:** REQUIRED SUB-SKILL: superpowers:executing-plans. Conventions unchanged (build/test
> via xcodebuild on `iPhone 17 Pro`, commit per green step, re-run `xcodegen generate` on structural
> source changes).

**Goal:** Perfect the entire on-device voice capture experience — mic permission, recording UI
(waveform, timer, Cancel/Done), transcribing state, cursor insertion, and error/retry — against a
**fake, deterministic** transcription service. No backend, no OpenAI key, no network (build plan
Phase 8: "Do this before OpenAI integration").

**Architecture:** Protocol-driven and injectable so the whole flow is unit-testable:
`AudioRecording` (real `AVAudioRecorder` wrapper + fake), `TranscriptionService`
(`FakeTranscriptionService` now; real relay client later). `VoiceCaptureModel` (`@Observable`) is the
state machine. Transcript insertion is a pure function (verbatim + minimal boundary whitespace only,
RULES.md §2). The editor owns the insertion anchor (docs/04-voice-transcription.md §8).

**Tech Stack:** Swift 6.2, SwiftUI, AVFoundation, Swift Concurrency, Swift Testing.

**Out of scope (later slices):** transcription relay backend (Node/Fastify), real `gpt-transcribe`,
App Attest, rate limiting, language-quality benchmark corpus (Phases 9–11).

---

## Task 8a — Transcription service contract + fake

**Files:** `Core/Voice/TranscriptionService.swift` (protocol, `TranscriptionResult`,
`TranscriptionError`), `Core/Voice/FakeTranscriptionService.swift`; test `TranscriptionErrorTests.swift`.

- `TranscriptionResult { text: String; detectedLanguages: [String] }` (Sendable).
- `TranscriptionError`: microphonePermissionDenied, noSpeech, offline, requestTooLarge, rateLimited,
  serviceUnavailable, invalidResponse, cancelled (docs/05-architecture.md §21).
- `protocol TranscriptionService { func transcribe(audioURL:URL, requestID:UUID) async throws -> TranscriptionResult }`.
- `FakeTranscriptionService`: returns a deterministic Telugu+English sample after a short delay;
  configurable to throw a chosen error (for previews/tests). Never network.
- **Done:** compiles; error enum stable.

## Task 8b — Transcript insertion (pure, TDD)

**Files:** `Core/Voice/TranscriptInsertion.swift`; test `TranscriptInsertionTests.swift`.

- `insertTranscript(_ transcript:String, into body:String, at offset:Int) -> (text:String, cursor:Int)`.
- Rules (RULES.md §2): insert verbatim; add a single boundary space only when needed to avoid gluing
  words (previous char and first transcript char are both non-whitespace, and vice-versa); never
  rewrite/trim internal content; clamp offset into range; return new caret after inserted text.
- **Tests:** insert at start / middle / end; boundary space added when adjacent to a word; no double
  space when whitespace already present; Telugu content preserved byte-for-byte; empty transcript is a
  no-op; offset clamping.

## Task 8c — Audio recorder (protocol + AVFoundation)

**Files:** `Core/Voice/AudioRecording.swift` (protocol + `AudioLevel`),
`Core/Voice/AVAudioRecorderService.swift`; Info.plist mic key via `project.yml`.

- `protocol AudioRecording { func requestPermission() async -> Bool; func start() throws -> URL;
  func stop() -> URL?; func cancel(); var level: Float { get } }` (@MainActor).
- Real impl: `AVAudioApplication.requestRecordPermission`; `AVAudioRecorder` → temp `.m4a` (mono AAC)
  in a protected temp dir with a random name; metering on for level; delete temp on cancel.
- `INFOPLIST_KEY_NSMicrophoneUsageDescription` added.
- **Done:** compiles; permission + record/stop/cancel wired (device/simulator).

## Task 8d — Voice capture state machine (TDD)

**Files:** `Features/Voice/VoiceCaptureModel.swift`; test `VoiceCaptureModelTests.swift` (fake recorder + fake service).

- Phases: `idle`, `permissionDenied`, `recording(elapsed)`, `transcribing`, `failed(TranscriptionError)`.
- Flow: `begin()` → request permission (denied → permissionDenied) → start recorder → recording.
  `done()` → stop → transcribing → service.transcribe → emit transcript (via callback) → idle + temp
  cleanup. `cancel()` → stop + delete temp → idle. `retry()` re-runs transcription on the kept temp
  file; `discard()` deletes it → idle.
- Temp audio deleted on success / cancel / discard; kept only for explicit retry (RULES.md §3).
- **Tests:** permission denied path; happy path yields transcript + returns to idle; service error →
  failed; retry after failure → success; cancel/discard clean up; never emits text on failure.

## Task 8e — Recording UI

**Files:** `Features/Voice/RecordingPanel.swift`, `Features/Voice/WaveformView.swift`,
`Features/Voice/TranscribingIndicator.swift`, `Core/DesignSystem/VoiceButton.swift`.

- Dark system-material panel rising from the mic control (only dark surface over content); live
  waveform from the level meter, elapsed time, `Cancel` / stop / `Done` (matches reference screen 6).
- `Transcribing…` indicator after Done; error state shows concise copy + Retry / Discard.
- Haptics on start/stop; VoiceOver labels (Start/Stop recording).

## Task 8f — Wire mic into the editor

**Files:** modify `Features/Editor/EditorView.swift`, `Features/Editor/EditorModel.swift`.

- Add the mic control (bottom of the editor). Tapping captures the body selection/cursor, then
  presents the recording panel; body editing is disabled while the operation owns the anchor
  (docs/04-voice-transcription.md §8).
- On transcript, call `EditorModel.insertTranscript` (uses the pure func at the captured offset),
  autosave, delete temp audio, re-enable editing.
- **Done:** end-to-end with the fake service; transcript lands at the cursor as editable text.

## Task 8g — Verify

- Full test suite green. Simulator: show the recording panel and the transcribing state and the
  inserted Telugu+English transcript (Light + Dark). Confirm against reference screen 6 and RULES.md
  §2 (verbatim), §3 (temp audio deleted). Zero third-party dependencies.
