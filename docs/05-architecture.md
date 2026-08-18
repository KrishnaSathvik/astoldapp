# Architecture

## 1. Architecture goals

The architecture must optimize for:

1. fast native UI
2. local-first note ownership
3. simple mental model
4. reliable autosave
5. safe temporary audio handling
6. secure server-side transcription credentials
7. testability without turning the app into enterprise boilerplate

---

# 2. System context

```text
┌───────────────────────────────────────┐
│              iPhone App               │
│                                       │
│ SwiftUI                               │
│ SwiftData                             │
│ LocalAuthentication                   │
│ AVFoundation                          │
│ URLSession                            │
│ DeviceCheck / App Attest              │
└───────────────┬───────────────────────┘
                │
                │ HTTPS
                │ audio only for transcription
                v
┌───────────────────────────────────────┐
│       Transcription Relay API         │
│                                       │
│ Node.js + TypeScript                  │
│ request validation                    │
│ App Attest verification               │
│ rate limiting                         │
│ OpenAI API call                       │
│ NO note database                      │
└───────────────┬───────────────────────┘
                │
                v
┌───────────────────────────────────────┐
│        OpenAI Transcription API       │
│            gpt-transcribe             │
└───────────────────────────────────────┘
```

---

# 3. Client architecture style

Use a **feature-oriented native architecture**, not strict multi-layer Clean Architecture everywhere.

Recommended:

- SwiftUI Views
- `@Observable` feature models/controllers when state is non-trivial
- protocol-backed services where mocking matters
- SwiftData behind a small `NoteStore`
- environment-based dependency injection
- Swift Concurrency (`async/await`, actors where required)

Avoid:

- one giant `AppViewModel`
- massive singleton state
- dozens of use-case classes for trivial reads/writes
- importing backend DTO concerns into UI

---

# 4. Client modules

## App

Responsibilities:

- app startup
- dependency construction
- SwiftData model container
- scene phase
- first-launch routing
- privacy cover
- app lock routing

## Welcome

- first-run presentation
- mark onboarding complete

## Home

- fetch recent notes
- date grouping
- lazy pagination
- swipe delete
- calendar launch
- search activation
- new note route

## Editor

- note title/body binding
- selection anchor
- **focus state** — two-way with the `UITextView` body, so the editor always knows whether a caret
  is active. Drives three things: whether the keyboard opens on arrival (new note yes, existing note
  no), whether the keyboard-dismissing `Done` is offered, and whether a transcript inserts at the
  caret or appends to the end.
- autosave scheduling
- empty draft cleanup
- mic entry

## Voice

- permission state
- AVFoundation recording
- temporary audio
- recording timer/level
- transcription request
- insertion result
- retry/discard

## Search

- search query
- local text matching
- result list

## Calendar

- month state
- note-day presence
- selected day

## Settings

- Face ID toggle
- about/privacy/version

## AppLock

- LocalAuthentication
- foreground/background lock policy
- privacy cover state

## Core/DesignSystem

- semantic colors
- typography roles
- spacing
- components
- haptics

## Core/Persistence

- `NoteStore`
- SwiftData queries/mutations
- pagination
- soft-delete cleanup

## Core/Networking

- API client
- request IDs
- errors
- retry policy

## Core/Security

- App Attest client
- app lock service
- secure temporary file handling

---

# 5. Data model

## Note

Recommended SwiftData model:

```swift
@Model
final class Note {
    @Attribute(.unique) var id: UUID

    var title: String?
    var body: String

    var createdAt: Date
    var updatedAt: Date

    // Non-nil while in short undo/cleanup state.
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String? = nil,
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
```

### Rules

- `title` normalized: whitespace-only becomes nil.
- `body` remains raw user content.
- timeline sorting uses `createdAt`, not `updatedAt`.
- date grouping derives from `createdAt` using current/local calendar rules.
- no `voiceNote` type.
- no transcript provenance required in V1.
- no audio URL after successful transcription.

---

# 6. App settings

Use lightweight local settings for:

- `hasCompletedWelcome`
- `appLockEnabled`
- optional lock grace policy if introduced later

Use `@AppStorage` / UserDefaults for non-sensitive preferences.

Do not store secrets there.

---

# 7. Persistence layer

## Technology

SwiftData.

## NoteStore contract

A small protocol makes feature code testable:

```swift
protocol NoteStore {
    func createDraft() throws -> Note
    func save(_ note: Note) throws
    func delete(_ note: Note) throws
    func undoDelete(id: UUID) throws

    func recent(limit: Int, before: Date?) throws -> [Note]
    func notes(on day: Date) throws -> [Note]
    func noteDays(in month: Date) throws -> Set<Date>
    func search(_ query: String, limit: Int) throws -> [Note]
}
```

