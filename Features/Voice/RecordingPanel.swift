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

    @State private var elapsed: Int = 0
    @State private var tickCount: Int = 0
    @State private var levels: [Float] = Array(repeating: 0.05, count: 32)
    @State private var ticker: Timer?
    @State private var wasActive = false

    var body: some View {
        VStack(spacing: DSSpacing.s5) {
            switch model.phase {
            case .recording:
                recording
            case .needsConsent:
                consentRequest
            case .transcribing:
                TranscribingIndicator()
            case .failed(let error):
                failure(error)
            case .permissionDenied:
                permissionDenied
            case .idle:
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
        .onChange(of: model.phase) { _, new in
            switch new {
            case .recording, .needsConsent, .transcribing, .failed, .permissionDenied:
                wasActive = true
            case .idle:
                if wasActive { onClose() }   // capture completed → dismiss
            }
        }
    }

    // MARK: States

    private var recording: some View {
        VStack(spacing: DSSpacing.s4) {
            WaveformView(levels: levels)
                .frame(height: 48)
            Text(timeString)
                .font(.system(.body, design: .monospaced))
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

    private func failure(_ error: TranscriptionError) -> some View {
        VStack(spacing: DSSpacing.s4) {
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
            HStack(spacing: DSSpacing.s6) {
                if case .monthlyLimitReached = error {
                    // Nothing to retry — the same upload would be refused again — and nothing to
                    // upsell, because there is no Pro tier to sell (RULES.md §1).
                    Button("OK") { model.discard(); onClose() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                } else {
                    Button("Discard") { model.discard(); onClose() }
                        .foregroundStyle(.white.opacity(0.8))
                    Button(retryLabel(for: error)) { model.retry() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
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
        case (_, .recording): return .start
        // Recording has stopped in both cases; the disclosure just sits between stop and send.
        case (.recording, .transcribing), (.recording, .needsConsent): return .stop
        case (.transcribing, .idle): return .success
        case (_, .failed), (_, .permissionDenied): return .error
        default: return nil
        }
    }

    private var timeString: String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private func message(for error: TranscriptionError) -> String {
        switch error {
        case .offline: return "A connection is needed to transcribe this recording."
        case .timedOut: return "The transcription service isn't responding. Your recording is safe — try again."
        case .noSpeech: return "No speech was detected."
        case .rateLimited: return "Too many requests. Try again in a moment."
        case .requestTooLarge: return "That recording is too large to send."
        case .recordingTooLong(let maxSeconds): return Self.lengthLimitMessage(maxSeconds: maxSeconds)
        case .monthlyLimitReached(let resetsAt): return Self.allowanceMessage(resetsAt: resetsAt)
        default: return "Couldn't transcribe that recording."
        }
    }

    /// Only the monthly allowance gets a title. It is the one failure that is not about *this*
    /// recording, and reading it as "something went wrong" would be the wrong thing to believe.
    static func title(for error: TranscriptionError) -> String? {
        if case .monthlyLimitReached = error { return "Voice will be back soon" }
        return nil
    }

    /// The date comes from the relay and is rendered in the reader's own time zone — the app never
    /// works out when the month turns over. Without one, the sentence simply stops early rather than
    /// guessing a date (`docs/04-voice-transcription.md` §12).
    static func allowanceMessage(resetsAt: Date?) -> String {
        let used = "You've used this month's included voice transcription."
        guard let resetsAt else { return "\(used) You can keep writing normally." }
        let day = resetsAt.formatted(.dateTime.month(.wide).day())
        return "\(used) You can keep writing normally, and voice will be available again on \(day)."
    }

    /// "Recordings can be up to 5 minutes." — stated in the relay's units, not a hard-coded number,
    /// so changing the server limit changes the copy with it.
    static func lengthLimitMessage(maxSeconds: Int) -> String {
        let minutes = maxSeconds / 60
        guard minutes >= 1, maxSeconds % 60 == 0 else {
            return "Recordings can be up to \(maxSeconds) seconds."
        }
        return "Recordings can be up to \(minutes) minute\(minutes == 1 ? "" : "s")."
    }

    private func retryLabel(for error: TranscriptionError) -> String {
        error == .noSpeech ? "Try Again" : "Retry"
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard model.phase == .recording else { return }
                model.refreshLevel()
                levels.removeFirst()
                levels.append(max(0.05, model.level))
                tickCount += 1
                if tickCount % 10 == 0 { elapsed += 1 }   // 10 × 0.1s = 1s
            }
        }
    }

    private func stop() { ticker?.invalidate() }
}
