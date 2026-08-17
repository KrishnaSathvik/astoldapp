import SwiftUI

/// Privacy screen. The copy reflects the *actual* architecture (docs/01-product-requirements.md §11,
/// RULES.md §3) — it must stay true to how the app really behaves.
struct PrivacyView: View {
    private struct Point: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    private let points: [Point] = [
        .init(title: "Your notes stay on your device",
              body: "Notes are stored locally on your iPhone. There is no account and no cloud database of your notes."),
        .init(title: "No sign-in",
              body: "Yourly never asks you to create an account or sign in. Nothing ties your notes to an identity."),
        .init(title: "Voice is transcribed, not kept",
              body: "When you speak a note, the audio is sent only to transcribe it, and the recording is deleted right after. Your speech is transcribed faithfully — never translated, summarized, or rewritten."),
        .init(title: "Nothing is logged",
              body: "The transcription service never stores or logs your audio, transcript, note title, or note text — only anonymous technical metadata needed to run reliably."),
        .init(title: "Lock it down",
              body: "You can optionally require Face ID to open the app. When it's on, your notes are hidden in the app switcher and revealed only after you authenticate."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s6) {
                Text("Privacy")
                    .font(.ds.homeTitle)
                    .foregroundStyle(Color.ds.textPrimary)
                    .padding(.top, DSSpacing.s4)

                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: DSSpacing.s2) {
                        Text(point.title)
                            .font(.ds.noteTitle)
                            .foregroundStyle(Color.ds.textPrimary)
                        Text(point.body)
                            .font(.ds.preview)
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }

                Spacer(minLength: DSSpacing.s10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.screenH)
        }
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