The exact implementation can use `ModelContext` and fetch descriptors.

Do not over-abstract SwiftData fields away from all UI if direct binding provides a better native editing experience.

---

# 8. Pagination / continuous Home

User experience:

- continuous

Implementation:

- cursor/date-based batches

Recommended key:

`createdAt + id` stable ordering.

Example:

1. latest 40 non-deleted notes
2. user nears bottom
3. fetch 40 with `createdAt < oldestLoadedDate`
4. merge
5. preserve scroll position

If multiple notes share the same timestamp granularity, use UUID/order tie-break handling.

Do not use page numbers because inserts/deletes can make offset pagination unstable.

---

# 9. Date grouping

Always use `Calendar` semantics, not manual 24-hour math.

Bad:

```text
createdAt > now - 86400
```

Good:

- `Calendar.current.startOfDay(for:)`
- localized Today/Yesterday checks
- explicit date interval for selected day

This avoids DST bugs.

---

# 10. Search architecture

## V1

Local lexical search.

Fields:

- normalized title
- body

For the first implementation, use SwiftData-supported predicates/fetching where practical.

If performance becomes poor with realistic data, migrate the search implementation behind `NoteStore` to a SQLite FTS index without changing feature UI.

Do not introduce embeddings for V1.

### Performance test

Generate:

- 100 notes
- 1,000 notes
- 10,000 notes

Measure:

- query latency
- typing/search responsiveness
- memory

Architecture intentionally allows a search-engine swap later.

---

# 11. Autosave architecture

Editor state has a save coordinator.

### Events

- title changed
- body changed
- voice inserted

### Strategy

- update bound model
- schedule debounced save
- cancel previous pending debounce
- flush on navigation
- flush on scene inactive/background

Pseudo-flow:

```text
text change
   ↓
mark dirty
   ↓
debounce 400ms
   ↓
save context
```

### Empty draft cleanup

On exit:

```text
if title.trimmed.isEmpty && body.trimmed.isEmpty {
    delete draft
}
```

Do not clean user spacing inside non-empty body.

---

# 12. Delete / Undo architecture

Recommended short-lived soft delete:

```text
deletedAt = now
```

Normal Home/search fetches filter `deletedAt == nil`.

Undo:

```text
deletedAt = nil
```

Cleanup:

- after Undo window
- and/or on next launch for expired deleted records

This avoids relying solely on a transient UI UndoManager for persistence safety.

---

# 13. Voice architecture

## AudioRecorderService

Responsibilities:

- permission
- session setup (`.record` category — the app never plays audio back)
- record
- level meter
- stop
- cancel
- temp URL
- cleanup
- **interruption callback** — a call or Siri stops the recorder; the capture model finishes with the
  audio already on disk instead of discarding what was said. Route changes (AirPods) are not
  interruptions; recording continues on the new input.
- **launch sweep** — `purgeAbandonedRecordings()` deletes `rec-*.m4a` orphaned by a crash or
  force-quit (RULES.md §3).

## TranscriptionService

Protocol:

```swift
protocol TranscriptionService {
    func transcribe(
        audioURL: URL,
        requestID: UUID
    ) async throws -> TranscriptionResult
}
```

Result:

```swift
struct TranscriptionResult: Sendable {
    let text: String
    let detectedLanguages: [String]
}
```

Detected language metadata is useful for QA/debugging but does not need to be persisted with the note.

## Editor insertion

Editor owns:

- insertion anchor — the caret when the body had focus, otherwise the end of the body
- operation state
- returned text
- the caret position after insertion

The transcription service never mutates the note directly. Reading state survives a transcript: the
keyboard only returns if the user was already editing when recording started.

---

# 14. Transcription backend

## Endpoint

Conceptual:

```http
POST /v1/transcriptions
Content-Type: multipart/form-data
```

Fields:

- `audio`
- `request_id`
- optional supported language hint configuration controlled by server/app version

Headers:

- App Attest assertion/challenge material
- app version
- request correlation ID

### Response

```json
{
  "requestId": "uuid",
  "text": "transcribed text",
  "languages": ["te", "en"]
}
```

Do not return model internals the client does not need.

---

# 15. Backend request flow

```text
request
  ↓
size/content-type validation
  ↓
App Attest verification
  ↓
rate limit
  ↓
temporary in-memory/file handling
  ↓
OpenAI transcription
  ↓
validate response
  ↓
return transcript
  ↓
destroy temporary audio reference
```

No user account and no note persistence.

---

# 16. App Attest

Purpose:

Make it harder for third parties to copy the public endpoint and consume paid transcription using scripts or modified clients.

### Production idea

