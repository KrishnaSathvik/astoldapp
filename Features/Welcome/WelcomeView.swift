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
                Text("A quiet place for anything you want to put into words.\nWrite it, say it, shape it your way.")
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
        .background(Color.ds.canvas.ignoresSafeArea())
    }
}

#Preview { WelcomeView(onContinue: {}) }
