import SwiftUI

/// Orchestrates a single voice capture: permission → record → transcribe → emit transcript.
/// Injected recorder + service keep the flow fully testable. See docs/04-voice-transcription.md.
@MainActor @Observable
final class VoiceCaptureModel {
    /// The capture's state, as one explicit case at a time (`docs/10-voice-v2.md` §4).
    ///
    /// `recording` and `paused` are deliberately separate cases rather than `recording` plus an
    /// `isPaused` flag: the flag version is how a paused recorder ends up still counting time, and a
    /// capture that spends its five-minute cap on silence cuts somebody off mid-thought.
    ///
    ///     idle → requestingPermission → permissionDenied
    ///                  ↓
    ///          recording ⇄ paused → finishing → needsConsent → transcribing → idle / failed
    enum Phase: Equatable {
        case idle
        /// The microphone prompt is open. Its own state because the first capture on a fresh install
        /// waits here, and "nothing is happening yet" and "we are asking" are different things to draw.
        case requestingPermission
        case permissionDenied
        case recording
        /// Holding the microphone, keeping the file open, and **not** counting time.
        case paused
        /// The recorder is being closed and its file finalized, before anything is sent.
        ///
        /// A real step, not a label on the way past one (corrected 2026-08-30). Nothing leaves this
        /// state until the recorder has confirmed it stopped and the container it wrote has been
        /// measured — `AudioRecording.finish()` is what happens *in* here, and it is the only way
        /// out. Before that it was set and left within one synchronous call, which meant the upload
        /// began while the encoder might still have been writing.
        case finishing
        /// The recorder stopped without being asked, and what is on disk is real but incomplete.
        ///
        /// Its own state rather than a quiet trip through `finishing`, because the difference between
        /// this and Done is the difference between "here is your thought" and "here is as much of
        /// your thought as survived" — and `docs/10-voice-v2.md` §14 requires the app to *say what
        /// happened* rather than to present the second as the first. The audio is retained, so the
        /// two choices are the two that already exist for held audio: send it, or delete it.
        case stoppedUnexpectedly
        /// Recording finished, audio held, waiting on the one-time disclosure before it is sent.
        /// Only ever reached once per install, and only when the service actually uploads
        /// (`TranscriptionConsent`).
        case needsConsent
        case transcribing
        case failed(TranscriptionError)

        /// What VoiceOver is told when the capture moves from `old` to `new`, or `nil` when the move
        /// is not one a listener needs (`docs/10-voice-v2.md` §6).
        ///
        /// One definition for both presentations. The panel and Quick Voice are the same capture in
        /// two skins, and two lists of spoken strings would drift the first time either was edited.
        ///
        /// Deliberately quiet: a capture that narrates every internal step is one a screen-reader user
        /// cannot listen past, so `finishing` and the consent question say nothing — they are on their
        /// way somewhere, and the somewhere is what gets announced. A failure says nothing here either,
        /// because its copy is already on screen and saying it twice is noise rather than access.
        static func announcement(from old: Phase, to new: Phase) -> String? {
            switch (old, new) {
            // Resuming is not starting. One says a recording exists; the other says the one you
            // already made is running again.
            case (.paused, .recording): return "Recording resumed"
            case (_, .recording) where old != .recording: return "Recording started"
            case (.recording, .paused): return "Paused"
            case (_, .transcribing) where old != .transcribing: return "Transcribing"
            case (.transcribing, .idle): return "Transcript added"
            // The two facts a reader cannot get any other way, added with Phase 2B.
            //
            // A failure's *copy* is still not repeated out loud — it is on screen, and saying it
            // twice is noise rather than access. What is said is the durability: whether the words
            // just spoken still exist. Somebody who cannot see the screen has no other way to learn
            // that the recording survived the failure, and "Couldn't transcribe" alone reads as
            // *your words are gone* (`docs/10-voice-v2.md` §13).
            case (_, .failed(let error)) where old != new:
                return VoiceErrorCopy.announcement(for: error)
            // The one ending a listener could otherwise mistake for a completed recording: the
            // screen changed under them and nothing was said. Both halves matter — it stopped, and
            // what was said before it stopped is still here.
            case (_, .stoppedUnexpectedly) where old != new:
                return "\(VoiceErrorCopy.unexpectedStopMessage) \(VoiceErrorCopy.retainedNotice)"
            // And its counterpart: the recording is now actually gone, at the user's own request.
            case (.failed, .idle): return "Recording deleted"
            default: return nil
            }
        }
    }

