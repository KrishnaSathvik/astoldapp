import SwiftUI
import SwiftData

/// Home is the complete chronological notes timeline. See docs/01-product-requirements.md §8.
struct HomeView: View {
    @Environment(\.modelContext) private var context

    /// The note being edited *and* what its Back button should name, as one value (`EditorRoute`).
    ///
    /// One `@State`, not two. A separate origin flag was the obvious way to do this and the wrong
    /// one — not because a caller might forget to set it, but because `navigationDestination` reads a
    /// sibling `@State` a push behind, so the flag was still `.notes` when the editor was built. See
    /// `EditorRoute`.
    @State private var editingRoute: EditorRoute?
    @State private var deletion = NoteDeletion()
    @State private var searchQuery = ""
    @State private var showingCalendar = false
    @State private var showingProfile = false
    @State private var showingQuickVoice = false
    /// The note a Quick Voice capture just earned, held until the capture screen is actually gone.
    ///
    /// Opening it from inside `onCaptured` would push the editor while the cover is still on its way
    /// out, so the note is parked here and `onDismiss` opens it — one transition after another rather
    /// than both at once.
    @State private var capturedNote: Note?
    /// A recording a previous capture kept and never got to transcribe — after Back, or after the app
    /// was closed. Offered back once, on one surface, with two controls
    /// (`RecoveredRecordingView`, `docs/10-voice-v2.md` §13).
    @State private var recoveredRecording: RetainedVoiceRecording?
    @State private var pageLimit = 40
    @AppStorage("profileName") private var profileName = ""
    @Environment(AppLockModel.self) private var lock

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            // Home's own screen owns Home's chrome. `.searchable` and the profile / calendar /
            // compose controls live *inside* it rather than on the view that also declares the
            // stack's destinations — otherwise they read as chrome belonging to the stack, and a
            // pushed editor spent the whole transition with Home's search field still anchored to
            // the bottom of it and Home's glass controls floating over its content.
            homeScreen
                .navigationDestination(item: $editingRoute) { route in
                    // Deleting a note happens on the timeline, by swiping it. The editor deliberately
                    // carries no delete of its own — see RULES.md §4.
                    EditorView(note: route.note, onClose: { editingRoute = nil },
                               origin: route.origin)
                }
                .navigationDestination(isPresented: $showingCalendar) {
                    CalendarPage()
                }
                .navigationDestination(isPresented: $showingProfile) {
                    ProfileView(lock: lock)
                }
        }
    }

    private var homeScreen: some View {
        ZStack(alignment: .bottom) {
            Color.ds.canvas.ignoresSafeArea()
            if isSearching {
                SearchResultsView(query: searchQuery) { open($0, from: .notes) }
            } else {
                content
                if deletion.pending != nil {
                    UndoBanner { deletion.undo(in: context) }
                        .padding(.bottom, DSSpacing.s4)
                }
            }
        }
        .searchable(text: $searchQuery, prompt: "Search notes")
        #if DEBUG
        .task {
            if let q = DebugLaunch.presetSearch { searchQuery = q }
            if DebugLaunch.openCalendar { showingCalendar = true }
            if DebugLaunch.openSettings { showingProfile = true }
            if DebugLaunch.openQuickVoice { showingQuickVoice = true }
        }
        #endif
        .animation(DSMotion.standard, value: deletion.pending != nil)
        .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingProfile = true } label: {
                        if let profileInitial {
                            Text(profileInitial)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.ds.iconProfile)
                        } else {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(Color.ds.iconProfile)
                        }
                    }
                    .accessibilityLabel("Profile")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCalendar = true } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.ds.iconCalendar)
                    }
                    .accessibilityLabel("Open calendar")
                }
                // No ToolbarSpacer here: calendar and compose share one capsule, so the header
                // reads as two grouped controls rather than three unrelated floating islands (§5).
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newNote) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.ds.iconCompose)
                    }
                    .accessibilityLabel("New note")
                }
                // Write it. Say it. The two ways into a note sit beside each other, and neither is
                // a floating button or a second creation area (docs/10-voice-v2.md §1).
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingQuickVoice = true } label: {
                        Image(systemName: "mic")
                            .foregroundStyle(Color.ds.iconCompose)
                    }
                    .accessibilityLabel("New voice note")
                    .accessibilityHint("Starts recording straight away")
                }
        }
        // Quick Voice owns the screen: no editor appears first, and no note exists until a
        // transcript earns one (docs/10-voice-v2.md §3).
        .fullScreenCover(isPresented: $showingQuickVoice, onDismiss: openCapturedNote) {
            QuickVoiceCaptureView(
                onCaptured: captureQuickVoiceNote,
                onClose: { showingQuickVoice = false }
            )
        }
        // A sheet rather than a cover: it is an offer, not a demand. Swiping it away keeps the
        // recording — it is offered again next launch — because nothing about this may become a
        // deadline the user can lose audio by missing.
        .sheet(item: $recoveredRecording, onDismiss: openCapturedNote) { recording in
            RecoveredRecordingView(
                recording: recording,
                onTranscribed: captureQuickVoiceNote,
                onClose: { recoveredRecording = nil }
            )
            // Small by default, and draggable to full height: three lines and two buttons need very
            // little room at ordinary text sizes, and need considerably more at accessibility ones.
            // A fixed height is how the second button ends up under the edge of the screen (RULES.md §4).
            .presentationDetents([.height(260), .large])
        }
        // Checked at launch, and again whenever the editor closes: leaving a note mid-failure is one
        // of the two ways a recording ends up needing this (`VoiceCaptureModel.finishOnLeave`).
        .task { findRecoveredRecording() }
        .onChange(of: editingRoute) { _, route in
            if route == nil { findRecoveredRecording() }
        }
    }

    /// Looks once for a recording still worth offering back. Anything expired or already gone is
    /// forgotten by `recoverable` itself, so this either finds one recording or nothing at all.
    private func findRecoveredRecording() {
        guard recoveredRecording == nil, !showingQuickVoice else { return }
        recoveredRecording = UserDefaultsRetainedRecording().recoverable()
    }

    private var profileInitial: String? {
        let t = profileName.trimmingCharacters(in: .whitespaces)
        guard let f = t.first else { return nil }
        return String(f).uppercased()
    }

    /// Home is always the whole timeline. Browsing a single day belongs to the calendar, which
    /// shows that day's notes under its own grid rather than sending the reader back here filtered.
    private var content: some View {
        PagedNotesList(
            limit: pageLimit,
            onSelect: { open($0, from: .notes) },
            onDelete: { deletion.delete($0, in: context) },
            onLoadMore: { pageLimit += 40 }
        )
    }

    /// The one way this screen opens the editor, so the note and the Back label are always set
    /// together.
    private func open(_ note: Note, from origin: EditorOrigin) {
        editingRoute = EditorRoute(note, from: origin)
    }

    private func newNote() {
        EditorTrace.open("new note")
        let note = Note()
        context.insert(note)
        EditorTrace.mark("draft created")
        open(note, from: .notes)
        EditorTrace.mark("navigation requested")
    }

    /// The only place a Quick Voice capture becomes a stored note.
    ///
    /// Reached exclusively on a successful transcription — `VoiceCaptureModel` calls back nowhere
    /// else — so Cancel, a denied microphone, no speech, a declined disclosure, and a transcription
    /// failure cannot create one. This is the whole transient-capture rule, and it is enforced by
    /// where the call sits rather than by a check inside it (`QuickVoiceNote`).
    private func captureQuickVoiceNote(_ transcript: String) {
        guard let note = QuickVoiceNote.make(from: transcript) else { return }
        context.insert(note)
        capturedNote = note
    }

    /// Runs when the capture screen has finished dismissing. Nothing to open on any path but success,
    /// because nothing was created on any path but success.
    private func openCapturedNote() {
        guard let note = capturedNote else { return }
        capturedNote = nil
        // The editor opens for *reading* because the note already has a body: `EditorView` gives the
        // keyboard only to an empty draft. Someone who chose to speak is not answered with a
        // keyboard (docs/10-voice-v2.md §7) — and that falls out of behavior that already shipped
        // rather than needing a rule of its own here.
        open(note, from: .notes)
    }

}
