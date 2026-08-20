import SwiftUI

/// One-time first-run screen — the app's opening card. No permissions, no account, and no navigation
/// chrome: `AppRootView` shows this as a bare root view, never pushed, so there is no back affordance
/// to hide. See docs/03-design-system.md §4.2.
///
/// Three blocks, top to bottom: brand, message, and the single action. The action is pinned with
/// `safeAreaInset`, which also lifts the optical centre of the first two blocks above the centre of
/// the screen — the reason there are no hard-coded vertical offsets here.
struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: DSSpacing.s8)
            AppMark(markSize: 76)
            message
            Spacer(minLength: DSSpacing.s10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DSSpacing.s6)
        .safeAreaInset(edge: .bottom) { continueButton }
        .background(Color.ds.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Tagline, then one supporting sentence. The width cap is what breaks that sentence over two
    /// even lines — at the full 24 pt margin it runs to a top-heavy line plus a two-word orphan.
    private var message: some View {
        VStack(spacing: DSSpacing.s3) {
            Text("Write it. Say it. Keep it.")
                .font(.ds.groupTitle)
                .foregroundStyle(Color.ds.textPrimary)

            Text("A quiet place for anything you want to put into words.")
                .font(.ds.preview)
                .foregroundStyle(Color.ds.textSecondary)
                .lineSpacing(3)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 240)
        .padding(.top, DSSpacing.s6)
    }

    /// The one action on the screen. The label is `onAccent`, never a fixed white: the Dark Mode
    /// accent (`#8AA9BE`) is light enough that white on it lands at 2.5:1 and reads as a *disabled*
    /// control. `onAccent` takes the same fill to 7.6:1 (RULES.md §4).
    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ds.onAccent)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.ds.accent, in: RoundedRectangle(cornerRadius: DSRadius.large))
                .contentShape(RoundedRectangle(cornerRadius: DSRadius.large))
        }
        .buttonStyle(FilledPress())
        .padding(.horizontal, DSSpacing.s6)
        .padding(.vertical, DSSpacing.s6)
    }
}

/// Answers the tap with a small scale rather than the system's default label fade — on a filled
/// button that fade is the thing that makes it look switched off.
private struct FilledPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DSMotion.fast, value: configuration.isPressed)
    }
}

#Preview("Light") { WelcomeView(onContinue: {}) }
#Preview("Dark") { WelcomeView(onContinue: {}).preferredColorScheme(.dark) }