    /// The one temporary recording this capture owns, and why it still exists.
    ///
    /// One value rather than a URL plus an `isRetained` flag, for the same reason `recording` and
    /// `paused` are separate cases: two fields that must agree are two fields that eventually do not,
    /// and the disagreement here is whether a user's words are still on disk. Every deletion in this
    /// type goes through the one place that clears it (`release`), so no future path can reach into
    /// the file system from a view and delete audio the capture is still offering back.
    private enum HeldAudio {
        /// Finished audio on its way through the flow — waiting on the disclosure, or being sent.
        case held(URL)
        /// Kept after a **retryable** failure, for an explicit Retry, until success, deletion, or the
        /// 24-hour lifetime ends it (`docs/10-voice-v2.md` §13).
        case retained(RetainedVoiceRecording)

        var url: URL {
            switch self {
            case .held(let url): return url
            case .retained(let recording): return recording.url
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var level: Float = 0

    private var recorder: AudioRecording
    private let service: TranscriptionService
    private let consent: TranscriptionConsentStoring
    private let allowance: VoiceAllowanceStoring
    private let onTranscript: (String) -> Void
    /// Wall-clock, injected, because the retry lifetime is measured in hours and no test may wait
    /// them out. Distinct from `clock` above, which measures recorded audio on a monotonic clock.
    private let now: @Sendable () -> Date
    /// What remembers a retained recording once this capture is gone — after Back, and after the
    /// process ends. Without it the file would still be on disk and nothing would know it was
    /// anybody's (`RetainedRecordingStoring`).
    private let retention: RetainedRecordingStoring
    /// Which surface this capture belongs to, carried only so the recovery copy can be honest about
    /// where a recovered transcript will land.
    private let origin: RetainedVoiceRecording.Origin

    private var audio: HeldAudio?
    private var work: Task<Void, Never>?
    /// The finalization in flight — closing the recorder and measuring what it wrote.
    ///
    /// Held so that abandoning a capture abandons this too. It is deliberately *not* the same task
    /// as `work`: finalizing is about the file, transcribing is about the network, and a cancel that
    /// conflated them would be a cancel that could interrupt the encoder.
    private var finishing: Task<Void, Never>?
    /// Which transcription attempt is the current one.
    ///
    /// `Task.cancel()` alone is not an answer here: a real upload that has already reached the relay
    /// comes back whether or not anybody is still listening, and cancellation is cooperative — a
    /// service that never checks it still returns, or throws. So each attempt carries a number, and a
    /// result whose number is stale is dropped before it can touch anything: no transcript into a note
    /// that has been left, no second note, and above all no deletion of a recording that is now being
    /// held for recovery (`docs/10-voice-v2.md` §13).
    private var attempt = 0
    /// Whether this capture has already been told the surface it belonged to is going away.
    ///
    /// Leaving is one event reported twice — the editor finalizes at the Back tap *and* on teardown —
    /// and the two calls must mean the same thing. Without this, the first would start the upload that
    /// `RULES.md` §2 requires to finish and insert, and the second would find it in flight and abandon
    /// it. The first call wins.
    private var hasLeft = false

    /// The audio this capture has actually recorded, summed across pauses — never wall-clock time.
    private var recorded = RecordedDuration()
    private let clock = ContinuousClock()

    /// Client-side mirror of the relay's duration limit. The relay is still the authority — this
    /// only spares the user from talking past a limit that would reject the upload anyway.
    private let maxRecordingDuration: Duration
    private var limitTask: Task<Void, Never>?

    init(recorder: AudioRecording,
         service: TranscriptionService,
         consent: TranscriptionConsentStoring? = nil,
         allowance: VoiceAllowanceStoring? = nil,
         maxRecordingDuration: Duration = VoiceLimits.maxRecordingDuration,
         now: @escaping @Sendable () -> Date = Date.init,
         retention: RetainedRecordingStoring = UserDefaultsRetainedRecording(),
         origin: RetainedVoiceRecording.Origin = .quickVoice,
         onTranscript: @escaping (String) -> Void) {
        self.now = now
        self.retention = retention
        self.origin = origin
        self.recorder = recorder
        self.service = service
        // A service that keeps the audio local has no transfer to disclose, so it is never gated.
        self.consent = consent ?? (service.sendsAudioOffDevice
            ? UserDefaultsTranscriptionConsent()
            : AlwaysGrantedTranscriptionConsent())
        // Likewise: audio that never reaches the relay never spends the relay's allowance.
        self.allowance = allowance ?? (service.sendsAudioOffDevice
            ? UserDefaultsVoiceAllowance()
            : AlwaysAvailableVoiceAllowance())
        self.maxRecordingDuration = maxRecordingDuration
        self.onTranscript = onTranscript
    }

    /// A capture that begins where a previous one ended: holding a recording that outlived the app.
    ///
    /// One-shot recovery, not an archive (`docs/10-voice-v2.md` §13, decided 2026-08-28). There is at
    /// most one of these, it is offered on one surface, and the only two things that can happen to it
    /// are the two things that could happen to it before the app closed: **Retry** and **Delete
    /// Recording**. Everything underneath is the same state machine — the same `retry()`, the same
    /// `settle`, the same deletion rules — because a recovered recording is not a different kind of
    /// recording, it is the same one after an interruption nobody chose.
    ///
    /// There is no recorder behind it: the microphone belonged to a process that has ended, and the
    /// only thing left to do to the file is send it or delete it.
    convenience init(recovering recording: RetainedVoiceRecording,
                     service: TranscriptionService,
                     allowance: VoiceAllowanceStoring? = nil,
                     now: @escaping @Sendable () -> Date = Date.init,
                     retention: RetainedRecordingStoring = UserDefaultsRetainedRecording(),
                     onTranscript: @escaping (String) -> Void) {
        self.init(recorder: RecoveredRecordingFile(),
                  service: service,
                  // The recording was already sent once, which cannot have happened before the
                  // disclosure was accepted. Asking again would be asking a second time.
                  consent: AlwaysGrantedTranscriptionConsent(),
                  allowance: allowance,
                  now: now,
                  retention: retention,
                  origin: recording.origin,
                  onTranscript: onTranscript)
        adopt(recording)
    }

    /// Take ownership of a recording that was retained before this capture existed.
    private func adopt(_ recording: RetainedVoiceRecording) {
        audio = .retained(recording)
    }

    /// How much audio this capture has recorded — what the timer shows, and what the cap is measured
    /// against. Frozen while paused, because a pause is not voice (`docs/10-voice-v2.md` §5).
    var elapsedRecording: Duration { recorded.elapsed(at: clock.now) }

    /// The recording being held back for an explicit Retry, or `nil` when there is nothing to retry.
    ///
    /// Read by the failure surfaces to decide whether they may promise the audio is still here. It is
    /// deliberately the *only* window onto held audio: there is no list, no second recording, and
    /// nothing to browse (`RULES.md` §7 excludes an audio archive).
    var retainedRecording: RetainedVoiceRecording? {
        if case .retained(let recording) = audio { return recording }
        return nil
    }

    /// Ask for permission and start recording.
    func begin() async {
        // Refuse before the microphone opens, not after the upload. The relay already told us voice
        // is spent for this month; recording anyway would take a thought we then cannot transcribe.
        if let until = allowance.unavailableUntil {
            phase = .failed(.monthlyLimitReached(resetsAt: until))
            return
        }
        phase = .requestingPermission
        guard await recorder.requestPermission() else { phase = .permissionDenied; return }
        do {
            // A call, Siri, or an audio route the recorder cannot continue on — all of them end the
            // capture the same way, and none of them may end it by deleting what was said
            // (docs/04-voice-transcription.md §7, docs/10-voice-v2.md §14).
            //
            // A recorder that stopped *on its own* is the one ending that does not go down that
            // path. The audio is kept exactly the same way; what differs is that the user is told,
            // because they were still speaking into a microphone that had already closed.
            recorder.onCaptureEnded = { [weak self] stop in
                switch stop {
                case .userFinished, .interrupted: self?.done()
                case .unexpected: self?.endUnexpectedly()
                }
            }
            audio = .held(try recorder.start())
            recorded.start(at: clock.now)
            phase = .recording
            startLimitTimer()
        } catch {
            phase = .failed(.serviceUnavailable)
        }
    }

    /// Hold the microphone without ending the capture.
    ///
    /// The clock stops with it. That is the whole point of pause being a state: the cap is spent on
    /// audio, so thinking for five minutes between two sentences costs nothing (`docs/10-voice-v2.md`
    /// §5). The file stays open — `resume()` continues the same container.
    func pause() {
        guard phase == .recording else { return }
        limitTask?.cancel()
        limitTask = nil
        recorded.pause(at: clock.now)
        recorder.pause()
        phase = .paused
    }

    /// Continue the capture, and give the cap back the time that is still owed to it.
    func resume() {
        guard phase == .paused else { return }
        recorded.resume(at: clock.now)
        recorder.resume()
        phase = .recording
        startLimitTimer()
    }

    /// Stop recording, then transcribe — pausing once for the disclosure if the recording is about
    /// to leave the device for the first time.
    func done() {
        // From either live state. Somebody who paused and then decided they were finished must not
        // have to resume in order to stop (`docs/10-voice-v2.md` §5 keeps **Done** in both).
        guard phase == .recording || phase == .paused else { return }
        stopCounting()
        phase = .finishing
        // Strongly captured on purpose. Back mid-recording finishes and transcribes (`RULES.md` §2),
        // and the editor drops this capture in the same breath — a weak capture here would let the
        // finalization evaporate along with it, which is the data loss the rule exists to prevent.
        finishing = Task {
            self.settleFinished(await self.recorder.finish(), ending: .userFinished)
        }
    }

    /// The recorder stopped and nobody asked it to.
    ///
    /// Everything about the audio is handled exactly as **Done** handles it — the file is finalized,
    /// measured, and kept. The one thing that is different is the ending it arrives at: the user is
    /// shown `stoppedUnexpectedly` and decides, rather than being handed a note that looks like the
    /// whole of what they said. Nothing here discards (`RULES.md` §2).
    private func endUnexpectedly() {
        guard phase == .recording || phase == .paused else { return }
        stopCounting()
        phase = .finishing
        finishing = Task {
            self.settleFinished(await self.recorder.finish(), ending: .unexpected)
        }
    }

    /// Stop the recorded-duration clock and the cap that reads it.
    ///
    /// Called the instant a capture actually terminates, however it terminated. The clock is
    /// arithmetic over `ContinuousClock` and knows nothing about the microphone, so a recorder that
    /// dies while this is still running produces a timer that goes on climbing over a dead input —
    /// which is precisely what the app used to draw.
    private func stopCounting() {
        limitTask?.cancel()
        limitTask = nil
        recorded.pause(at: clock.now)
    }

    /// What a finalized recording becomes, once it is finalized and measured.
    ///
    /// The one gate every capture passes through, so no ending can skip the measurement. A container
    /// with no usable duration is not audio: the relay measures the same way and refuses what it
    /// cannot measure, so this refuses it here rather than spending a round trip to be told.
    private func settleFinished(_ finished: FinishedRecording?, ending: RecordingStop) {
        // Nothing was ever opened, so there is nothing to finalize and nothing to keep. `.finishing`
        // is a step, and a step has to end even when the recorder had nothing to hand back.
        guard let finished else {
            release()
            phase = .failed(.noSpeech)
            return
        }
        VoiceDiagnostics.captureFinished(origin: origin,
                                         ending: ending,
                                         recorded: recorded.elapsed(at: clock.now),
                                         finished: finished)
        guard finished.isTranscribable else {
            release()                        // nothing was captured, so there is nothing to keep
            phase = .failed(.noSpeech)
            return
        }
        guard ending != .unexpected else {
            // Kept and handed back to the user with an explanation — never uploaded on the
            // assumption that a recording which ended by itself ended when they meant it to.
            //
            // Remembered across the process only once the disclosure has been accepted. A first
            // recording that has never been asked about may not be persisted for a later surface to
            // offer back: the recovery path treats a retained recording as already-disclosed,
            // because until now one could only exist after a *sent* upload. Held instead, so it
            // stays for this surface and this decision, and goes with it — the same rule
            // `finishOnLeave()` already applies to audio waiting on the disclosure (RULES.md §3).
            if consent.hasConsented { retain(finished.url) } else { audio = .held(finished.url) }
            phase = .stoppedUnexpectedly
            return
        }
        audio = .held(finished.url)
        // The audio stays on disk while the question is open; nothing is sent until it is answered.
        guard consent.hasConsented else { phase = .needsConsent; return }
        transcribe(finished.url)
    }

    /// **Transcribe** what survived an unexpected stop — the user's decision, never the app's.
    ///
    /// The same upload every other capture makes, from the same held audio, subject to the same
    /// disclosure. A recording that fails from here fails into the ordinary retained-recording
    /// flow, because from this point it is an ordinary recording.
    func transcribeCaptured() {
        guard phase == .stoppedUnexpectedly, let url = audio?.url else { return }
        guard consent.hasConsented else { phase = .needsConsent; return }
        transcribe(url)
    }

    /// The user accepted the disclosure: remember it and send the recording that is already waiting.
    func grantConsent() {
        guard phase == .needsConsent, let url = audio?.url else { return }
        consent.grant()
        transcribe(url)
    }

    /// Leaving the editor while a recording is running.
    ///
    /// Finishing, not cancelling. Backgrounding, a phone call, and the duration cap all already
    /// finish the capture and transcribe what was said; Back was the one exit that deleted it, which
    /// meant tapping it mid-sentence silently destroyed everything the user had spoken. The words are
    /// already said — the rule the rest of this type follows is that dropping them is the one outcome
    /// worse than a rejected upload.
    ///
    /// The single exception is a first recording whose disclosure has not been accepted. That audio
    /// cannot be sent, and it cannot be kept on disk with no UI left to ask (RULES.md §3), so it is
    /// the one case where leaving still discards.
    func finishOnLeave() {
        guard !hasLeft else { return }
        hasLeft = true
        if phase == .recording || phase == .paused {
            // The one case that still discards: a first recording whose disclosure has not been
            // accepted. That audio may not be sent and may not be kept.
            guard consent.hasConsented else { cancel(); return }
            done()
            return
        }
        // Left while the file was still being closed.
        //
        // The audio is already committed — the user stopped speaking and the recorder is shutting
        // down — so this is the mid-recording case one moment later, and it MUST finish and insert
        // exactly as that one does (`RULES.md` §2). Doing nothing is what allows that: the
        // finalization task holds this capture alive and carries it through to the transcript.
        // Falling through to `cancel()` here would delete a recording the user had finished making.
        if phase == .finishing { return }
        // Left while the recording was still being sent.
        //
        // The user has finished speaking and committed the audio; navigating away is not a decision
        // about it. The upload is abandoned rather than followed — a transcript arriving for an editor
        // that no longer exists has nowhere honest to land — and the recording is **claimed first**,
        // so that the order of events is: this audio is now retained, *then* that attempt stops
        // counting. Reversed, a result landing in between would still be believed.
        if phase == .transcribing, case .held(let url)? = audio {
            retain(url)
            abandonTranscription()
            // The phase is deliberately left as it is. Nothing is drawing it — the editor discards
            // this capture in the same breath — and the alternative, moving to `idle`, would announce
            // "Transcript added" to a VoiceOver user whose transcript never arrived.
            return
        }
        // **Back is navigation, not Delete Recording** (decided 2026-08-28). A recording kept after a
        // retryable failure outlives the screen it failed on: it stays on disk, stays remembered, and
        // comes back on one recovery surface. Deleting it here would be the app answering "I'm done
        // reading this note" with "and I threw away what you said", which is the exact silent loss
        // this phase exists to end.
        if retainedRecording != nil { return }
        cancel()
    }

    /// Stop listening to the transcription in flight, and make sure its answer cannot be believed if
    /// it arrives anyway. An explicit **Retry** is a new attempt, never a resumption of this one.
    private func abandonTranscription() {
        attempt += 1
        work?.cancel()
        work = nil
    }

    /// The app is going to the background mid-capture.
    ///
    /// Finishing, never discarding — **backgrounding MUST NEVER equal discard**
    /// (`docs/10-voice-v2.md` §14). Recording cannot continue once the app is suspended, and As Told
    /// deliberately does not ask iOS to let it: a continuous background listener is on the
    /// do-not-build list. So the microphone is closed and what was already said goes on to
    /// transcription, exactly as **Done** would have.
    ///
    /// From every other state this does nothing at all. A transcription in flight is left alone —
    /// its audio is deleted only by a confirmed success — and a retained recording stays retained,
    /// because a trip to the home screen is not a decision about it.
    ///
    /// Unlike `finishOnLeave()`, a capture waiting on the first-run disclosure is *not* discarded
    /// here: the surface that asked the question is still there when the app comes back.
    func finishOnBackground() {
        guard phase == .recording || phase == .paused else { return }
        done()
    }

    /// Abort the whole capture and delete the temporary audio.
    func cancel() {
        limitTask?.cancel()
        limitTask = nil
        finishing?.cancel()
        finishing = nil
        abandonTranscription()
        recorder.cancel()
        audio = nil
        retention.forget()
        recorded = RecordedDuration()
        phase = .idle
    }

    /// **Retry** — send the recording that is already on disk, again.
    ///
    /// A tap, and only a tap. Nothing here is ever reached by a timer, a reconnect, or a launch:
    /// As Told never uploads a retained recording without the user asking (`RULES.md` §2).
    ///
    /// It is one *affordance*, not one attempt. Failing again leaves the recording retained and this
    /// method available, until a success, a deletion, or the 24-hour lifetime ends it — a flaky
    /// connection is the normal reason a retry is needed, and the second attempt is the one most
    /// likely to work (`docs/10-voice-v2.md` §13).
    func retry() {
        guard let recording = retainedRecording else {
            // Nothing retained: the failure was one the same audio cannot get past, and its
            // recording was deleted when it happened.
            phase = .idle
            return
        }
        guard !recording.hasExpired(at: now()) else {
            // The lifetime ran out while the failure was on screen. The audio goes rather than being
            // uploaded past the window it was allowed to live in.
            deleteRecording()
            return
        }
        transcribe(recording.url)
    }

    /// **Delete Recording** — the only management affordance a retained recording has.
    ///
    /// There is no list to remove it from, nothing to play first, and nothing to export: the file is
    /// deleted immediately and the capture is over (`docs/10-voice-v2.md` §13, `RULES.md` §7).
    func deleteRecording() { discard() }

    /// Leave a finished capture without keeping anything: a declined disclosure, a closed permission
    /// notice, or the user dismissing a failure. Deletes the temporary file and resets.
    func discard() {
        limitTask?.cancel()
        limitTask = nil
        finishing?.cancel()
        finishing = nil
        abandonTranscription()
        release()
        recorded = RecordedDuration()
        phase = .idle
    }

    func refreshLevel() { level = recorder.level }

    /// Stop at the limit the way the user would: finish the recording and transcribe what was
    /// captured. The audio is never discarded — reaching the cap means the words are already said,
    /// and dropping them would be the one outcome worse than a rejected upload.
    /// Waits out whatever is **left** of the cap rather than the whole of it, so a capture that has
    /// already recorded four minutes and been paused resumes with one minute to go, not five. Pausing
    /// cancels this; resuming schedules it again against the new remainder. The wake-up re-asks
    /// `RecordedDuration` rather than trusting that it slept the right amount.
    private func startLimitTimer() {
        limitTask?.cancel()
        let remaining = recorded.remaining(of: maxRecordingDuration, at: clock.now)
        limitTask = Task { [maxRecordingDuration] in
            try? await Task.sleep(for: remaining)
            guard !Task.isCancelled, phase == .recording,
                  recorded.hasReached(maxRecordingDuration, at: clock.now) else { return }
            done()
        }
    }

    /// The one place a failed transcription decides whether the audio lives.
    ///
    /// `isRetryableVoiceFailure` is the whole test, asked once, of the error type itself — so the two
    /// surfaces cannot come to different conclusions about whether a user's words still exist. A
    /// retryable failure keeps the file and starts its 24 hours; everything else deletes it there and
    /// then, which is what keeps `RULES.md` §3's deletion contract from quietly widening into "audio
    /// stays around after failures".
    private func settle(_ error: TranscriptionError, for url: URL) {
        if error.isRetryableVoiceFailure {
            retain(url)
        } else {
            release()
        }
        phase = .failed(error)
    }

    /// Hold this recording back for an explicit Retry, and remember it beyond this capture.
    ///
    /// The 24 hours run from the *first* time it was kept, not from the last tap: restamping would let
    /// a recording live on the device indefinitely, one Retry at a time, which is the quiet
    /// accumulation the lifetime exists to prevent. Remembered as well as held, because this capture is
    /// often about to be dismissed by a Back tap or a terminated process, and the file has to outlive
    /// it (`RetainedRecordingStoring`).
    private func retain(_ url: URL) {
        let recording = RetainedVoiceRecording(url: url,
                                               retainedAt: retainedRecording?.retainedAt ?? now(),
                                               origin: origin)
        audio = .retained(recording)
        retention.remember(recording)
    }

    /// Delete whatever audio this capture holds, and stop holding it. Every deletion that is not the
    /// recorder aborting its own live file comes through here.
    private func release() {
        if let url = audio?.url { recorder.cleanup(url) }
        audio = nil
        retention.forget()
    }

    private func transcribe(_ url: URL) {
        attempt += 1
        let generation = attempt
        phase = .transcribing
        work = Task { [service, onTranscript, origin] in
            do {
                let result = try await service.transcribe(audioURL: url, requestID: UUID())
                guard isCurrentAttempt(generation) else { return }
                VoiceDiagnostics.transcriptReceived(origin: origin, characters: result.text.count)
                onTranscript(result.text)          // editor owns insertion
                release()                          // delete temp audio on success, immediately
                if let until = result.allowanceExhaustedUntil {
                    // This recording succeeded *and* spent the last of the month's allowance.
                    // Remembering that here is what makes the next microphone tap refuse before it
                    // opens, instead of taking a thought it cannot transcribe.
                    allowance.markUnavailable(until: until)
                } else {
                    allowance.clear()              // voice worked; any remembered refusal is stale
                }
                phase = .idle
            } catch is CancellationError {
                // left as-is; cancel()/discard() handle cleanup
            } catch let e as TranscriptionError {
                guard isCurrentAttempt(generation) else { return }
                if case .monthlyLimitReached(let resetsAt) = e {
                    // The one recording that crosses the ceiling is lost; remembering the date is
                    // what stops the one after it from being lost too.
                    allowance.markUnavailable(until: resetsAt)
                }
                settle(e, for: url)
            } catch {
                guard isCurrentAttempt(generation) else { return }
                settle(.serviceUnavailable, for: url)
            }
        }
    }

    /// Whether a result belongs to the attempt this capture is still waiting on.
    ///
    /// The failure branches need this at least as much as the success one does: a late *non-retryable*
    /// failure — `no_speech`, a length rejection — deletes its audio, and an abandoned attempt allowed
    /// to do that would delete the very recording the recovery surface is about to offer back.
    private func isCurrentAttempt(_ generation: Int) -> Bool {
        !Task.isCancelled && attempt == generation
    }
}
