import SwiftUI

/// About screen — brand, tagline, and what the product is. Editorial, matching Welcome.
struct AboutView: View {
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.s6) {
                Spacer().frame(height: DSSpacing.s8)
                AppMark()

                Text("A private place for the thoughts you want to keep — by writing or speaking. No account. No noise. Your notes stay on your device.")
                    .font(.ds.editorBody)
                    .foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.s4)

                Text(appVersion)
                    .font(.ds.caption)
                    .foregroundStyle(Color.ds.textTertiary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DSSpacing.screenH)
        }
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
