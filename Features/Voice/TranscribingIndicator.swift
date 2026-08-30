import SwiftUI

/// Small calm "Transcribing…" state shown after Done. Never fakes completion (RULES.md §2).
///
/// It is drawn on two different grounds, and that is why it asks which one. The in-note panel is the
/// app's one deliberately dark surface (`docs/03-design-system.md` §4.8), where white is the correct
/// foreground; Quick Voice owns the whole screen and sits on the ordinary canvas, where white is
/// invisible in Light mode. It used to hardcode white for both, which made the processing state after
/// Done effectively white-on-white on a phone in daylight — found on device, 2026-08-28.
///
/// The page ground resolves through the semantic tokens rather than through `.primary`/`.secondary`,
/// so it follows the app's own Light/Dark decision (including a forced theme) rather than the
/// system's (RULES.md §4 — semantic tokens, never scattered literals).
struct TranscribingIndicator: View {
    /// Where this is being drawn, which is the only thing that decides its colours.
    enum Ground {
        /// The ordinary note canvas — Quick Voice, which owns the screen.
        case page
        /// The dark recording panel that floats over a note.
        case darkPanel
    }

    var ground: Ground = .page

    var body: some View {
        HStack(spacing: DSSpacing.s3) {
            ProgressView()
                .controlSize(.small)
                .tint(secondary)
            Text("Transcribing…")
                .font(.ds.preview)
                .foregroundStyle(primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.s5)
        // One element, one sentence — the spinner says nothing a reader needs that the words do not.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Transcribing")
    }

    private var primary: Color {
        switch ground {
        case .page: Color.ds.textPrimary
        case .darkPanel: .white
        }
    }

    private var secondary: Color {
        switch ground {
        case .page: Color.ds.textSecondary
        case .darkPanel: .white.opacity(0.8)
        }
    }
}
