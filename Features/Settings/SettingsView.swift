import SwiftUI

/// Small settings screen: privacy lock + about. No appearance selector (theme follows system).
/// See docs/03-design-system.md §4.11.
struct SettingsView: View {
    @Bindable var lock: AppLockModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Privacy") {
                    Toggle("Lock with Face ID", isOn: Binding(
                        get: { lock.enabled },
                        set: { wantOn in
                            if wantOn {
                                Task { _ = await lock.enable() }
                            } else {
                                lock.disable()
                            }
                        }
                    ))
                }

                Section("About") {
                    LabeledContent("Privacy Policy") { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    LabeledContent("About Yourly") { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return v
    }
}
