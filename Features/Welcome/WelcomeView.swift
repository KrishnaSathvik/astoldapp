import SwiftUI

/// One-time first-run screen. No permissions, no account. See docs/03-design-system.md §4.2.
struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack {
            Spacer()
            AppMark()
            VStack(spacing: DSSpacing.s4) {
                Text("Write it. Say it. Keep it.")
                    .font(.ds.groupTitle)
                    .foregroundStyle(Color.ds.textPrimary)
                Text("A private place for the thoughts you want to keep.\nType them or speak them. Keep them as they came.")
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DSSpacing.s8)
            Spacer()
            Button(action: onContinue) {
                Text("Continue")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.ds.accent, in: RoundedRectangle(cornerRadius: DSRadius.medium))
            }
        }
        .padding(.horizontal, DSSpacing.s6)
        .padding(.bottom, DSSpacing.s8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.canvas)
    }
}

#Preview { WelcomeView(onContinue: {}) }
