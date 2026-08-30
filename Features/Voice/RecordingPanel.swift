import SwiftUI

/// Dark recording surface rising from the mic control: live waveform, elapsed time, and exactly two
/// controls — **Cancel** (stop, delete the temp audio, leave the note untouched) and **Done** (stop
/// and transcribe) — plus the transcribing and error/retry states. There is no separate "Stop":
/// this recorder has no review-before-transcribe step, so a third control would have been Done
/// under another name. The only dark surface over content (docs/03-design-system.md §4.8, §10).
/// Drives the injected VoiceCaptureModel.
struct RecordingPanel: View {
    @Bindable var model: VoiceCaptureModel
    var onClose: () -> Void

    @State private var levels: [Float] = Array(repeating: 0.05, count: 32)
    @State private var ticker: Timer?
    @State private var wasActive = false

    var body: some View {
        VStack(spacing: DSSpacing.s5) {
            switch model.phase {
            case .recording:
                capture(paused: false)
            case .paused:
                capture(paused: true)
            case .finishing:
                TranscribingIndicator(ground: .darkPanel)
            case .needsConsent:
                consentRequest
            case .transcribing:
                TranscribingIndicator(ground: .darkPanel)
            case .failed(let error):
                failure(error)
            case .permissionDenied:
                permissionDenied
            case .idle, .requestingPermission:
                // Nothing of ours to draw: before the first state, and while the system's own
                // microphone prompt is the thing on screen.
                EmptyView()
            }
        }
        .padding(DSSpacing.s5)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(0.001))   // keep the panel itself dark below
        .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: DSRadius.xl))
        .padding(.horizontal, DSSpacing.s4)
        .onAppear(perform: startTicker)
        .onDisappear { ticker?.invalidate() }
        // Subtle haptics at the state changes the user is waiting on (docs/02-features.md, Voice).
        .sensoryFeedback(trigger: model.phase) { Self.haptic(from: $0, to: $1) }
        .onChange(of: model.phase) { old, new in
            // Said out loud as well as drawn. A reader who cannot see the word or the glyph has no
            // other way to tell a paused capture from a running one (§6, RULES.md §4).
            if let said = VoiceCaptureModel.Phase.announcement(from: old, to: new) {
                UIAccessibility.post(notification: .announcement, argument: said)
            }
            switch new {
            case .requestingPermission, .recording, .paused, .finishing,
                 .needsConsent, .transcribing, .failed, .permissionDenied:
                wasActive = true
            case .idle:
                if wasActive { onClose() }   // capture completed → dismiss
            }
        }
    }

    // MARK: States

    /// One surface, two states. A pause is not a different screen — it is the same capture, not
    /// counting (`docs/10-voice-v2.md` §5). The state is said in a **word** as well as in the control's
    /// glyph, because §6 forbids a control that communicates its state through colour or shape alone.
    private func capture(paused: Bool) -> some View {
        VStack(spacing: DSSpacing.s4) {
            WaveformView(levels: levels)
                .frame(height: 48)
                // Decorative — it answers "is this hearing me?" and nothing a reader needs (§6).
                .accessibilityHidden(true)
            Text(timeString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .monospacedDigit()
                // Announced at state changes, never once a second (§6).
                .accessibilityHidden(true)
            Text(paused ? "Paused" : "Listening")
                .font(.ds.caption)
                .foregroundStyle(.white.opacity(0.8))
            ZStack {
                // Done is the primary target, centred under the waveform.
                VStack(spacing: DSSpacing.s2) {
                    Button {
                        stop(); model.done()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundStyle(.black)
                            .frame(width: 56, height: 56)
                            .background(.white, in: Circle())
                    }
                    .accessibilityLabel("Done")
                    .accessibilityHint("Stops recording and adds the transcript to this note")

                    Text("Done")
                        .font(.ds.caption)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }

                HStack {
                    Button("Cancel") { stop(); model.cancel(); onClose() }
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint("Discards this recording and leaves the note unchanged")
                    Spacer()
                    Button(paused ? "Resume" : "Pause") {
                        if paused { model.resume() } else { model.pause() }
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint(paused
                        ? "Continues this recording where it stopped"
                        : "Holds the recording without ending it")
                }
            }
        }
    }

    /// Shown once per install, after Done and before the first upload (`TranscriptionConsent`).
    /// Deliberately short: name where the recording goes, say what is *not* sent, two choices.
    /// The recording is already captured and stays on disk until this is answered.
    private var consentRequest: some View {
        VStack(spacing: DSSpacing.s4) {
            Text("Voice transcription")
                .font(.ds.noteTitle)
                .foregroundStyle(.white)

            Text("To turn your recording into text, As Told sends it to OpenAI. Nothing else from your note is sent.")
                .font(.ds.preview)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            HStack(spacing: DSSpacing.s6) {
                Button("Cancel") { model.discard(); onClose() }
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityHint("Deletes this recording without sending it")
                Button("Continue") { model.grantConsent() }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .accessibilityHint("Sends this recording to be transcribed, and doesn't ask again")
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The failure, and — when the recording survived it — the two controls that decide what happens
    /// to the audio. Same substance as Quick Voice's, in this panel's clothes: one retained recording,
    /// one **Retry**, one **Delete Recording** (`docs/10-voice-v2.md` §13).
    ///
    /// The note underneath is untouched throughout. A failed capture never writes to it, and a Retry
    /// that succeeds inserts through the same ordinary path the first attempt would have used — one
    /// insertion, one undo step.
    private func failure(_ error: TranscriptionError) -> some View {
        let retained = model.retainedRecording != nil
        return VStack(spacing: DSSpacing.s4) {
            if let title = Self.title(for: error) {
                Text(title)
                    .font(.ds.preview)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            Text(message(for: error))
                .font(.ds.preview)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if retained {
                Text(VoiceErrorCopy.retainedNotice)
                    .font(.ds.preview)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: DSSpacing.s6) {
                if retained {
                    Button(VoiceErrorCopy.deleteRecordingLabel) { model.deleteRecording(); onClose() }
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(minHeight: 44)
                        .accessibilityHint("Deletes this recording from this iPhone and leaves the note unchanged")
                    Button(VoiceErrorCopy.retryLabel) { model.retry() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(minHeight: 44)
                        .accessibilityHint("Sends this recording to be transcribed again")
                } else if error == .noSpeech {
                    // Nothing was heard, so nothing was kept: **Try Again** opens the microphone
                    // rather than re-sending silence.
                    Button("Cancel") { model.discard(); onClose() }
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(minHeight: 44)
                    Button(VoiceErrorCopy.recordAgainLabel) { Task { await model.begin() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(minHeight: 44)
                        .accessibilityHint("Starts a new recording")
                } else {
                    // Nothing to retry — the same upload would be refused again — and nothing to
                    // upsell, because there is no Pro tier to sell (RULES.md §1).
                    Button("OK") { model.discard(); onClose() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(minHeight: 44)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var permissionDenied: some View {
        VStack(spacing: DSSpacing.s4) {
            Text("Microphone access is off.")
                .font(.ds.preview).foregroundStyle(.white)
            HStack(spacing: DSSpacing.s6) {
                Button("Close") { model.discard(); onClose() }
                    .foregroundStyle(.white.opacity(0.8))
                Button("Open Settings") {
                    #if canImport(UIKit)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    #endif
                }
                .fontWeight(.semibold).foregroundStyle(.white)
            }
        }
    }

    // MARK: Helpers

    /// One haptic per meaningful capture transition; silence for everything else.
    private static func haptic(from old: VoiceCaptureModel.Phase,
                               to new: VoiceCaptureModel.Phase) -> SensoryFeedback? {
        switch (old, new) {
        // Pause and resume are marked, and marked *quietly* (§6) — and they are matched before the
        // start/stop rules below, so resuming does not fire the same haptic as beginning a recording.
        case (.recording, .paused), (.paused, .recording): return .selection
        case (_, .recording): return .start
        // Recording has stopped in every case; the disclosure just sits between stop and send.
        case (.finishing, .transcribing), (.finishing, .needsConsent): return .stop
        case (.transcribing, .idle): return .success
        case (_, .failed), (_, .permissionDenied): return .error
        default: return nil
        }
    }

    /// The **recorded** time, read from the capture rather than counted here. A second counter beside
    /// the model's own is how a paused timer keeps ticking (`docs/10-voice-v2.md` §5).
    private var timeString: String {
        let seconds = Int(model.elapsedRecording.components.seconds)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // Failure copy is shared with Home's Quick Voice capture, which is the same capture in a
    // different presentation — see `VoiceErrorCopy`. These forward rather than restate.
    private func message(for error: TranscriptionError) -> String {
        VoiceErrorCopy.message(for: error)
    }

    static func title(for error: TranscriptionError) -> String? {
        VoiceErrorCopy.title(for: error)
    }

    static func allowanceMessage(resetsAt: Date?) -> String {
        VoiceErrorCopy.allowanceMessage(resetsAt: resetsAt)
    }

    static func lengthLimitMessage(maxSeconds: Int) -> String {
        VoiceErrorCopy.lengthLimitMessage(maxSeconds: maxSeconds)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard model.phase == .recording else { return }
                model.refreshLevel()
                levels.removeFirst()
                levels.append(max(0.05, model.level))
            }
        }
    }

    private func stop() { ticker?.invalidate() }
}
