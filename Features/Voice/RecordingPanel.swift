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
            case .recording, .transcribing, .failed, .permissionDenied:
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

    private func failure(_ error: TranscriptionError) -> some View {
        VStack(spacing: DSSpacing.s4) {
            Text(message(for: error))
                .font(.ds.preview)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            HStack(spacing: DSSpacing.s6) {
                Button("Discard") { model.discard(); onClose() }
                    .foregroundStyle(.white.opacity(0.8))
                Button(retryLabel(for: error)) { model.retry() }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
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
        case (.recording, .transcribing): return .stop
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
        case .noSpeech: return "No speech was detected."
        case .rateLimited: return "Too many requests. Try again in a moment."
        case .requestTooLarge: return "That recording is too long."
        default: return "Couldn't transcribe that recording."
        }
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
