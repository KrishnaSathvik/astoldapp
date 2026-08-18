import SwiftUI

/// "What is As Told" screen — brand, tagline, and what the product is. Editorial, matching Welcome.
/// Version lives as a row in Profile, not here (avoids duplication).
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.s6) {
                Spacer().frame(height: DSSpacing.s10)
                AppMark()

                Text("Write it. Say it. Keep it.")
                    .font(.ds.groupTitle)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("A quiet place for anything you want to put into words — write it, say it, shape it your way. No account. No noise. Your notes stay on your device.")
                    .font(.ds.editorBody)
                    .foregroundStyle(Color.ds.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.s4)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DSSpacing.screenH)
        }
        .scrollIndicators(.hidden)
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle("What is As Told")
        .navigationBarTitleDisplayMode(.inline)
    }
}
