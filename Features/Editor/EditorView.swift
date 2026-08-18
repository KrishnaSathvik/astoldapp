import SwiftUI
import SwiftData

/// Plain-text editor: date, optional title, body. No Save, no formatting toolbar (RULES.md §4).
///
/// Two intentions, one screen (product behavior matrix):
///  - **New note** — opens ready to capture: the body takes focus and the keyboard rises.
///  - **Existing note** — opens for *reading*: nothing becomes first responder, no keyboard.
///    Tapping the title or the body starts editing exactly where the user tapped.
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
    @State private var bodyFocused = false
    @FocusState private var titleFocused: Bool
    @State private var capturedInsertOffset = 0
    /// Whether the body had the caret when recording started — decides whether the keyboard comes
    /// back after the transcript lands.
    @State private var refocusBodyAfterVoice = false

    private var isCapturing: Bool { voice != nil }
    /// True while the user is actually editing (a field owns the keyboard), false while reading.
    private var isEditing: Bool { bodyFocused || titleFocused }

    private var dateText: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy · h:mm a"
        return df.string(from: note.createdAt).uppercased()
    }

    private func close() {
        // onDisappear runs finish() (flush or discard empty draft).
        if let onClose { onClose() } else { dismiss() }
    }

    private func dismissKeyboard() {
        titleFocused = false
        bodyFocused = false
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
                // A note created by the compose button is still an empty draft here — that, and only
                // that, means "the user came to write", so only that opens the keyboard.
                if note.isEmptyDraft { bodyFocused = true }
            }
            #if DEBUG
            if DebugLaunch.autoStartVoice, let model {
                startVoice(model)
                Task { try? await Task.sleep(for: .seconds(1.5)); voice?.done() }
            }
            #endif
        }
        .onDisappear {
            // Leaving mid-recording must not leave the microphone hot or raw audio on disk.
            voice?.cancel()
            voice = nil
            model?.finish()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model?.flush() }
            // Recording cannot continue once the app is suspended, so finish the capture with the
            // audio already on disk rather than stranding it.
            if phase == .background, voice?.phase == .recording { voice?.done() }
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
            // Autosave is the only save (RULES.md §4), so this is *not* a completion control — it
            // exists solely to put the keyboard away, and only while the keyboard is up.
            if isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismissKeyboard() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ds.accent)
                        .accessibilityLabel("Dismiss keyboard")
                }
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
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { titleFocused = false; bodyFocused = true }
                .disabled(isCapturing)

            BodyTextView(
                text: Binding(get: { model.body }, set: { model.body = $0 }),
                selectedRange: $bodySelection,
                isFocused: $bodyFocused,
                isEditable: !isCapturing   // recording/transcription owns the anchor
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
        .animation(DSMotion.fast, value: isEditing)
    }

    @ViewBuilder private func voiceLayer(_ model: EditorModel) -> some View {
        if let voice {
            RecordingPanel(model: voice) { endVoice() }
                .padding(.bottom, DSSpacing.s4)
        } else {
            HStack {
                Spacer()
                VoiceButton(action: { startVoice(model) }, appendsToEnd: !bodyFocused)
            }
            .padding(.bottom, DSSpacing.s4)
        }
    }

    private func startVoice(_ model: EditorModel) {
        // Where the transcript will land is decided *now*, before recording, and the recording owns
        // that anchor (docs/04-voice-transcription.md §8):
        //  - caret in the body  → insert at the caret
        //  - reading, no caret  → append to the end of the note
        refocusBodyAfterVoice = bodyFocused
        capturedInsertOffset = bodyFocused
            ? bodySelection.location
            : (model.body as NSString).length

        let capture = VoiceCaptureModel(
            recorder: AVAudioRecorderService(),
            service: TranscriptionConfig.makeService()   // real relay if configured, else fake
        ) { text in
            let cursor = model.insertVoiceTranscript(text, atUTF16: capturedInsertOffset)
            bodySelection = NSRange(location: cursor, length: 0)
        }
        voice = capture
        Task { await capture.begin() }
    }

    private func endVoice() {
        voice = nil
        // Reading stays reading: only give the keyboard back if the user was editing beforehand.
        if refocusBodyAfterVoice { bodyFocused = true }
    }
}
