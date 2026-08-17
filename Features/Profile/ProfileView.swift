import SwiftUI
import StoreKit

/// Profile — the top-level "you" screen in Yourly's Quiet Editorial style (warm canvas, chromeless
/// rows, no iOS cards). Holds an optional name and Settings / About / Rating.
struct ProfileView: View {
    @Bindable var lock: AppLockModel
    @Environment(ThemeStore.self) private var themeStore
    @AppStorage("profileName") private var name = ""
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s8) {
                header

                section("Settings") {
                    NavigationLink { ThemeView() } label: {
                        ProfileRow(title: "Theme") {
                            HStack(spacing: DSSpacing.s2) {
                                Text(themeStore.theme.title)
                                    .font(.ds.preview)
                                    .foregroundStyle(Color.ds.textSecondary)
                                Chevron()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Separator()
                    ProfileRow(title: "Lock with Face ID") {
                        Toggle("", isOn: Binding(
                            get: { lock.enabled },
                            set: { on in
                                if on { Task { _ = await lock.enable() } } else { lock.disable() }
                            }
                        ))
                        .labelsHidden()
                    }
                }

                section("About") {
                    NavigationLink { AboutView() } label: {
                        ProfileRow(title: "What is Yourly") { Chevron() }
                    }
                    .buttonStyle(.plain)
                    Separator()
                    NavigationLink { PrivacyView() } label: {
                        ProfileRow(title: "Privacy") { Chevron() }
                    }
                    .buttonStyle(.plain)
                    Separator()
                    Button { requestReview() } label: {
                        ProfileRow(title: "Rate Yourly") { Chevron() }
                    }
                    .buttonStyle(.plain)
                    Separator()
                    ProfileRow(title: "Version") {
                        Text(appVersion).font(.ds.preview).foregroundStyle(Color.ds.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Version \(appVersion)")
                }

                Spacer(minLength: DSSpacing.s10)
            }
            .padding(.horizontal, DSSpacing.screenH)
            .padding(.top, DSSpacing.s4)
        }
        .scrollIndicators(.hidden)
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DSSpacing.s4) {
            ProfileAvatar(name: name, size: 76)

            TextField("Your name", text: $name)
                .font(.ds.editorTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)

            Text("Your notes stay on this device.")
                .font(.ds.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.s4)
    }

    // MARK: Section helpers

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            Text(title.uppercased())
                .font(.ds.dateLabel)
                .foregroundStyle(Color.ds.textTertiary)
                .padding(.bottom, DSSpacing.s1)
            content()
        }
    }

    @ViewBuilder private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.ds.caption)
            .foregroundStyle(Color.ds.textTertiary)
            .padding(.top, DSSpacing.s1)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

/// A chromeless profile row: leading title (optional icon) + trailing accessory.
private struct ProfileRow<Trailing: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DSSpacing.s3) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(Color.ds.accent)
            }
            Text(title)
                .font(.ds.editorBody)
                .foregroundStyle(Color.ds.textPrimary)
            Spacer()
            trailing()
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }
}

private struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Color.ds.textTertiary)
    }
}

private struct Separator: View {
    var body: some View {
        Rectangle().fill(Color.ds.textTertiary.opacity(0.12)).frame(height: 0.5)
    }
}
