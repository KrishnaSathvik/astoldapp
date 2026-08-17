import SwiftUI

/// Locked root: brand mark + Face ID affordance. Content stays hidden until authentication succeeds.
struct LockView: View {
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.ds.canvas.ignoresSafeArea()
            VStack(spacing: DSSpacing.s6) {
                AppMark()
                Button(action: onUnlock) {
                    Label("Unlock", systemImage: "faceid")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.ds.accent)
                }
            }
        }
    }
}
