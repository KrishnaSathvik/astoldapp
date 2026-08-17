import SwiftUI

/// Routes first-run Welcome → Home, and gates content behind the privacy lock when enabled.
/// No tab bar (docs/03-design-system.md §3). See docs/05-architecture.md §18, RULES.md §3.
struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false

    @State private var lock = AppLockModel(
        enabled: UserDefaults.standard.bool(forKey: "appLockEnabled"),
        authenticator: DeviceAuthenticator()
    )

    var body: some View {
        ZStack {
            main
                .environment(lock)

            switch lock.phase {
            case .covered:
                PrivacyCover().transition(.opacity)
            case .locked:
                LockView { Task { await lock.attemptUnlock() } }.transition(.opacity)
            case .unlocked:
                EmptyView()
            }
        }
        .animation(DSMotion.fast, value: lock.phase)
        .onChange(of: lock.enabled) { _, isOn in
            UserDefaults.standard.set(isOn, forKey: "appLockEnabled")
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await lock.didBecomeActive() }
            case .inactive, .background:
                lock.willResignActive()
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder private var main: some View {
        #if DEBUG
        if DebugLaunch.openSampleEditor {
            NavigationStack { EditorView(note: Note()) }
        } else if DebugLaunch.openAbout {
            NavigationStack { AboutView() }
        } else if DebugLaunch.openPrivacy {
            NavigationStack { PrivacyView() }
        } else {
            routed
        }
        #else
        routed
        #endif
    }

    @ViewBuilder private var routed: some View {
        if hasCompletedWelcome {
            HomeView()
                .task { try? SwiftDataNoteStore(context: context).purgeDeleted() }
        } else {
            WelcomeView(onContinue: { hasCompletedWelcome = true })
        }
    }
}
