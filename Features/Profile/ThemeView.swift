import SwiftUI

/// Theme picker — Light / Dark / Use device settings, plus Increase contrast. As Told editorial style
/// (warm canvas, chromeless rows). See docs/03-design-system.md §15.
struct ThemeView: View {
    @Environment(ThemeStore.self) private var themeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s8) {
                VStack(spacing: 0) {
                    ForEach(Array(AppTheme.allCases.enumerated()), id: \.element.id) { index, option in
                        Button { themeStore.theme = option } label: {
                            row(option, selected: themeStore.theme == option)
                        }
                        .buttonStyle(.plain)
                        if index < AppTheme.allCases.count - 1 { Separator() }
                    }
                }

                Spacer(minLength: DSSpacing.s10)
            }
            .padding(.horizontal, DSSpacing.screenH)
            .padding(.top, DSSpacing.s6)
        }
        .scrollIndicators(.hidden)
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func row(_ option: AppTheme, selected: Bool) -> some View {
        HStack(spacing: DSSpacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.ds.editorBody)
                    .foregroundStyle(Color.ds.textPrimary)
                if option == .system {
                    Text("Follow the light or dark theme setting in your device settings.")
                        .font(.ds.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                }
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? Color.ds.accent : Color.ds.textTertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private struct Separator: View {
        var body: some View {
            Rectangle().fill(Color.ds.textTertiary.opacity(0.12)).frame(height: 0.5)
        }
    }
}
