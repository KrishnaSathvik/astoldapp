import SwiftUI
import SwiftData

/// Plain-text editor: date, optional title, body. No Save, no toolbar (RULES.md §4).
struct EditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let note: Note
    @State private var model: EditorModel?
    @State private var voice: VoiceCaptureModel?
    @FocusState private var bodyFocused: Bool

    private var isCapturing: Bool { voice != nil }

    private var dateText: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        return df.string(from: note.createdAt).uppercased()
    }

    var body: some View {
        ZStack {
            Color.ds.canvas.ignoresSafeArea()
            if let model {
                editor(model)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if model == nil {
                model = EditorModel(note: note, context: context)
                bodyFocused = true
            }
        }
        .onDisappear { model?.finish() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model?.flush() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.ds.textSecondary)
                    .accessibilityLabel("More")
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

            TextEditor(text: Binding(get: { model.body }, set: { model.body = $0 }))
                .font(.ds.editorBody)
                .foregroundStyle(Color.ds.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($bodyFocused)
                .disabled(isCapturing)   // recording/transcription owns the anchor
                .overlay(alignment: .topLeading) {
                    if model.body.isEmpty {
                        Text("Start writing…")
                            .font(.ds.editorBody)
                            .foregroundStyle(Color.ds.textTertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
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
            RecordingPanel(model: voice) { self.voice = nil; bodyFocused = true }
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
        bodyFocused = false
        let capture = VoiceCaptureModel(
            recorder: AVAudioRecorderService(),
            service: FakeTranscriptionService()
        ) { text in
            model.insertVoiceTranscript(text)
        }
        voice = capture
        Task { await capture.begin() }
    }
}
