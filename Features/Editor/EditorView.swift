import SwiftUI
import SwiftData

/// Plain-text editor: date, optional title, body. No Save, no toolbar (RULES.md §4).
struct EditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    let note: Note
    /// Set by Home to nil the navigationDestination item — the reliable way to pop an item-based push.
    var onClose: (() -> Void)? = nil
    @State private var model: EditorModel?
    @State private var voice: VoiceCaptureModel?
    @State private var bodySelection = NSRange(location: 0, length: 0)
    @State private var focusToken = UUID()
    @State private var capturedInsertOffset = 0

    private var isCapturing: Bool { voice != nil }

    private var dateText: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy · h:mm a"
        return df.string(from: note.createdAt).uppercased()
    }

    private func close() {
        // onDisappear runs finish() (flush or discard empty draft).
        if let onClose { onClose() } else { dismiss() }
    }

    var body: some View {
        ZStack {
            Color.ds.canvas.ignoresSafeArea()
            if let model {
                editor(model)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if model == nil {
                model = EditorModel(note: note, context: context)
                focusToken = UUID()   // focus the body on first appearance
            }
            #if DEBUG
            if DebugLaunch.autoStartVoice, let model {
                startVoice(model)
                Task { try? await Task.sleep(for: .seconds(1.5)); voice?.done() }
            }
            #endif
        }
        .onDisappear { model?.finish() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model?.flush() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { close() } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                        Text("Notes")
                    }
                    .foregroundStyle(Color.ds.accent)
                }
                .accessibilityLabel("Back to notes")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { close() }   // finish → back to Home
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.ds.accent)
            }
        }
    }

    @ViewBuilder private func editor(_ model: EditorModel) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s3) {
            Text(dateText)
                .font(.ds.dateLabel)
                .foregroundStyle(Color.ds.textTertiary)

            TextField("Title", text: Binding(get: { model.title }, set: { model.title = $0 }))
                .font(.ds.editorTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .disabled(isCapturing)

            BodyTextView(
                text: Binding(get: { model.body }, set: { model.body = $0 }),
                selectedRange: $bodySelection,
                isEditable: !isCapturing,   // recording/transcription owns the anchor
                focusToken: focusToken
            )
            .overlay(alignment: .topLeading) {
                if model.body.isEmpty {
                    Text("Start writing…")
                        .font(.ds.editorBody)
                        .foregroundStyle(Color.ds.textTertiary)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) { voiceLayer(model) }
        .padding(.horizontal, DSSpacing.screenH)
        .padding(.top, DSSpacing.s4)
    }

    @ViewBuilder private func voiceLayer(_ model: EditorModel) -> some View {
        if let voice {
            RecordingPanel(model: voice) { self.voice = nil; focusToken = UUID() }
                .padding(.bottom, DSSpacing.s4)
        } else {
            HStack {
                Spacer()
                VoiceButton { startVoice(model) }
            }
            .padding(.bottom, DSSpacing.s4)
        }
    }

    private func startVoice(_ model: EditorModel) {
        // Capture the caret now — the recording/transcription owns this anchor (docs §8).
        capturedInsertOffset = model.body.characterOffset(fromUTF16: bodySelection.location)
        let capture = VoiceCaptureModel(
            recorder: AVAudioRecorderService(),
            service: TranscriptionConfig.makeService()   // real relay if configured, else fake
        ) { text in
            model.insertVoiceTranscript(text, at: capturedInsertOffset)
        }
        voice = capture
        Task { await capture.begin() }
    }
}
