import SwiftUI

/// Small calm "Transcribing…" state shown after Done. Never fakes completion (RULES.md §2).
struct TranscribingIndicator: View {
    var body: some View {
        HStack(spacing: DSSpacing.s3) {
            ProgressView().controlSize(.small).tint(.white)
            Text("Transcribing…")
                .font(.ds.preview)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.s5)
    }
}
