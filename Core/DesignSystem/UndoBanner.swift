import SwiftUI

/// Small, temporary "Note deleted   Undo" banner. See docs/03-design-system.md §4.10.
struct UndoBanner: View {
    var message: String = "Note deleted"
    var onUndo: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textPrimary)
            Spacer()
            Button("Undo", action: onUndo)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ds.accent)
        }
        .padding(.horizontal, DSSpacing.s5)
        .padding(.vertical, DSSpacing.s4)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: DSRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.medium)
                .stroke(Color.ds.textTertiary.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, DSSpacing.screenH)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
