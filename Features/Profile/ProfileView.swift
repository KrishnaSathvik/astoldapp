import SwiftUI

/// Profile is the top-level "you" screen: an optional name, and Settings / About / Rating sections.
/// Replaces a bare settings gear. Pushed inside Home's navigation stack (system back button).
struct ProfileView: View {
    @Bindable var lock: AppLockModel
    @AppStorage("profileName") private var name = ""

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "" }
        return String(first).uppercased()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: DSSpacing.s4) {
                    ZStack {
                        Circle().fill(Color.ds.accent.opacity(0.15))
                        if initials.isEmpty {
                            Image(systemName: "person.fill").foregroundStyle(Color.ds.accent)
                        } else {
                            Text(initials).font(.title2.weight(.semibold)).foregroundStyle(Color.ds.accent)
                        }
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Your name", text: $name)
                            .font(.ds.editorTitle)
                            .foregroundStyle(Color.ds.textPrimary)
                        Text("Your notes stay on this device.")
                            .font(.ds.caption)
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }
                .padding(.vertical, DSSpacing.s1)
            }

            Section {
                Toggle("Lock with Face ID", isOn: Binding(
                    get: { lock.enabled },
                    set: { wantOn in
                        if wantOn { Task { _ = await lock.enable() } } else { lock.disable() }
                    }
                ))
            } header: {
                Text("Settings")
            } footer: {
                Text("Appearance follows your system Light/Dark setting.")
            }

            Section("About") {
                LabeledContent("Privacy Policy") { chevron }
                LabeledContent("About Yourly") { chevron }
                LabeledContent("Version", value: appVersion)
            }

            Section {
                LabeledContent {
                    chevron
                } label: {
                    Label("Rate Yourly", systemImage: "star")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
    }
}
