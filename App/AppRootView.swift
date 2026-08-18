import SwiftUI
import SwiftData

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
    @State private var themeStore = ThemeStore()

    var body: some View {
        ZStack {
            main
                .environment(lock)
                .environment(themeStore)

            switch lock.phase {
            case .covered:
                PrivacyCover().transition(.opacity)
            case .locked:
                LockView { Task { await lock.attemptUnlock() } }.transition(.opacity)
            case .unlocked:
                #if DEBUG
                if DebugLaunch.forceLocked { LockView(onUnlock: {}) }
                #endif
            }
        }
        .preferredColorScheme(themeStore.colorScheme)
        .animation(DSMotion.fast, value: lock.phase)
        // `onChange(of: scenePhase)` never fires for the scene's *initial* active value, so a cold
        // launch needs its own prompt — otherwise the lock screen would just sit there waiting.
        .task {
            // Sweep audio left behind by a crash/force-quit during a recording (RULES.md §3).
            AVAudioRecorderService.purgeAbandonedRecordings()
            await lock.didBecomeActive()
        }
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
        } else if DebugLaunch.openSeededNote {
            NavigationStack { SeededNoteEditor() }
        } else if DebugLaunch.openAbout {
            NavigationStack { AboutView() }
        } else if DebugLaunch.openPrivacy {
            NavigationStack { PrivacyView() }
        } else if DebugLaunch.openTheme {
            NavigationStack { ThemeView() }
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

#if DEBUG
/// Debug-only: routes straight into the newest existing note, for verifying the reading state.
private struct SeededNoteEditor: View {
    @Query(filter: #Predicate<Note> { $0.deletedAt == nil },
           sort: \Note.createdAt, order: .reverse)
    private var notes: [Note]

    var body: some View {
        if let note = notes.first { EditorView(note: note) }
    }
}
#endif
