import SwiftUI

/// Home's Quick Voice capture: tap the mic, speak, get an ordinary note.
///
/// **A second presentation of the existing voice engine, never a second voice stack**
/// (`docs/10-voice-v2.md` §1). It drives the same `VoiceCaptureModel` the editor drives, through the
/// same `AVAudioRecorderService`, the same `TranscriptionConfig.makeService()`, the same one-time
/// disclosure, and the same failure copy (`VoiceErrorCopy`). Nothing about recording, uploading,
/// consent, permission, the duration cap, or the monthly allowance is reimplemented here — this file
/// owns layout and nothing else.
///
/// It differs from `RecordingPanel` in exactly one way, and deliberately: there is no note underneath
/// to keep visible, so the capture owns the screen instead of floating over a note.
///
/// Cancel, elapsed time, the capture's state in a word, audio activity, Pause / Resume, and Done —
/// the surface `docs/10-voice-v2.md` §3 describes and nothing else. Pause and Resume arrived with the
/// shared state machine in Phase 2A; until then they were deliberately absent rather than drawn as
/// disabled placeholders for unbuilt behavior (§23).
struct QuickVoiceCaptureView: View {
    /// Called with a successful, non-empty transcript. The caller owns note creation — this view
    /// never touches SwiftData, which is what keeps the transient rule in one testable place
    /// (`QuickVoiceNote`).
    var onCaptured: (String) -> Void
    var onClose: () -> Void

    /// Injectable so tests and previews can drive the flow without a microphone or a network.
    var makeModel: (@escaping (String) -> Void) -> VoiceCaptureModel = { onTranscript in
        #if DEBUG
        if let stand_in = DebugVoice.captureModel(onTranscript: onTranscript) { return stand_in }
        #endif
        return VoiceCaptureModel(recorder: AVAudioRecorderService(),
                                 service: TranscriptionConfig.makeService(),
                                 onTranscript: onTranscript)
    }

    @Environment(\.scenePhase) private var scenePhase

    @State private var model: VoiceCaptureModel?
    @State private var levels: [Float] = Array(repeating: 0.05, count: 32)
    @State private var ticker: Timer?
    /// Whether this capture ever got going, so the `idle` it starts in is not read as the `idle` it
    /// ends in. Same guard the in-note panel uses.
    @State private var wasActive = false