1. app creates App Attest key
2. server challenges app
3. app attests key
4. server associates an anonymous server record/cache entry with key ID
5. subsequent transcription requests carry assertions
6. server verifies assertion/request hash

### Registry durability

The record in step 4 holds the key ID, its public key, and the assertion counter — no note content
and no user identity. It MUST outlive the process whenever attestation is enforced: the counter is
the replay defence, and comparing against a counter that resets on restart rejects nothing. It also
spares every install a forced re-registration on each deploy.

`transcription-service/src/security/attestedKeyStore.ts` holds both implementations behind one
interface — SQLite on a mounted volume (`node:sqlite`, no added dependency) for enforced deploys,
in-memory for dev and tests. `APP_ATTEST_DB_PATH` is required when `APP_ATTEST_REQUIRED=true`.

Challenges stay in-process on purpose: they expire in 5 minutes and a lost one costs a single
retried request, so they do not justify the durability cost. That, plus the in-memory rate limiter,
is why the relay stays single-instance until there is a shared store.

Development builds need a controlled bypass/development environment.

Do not make a generic `X-Debug-Bypass` work in production. A production relay with attestation off
must fail to start rather than serve — see `APP_ATTEST_ALLOW_UNPROTECTED` in `config.ts`.

---

# 17. Rate limiting

Because there is no account:

Primary identifier:

- validated App Attest key ID / anonymous installation identity

Secondary:

- IP anomaly limit

Optional storage:

- Redis

Never use note content for abuse identity.

---

# 18. App lock architecture

Use LocalAuthentication.

Recommended product behavior:

- user explicitly enables lock
- authenticate at enable time
- when scene is no longer active, show privacy cover
- mark content as requiring authentication
- on active, evaluate device-owner authentication
- on cold launch with the lock on, start in the locked phase and prompt from `.task` — there is no
  prior cover transition to escalate from, and `onChange(of: scenePhase)` does not fire for the
  scene's initial active value
- only reveal content after success

Use device authentication with biometric-first system behavior and passcode fallback where appropriate.

### Important

App lock is an access gate, not a claim that the app database is independently end-to-end encrypted.

Do not market beyond the actual threat model.

---

# 19. Temporary audio security

Temporary audio should:

- live only in app-controlled temporary/application support location
- use iOS file protection where applicable
- have randomized names
- never go to Photos
- never go to shared Documents
- be deleted on Cancel
- be deleted on successful transcription
- be deleted on Discard
- be cleaned on launch if abandoned beyond allowed retry lifetime

---

# 20. Offline behavior

Works offline:

- Home
- create
- type
- edit
- delete
- Undo
- search
- calendar
- settings
- app lock

Does not work fully offline:

- speech transcription

When offline after recording:

- retain protected temp audio for explicit retry
- tell user connection is required
- never silently upload later

---

# 21. Error model

Define domain errors.

```swift
enum TranscriptionError: Error {
    case microphonePermissionDenied
    case noSpeech
    case offline
    case requestTooLarge
    case rateLimited
    case serviceUnavailable
    case invalidResponse
    case cancelled
}
```

UI maps domain errors to concise human copy.

Do not display raw backend/OpenAI errors to users.

---

# 22. Observability

Client:

- MetricKit
- OSLog categories
- no note/transcript payloads in logs

Backend:

Log metadata only:

- request ID
- route
- status
- latency
- model
- byte size
- coarse error code

Never log:

- audio
- transcript
- title
- body

---

# 23. Testing architecture

## Unit

- date grouping
- title normalization
- empty draft cleanup
- search matching
- pagination cursor
- delete/undo
- transcript insertion spacing
- lock state machine

## SwiftData integration

- create/relaunch
- edit
- pagination
- soft-delete cleanup
- month queries

## UI

- Welcome → Home
- New note
- Back/autosave
- Search
- Calendar
- swipe delete
- Face ID mocked state
- mic permission mocked state

## Backend

- invalid MIME
- oversized request
- invalid attestation
- rate limit
- OpenAI timeout
- empty transcript
- success
- content not logged

## Voice quality

Separate benchmark suite, not just unit tests.

---

# 24. Migration strategy

SwiftData schema must be versioned deliberately before public release.

Even a simple app eventually needs migrations.

Do not assume V1's model is permanent.

Possible future fields:

- pinnedAt
- audio metadata
- sync metadata

Do not add them now merely because they may exist later.

---

# 25. Architecture non-goals

Do not build:

- server-side note database
- event-sourced note history
- microservices
- Kafka
- GraphQL
- vector DB
- auth platform
- realtime collaboration stack
- sync engine before sync is a product requirement

The backend exists because paid transcription credentials cannot safely live in the client, not because the product needs a traditional cloud backend.
