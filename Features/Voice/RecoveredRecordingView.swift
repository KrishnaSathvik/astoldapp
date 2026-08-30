import SwiftUI

/// The one place a recording that outlived its capture is offered back (`docs/10-voice-v2.md` §13,
/// decided 2026-08-28).
///
/// It exists because Back and a terminated process are neither "the user deleted it" nor "it became
/// text" nor "the 24 hours ran out", so neither may be what ends a recording. Something has to be
/// able to say *this is still here* afterwards, and this is that something.
///
/// **One recording, two controls, and nothing else.** No list, no playback, no name, no date, no
/// duration, no history — the moment a second row could appear here, As Told has the audio archive
/// `RULES.md` §7 excludes. It is the ordinary retained-failure surface in a different room, driven by
/// the same `VoiceCaptureModel` through the same `retry()` and `deleteRecording()`.
///
/// Dismissing it without choosing is safe and deliberate: the recording stays, and it is offered
/// again next launch. Nothing here is a deadline.
struct RecoveredRecordingView: View {
    let recording: RetainedVoiceRecording
    /// Called with the transcript a successful retry produced. The caller owns note creation — the
    /// same rule Quick Voice follows, for the same reason (`QuickVoiceNote`).
    var onTranscribed: (String) -> Void
    var onClose: () -> Void

    /// Injectable so tests and previews can drive it without a network.
    var makeModel: (RetainedVoiceRecording, @escaping (String) -> Void) -> VoiceCaptureModel = {
        recording, onTranscript in
        #if DEBUG
        if let stand_in = DebugVoice.service() {
            return VoiceCaptureModel(recovering: recording, service: stand_in,
                                     onTranscript: onTranscript)
        }
        #endif
        return VoiceCaptureModel(recovering: recording,
                                 service: TranscriptionConfig.makeService(),
                                 onTranscript: onTranscript)
    }

    @State private var model: VoiceCaptureModel?

    var body: some View {
        VStack(spacing: DSSpacing.s5) {
            if let model {
                content(model)
            }
        }
        .padding(DSSpacing.s6)
        .frame(maxWidth: .infinity)
        .background(Color.ds.canvas)
        .task {
            guard model == nil else { return }
            model = makeModel(recording) { text in
                onTranscribed(text)
                onClose()
            }
        }
        .onChange(of: model?.phase) { old, new in
            if let old, let new,
               let said = VoiceCaptureModel.Phase.announcement(from: old, to: new) {
                UIAccessibility.post(notification: .announcement, argument: said)
            }
            // The recording is gone — transcribed, or deleted on purpose. Nothing left to offer.
            if new == .idle, old != nil, old != .idle { onClose() }
        }
    }

    @ViewBuilder
    private func content(_ model: VoiceCaptureModel) -> some View {
        switch model.phase {
        case .transcribing, .finishing:
            TranscribingIndicator()
        case .failed(let error):
            // A retry that failed again lands in the ordinary failure copy, with the ordinary two
            // controls. One implementation, wherever the failure happens.
            failure(error, model)
        default:
            offer(model)
        }
    }

    private func offer(_ model: VoiceCaptureModel) -> some View {
        VStack(spacing: DSSpacing.s4) {
            Text(VoiceErrorCopy.recoveryTitle)
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textPrimary)
                .multilineTextAlignment(.center)

            // Said before the retry, not discovered after it: the caret this recording was aimed at
            // belonged to an editing session that no longer exists.
            if let notice = VoiceErrorCopy.recoveryNotice(for: recording.origin) {
                Text(notice)
                    .font(.ds.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
            }

            controls(model)
        }
        .accessibilityElement(children: .contain)
    }

    private func failure(_ error: TranscriptionError, _ model: VoiceCaptureModel) -> some View {
        VStack(spacing: DSSpacing.s4) {
            Text(VoiceErrorCopy.message(for: error))
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textPrimary)
                .multilineTextAlignment(.center)
            if model.retainedRecording != nil {
                Text(VoiceErrorCopy.retainedNotice)
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
                controls(model)
            } else {
                // Nothing survived this one, so nothing is promised and there is nothing to retry.
                Button("OK") { model.discard(); onClose() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.ds.textPrimary)
                    .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The two controls, written once: they are the same two whether this is the first offer or the
    /// state after another failed retry.
    private func controls(_ model: VoiceCaptureModel) -> some View {
        HStack(spacing: DSSpacing.s6) {
            Button(VoiceErrorCopy.deleteRecordingLabel) { model.deleteRecording(); onClose() }
                .foregroundStyle(Color.ds.textSecondary)
                .frame(minHeight: 44)
                .accessibilityHint("Deletes this recording from this iPhone")
            Button(VoiceErrorCopy.retryLabel) { model.retry() }
                .fontWeight(.semibold)
                .foregroundStyle(Color.ds.textPrimary)
                .frame(minHeight: 44)
                .accessibilityHint("Sends this recording to be transcribed again")
        }
    }
}