    var body: some View {
        ZStack {
            Color.ds.canvas.ignoresSafeArea()
            if let model {
                content(model)
                    .padding(DSSpacing.s6)
            }
        }
        .task { await start() }
        .onDisappear { ticker?.invalidate() }
        // The same small set of transitions the in-note panel marks, and no others.
        .sensoryFeedback(trigger: model?.phase) { Self.haptic(from: $0, to: $1) }
        // Said out loud as well as drawn — the same announcements the in-note panel makes, from the
        // same definition (§6).
        .onChange(of: model?.phase) { old, new in
            if let old, let new,
               let said = VoiceCaptureModel.Phase.announcement(from: old, to: new) {
                UIAccessibility.post(notification: .announcement, argument: said)
            }
            switch new {
            case .idle?:
                // The capture is over — a transcript landed, or the recording it was holding was
                // deleted. Success already closes through `onCaptured`; this is what stops the other
                // endings leaving an empty screen behind.
                if wasActive { onClose() }
            case .none:
                break
            default:
                wasActive = true
            }
        }
        // Recording cannot continue once the app is suspended, so the capture finishes with the audio
        // already on disk rather than being stranded live. Never a discard (`docs/10-voice-v2.md` §14).
        //
        // `.background` rather than `.inactive`: the microphone prompt, Control Centre, and a
        // notification pulled halfway down all resign active, and none of them is somebody leaving.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model?.finishOnBackground() }
        }
    }

    // MARK: States

    @ViewBuilder
    private func content(_ model: VoiceCaptureModel) -> some View {
        switch model.phase {
        case .recording:
            capture(model, paused: false)
        case .paused:
            capture(model, paused: true)
        case .finishing:
            TranscribingIndicator()
        case .needsConsent:
            consentRequest(model)
        case .transcribing:
            TranscribingIndicator()
        case .failed(let error):
            failure(error, model)
        case .permissionDenied:
            permissionDenied(model)
        case .idle, .requestingPermission:
            // Reached between construction and `begin()`, while the system's own microphone prompt is
            // the thing on screen, and again after a capture completes while the sheet is on its way
            // out. Nothing of ours to draw in any of them.
            Color.clear
        }
    }

    /// One surface, two states — the capture, and the capture not counting (`docs/10-voice-v2.md` §5).
    private func capture(_ model: VoiceCaptureModel, paused: Bool) -> some View {
        VStack {
            HStack {
                Button("Cancel") { finish(); model.cancel(); onClose() }
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Discards this recording without creating a note")
                Spacer()
            }

            Spacer()

            VStack(spacing: DSSpacing.s5) {
                Text(timeString)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(Color.ds.textSecondary)
                    .monospacedDigit()
                    // Announced when it changes state, not once a second (docs/10-voice-v2.md §6).
                    .accessibilityHidden(true)

                // The word, not only the glyph on the button: §6 forbids a control whose state is
                // carried by colour or shape alone.
                Text(paused ? "Paused" : "Listening")
                    .font(.ds.noteTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                WaveformView(levels: levels, tint: Color.ds.textPrimary)
                    .frame(height: 40)
                    .padding(.horizontal, DSSpacing.s6)
                    // Decorative: it answers "is this hearing me?" and carries nothing a VoiceOver
                    // user needs, which the spoken state above already gives them.
                    .accessibilityHidden(true)
            }

            Spacer()

            // "Bottom: **Pause** and **Done**" (`docs/10-voice-v2.md` §3).
            HStack(spacing: DSSpacing.s8) {
                Button(paused ? "Resume" : "Pause") {
                    if paused { model.resume() } else { model.pause() }
                }
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textPrimary)
                .frame(minWidth: 64, minHeight: 44)
                .accessibilityHint(paused
                    ? "Continues this recording where it stopped"
                    : "Holds the recording without ending it")

                Button { finish(); model.done() } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(Color.ds.canvas)
                        .frame(width: 64, height: 64)
                        .background(Color.ds.textPrimary, in: Circle())
                }
                .accessibilityLabel("Done")
                .accessibilityHint("Stops recording and turns it into a note")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(paused ? "Paused" : "Recording")
    }

    /// Shown once per install, after Done and before the first upload. Identical in substance to the
    /// editor's — same decision, same consequences, same store (`TranscriptionConsent`).
    private func consentRequest(_ model: VoiceCaptureModel) -> some View {
        VStack(spacing: DSSpacing.s4) {
            Text("Voice transcription")
                .font(.ds.noteTitle)
                .foregroundStyle(Color.ds.textPrimary)
            Text("To turn your recording into text, As Told sends it to OpenAI. Nothing else from your notes is sent.")
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: DSSpacing.s6) {
                Button("Cancel") { model.discard(); onClose() }
                    .foregroundStyle(Color.ds.textSecondary)
                    .accessibilityHint("Deletes this recording without sending it")
                Button("Continue") { model.grantConsent() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.ds.textPrimary)
                    .accessibilityHint("Sends this recording to be transcribed, and doesn't ask again")
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// A failure, and — when the recording survived it — the two controls that decide what happens to
    /// the audio (`docs/10-voice-v2.md` §13).
    ///
    /// The failure stays here, on the capture surface. A Quick Voice capture has no note to return to,
    /// so bouncing back to Home would leave the user holding a recording they could no longer see.
    ///
    /// Which controls appear is read from the capture, never guessed from the error: if the recording
    /// was kept, the screen says so and offers **Retry** / **Delete Recording**; if it was not, the
    /// screen makes no promise about audio that has already been deleted.
    private func failure(_ error: TranscriptionError, _ model: VoiceCaptureModel) -> some View {
        let retained = model.retainedRecording != nil
        return VStack(spacing: DSSpacing.s4) {
            if let title = VoiceErrorCopy.title(for: error) {
                Text(title)
                    .font(.ds.preview)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.ds.textPrimary)
                    .multilineTextAlignment(.center)
            }
            Text(VoiceErrorCopy.message(for: error))
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textPrimary)
                .multilineTextAlignment(.center)
            if retained {
                Text(VoiceErrorCopy.retainedNotice)
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: DSSpacing.s6) {
                if retained {
                    Button(VoiceErrorCopy.deleteRecordingLabel) { model.deleteRecording(); onClose() }
                        .foregroundStyle(Color.ds.textSecondary)
                        .frame(minHeight: 44)
                        .accessibilityHint("Deletes this recording from this iPhone")
                    Button(VoiceErrorCopy.retryLabel) { model.retry() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ds.textPrimary)
                        .frame(minHeight: 44)
                        .accessibilityHint("Sends this recording to be transcribed again")
                } else if error == .noSpeech {
                    // There is no audio to send again, so **Try Again** means the microphone, not the
                    // upload (`docs/10-voice-v2.md` §14).
                    Button("Cancel") { model.discard(); onClose() }
                        .foregroundStyle(Color.ds.textSecondary)
                        .frame(minHeight: 44)
                    Button(VoiceErrorCopy.recordAgainLabel) { Task { await model.begin() } }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ds.textPrimary)
                        .frame(minHeight: 44)
                        .accessibilityHint("Starts a new recording")
                } else {
                    // The monthly ceiling, a recording over the limit, an upload too large: sending the
                    // same audio again cannot succeed, so there is nothing to offer — and nothing to
                    // upsell either (RULES.md §1).
                    Button("OK") { model.discard(); onClose() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ds.textPrimary)
                        .frame(minHeight: 44)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func permissionDenied(_ model: VoiceCaptureModel) -> some View {
        VStack(spacing: DSSpacing.s4) {
            Text("Microphone access is off.")
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textPrimary)
            HStack(spacing: DSSpacing.s6) {
                Button("Close") { model.discard(); onClose() }
                    .foregroundStyle(Color.ds.textSecondary)
                Button("Open Settings") {
                    #if canImport(UIKit)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    #endif
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color.ds.textPrimary)
            }
        }
    }

    // MARK: Flow

    /// Permission, then recording, immediately — no editor, no note, no keyboard on the way in.
    private func start() async {
        guard model == nil else { return }
        let capture = makeModel { text in
            onCaptured(text)
            onClose()
        }
        model = capture
        startTicker()
        await capture.begin()
        #if DEBUG
        // Screenshot hook only: the Paused state is behind a button no capture script can tap.
        if DebugLaunch.voiceAutoPause {
            try? await Task.sleep(for: .seconds(DebugLaunch.voicePauseAfter))
            capture.pause()
        }
        #endif
    }

    private static func haptic(from old: VoiceCaptureModel.Phase?,
                               to new: VoiceCaptureModel.Phase?) -> SensoryFeedback? {
        switch (old, new) {
        case (_, .recording): return .start
        case (.recording, .transcribing), (.recording, .needsConsent): return .stop
        case (.transcribing, .idle): return .success
        case (_, .failed), (_, .permissionDenied): return .error
        default: return nil
        }
    }

    /// The **recorded** time, read from the capture rather than counted here. A second counter beside
    /// the model's own is how a paused timer keeps ticking (`docs/10-voice-v2.md` §5).
    private var timeString: String {
        let seconds = Int(model?.elapsedRecording.components.seconds ?? 0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard let model, model.phase == .recording else { return }
                model.refreshLevel()
                levels.removeFirst()
                levels.append(max(0.05, model.level))
            }
        }
    }

    private func finish() { ticker?.invalidate() }
}
