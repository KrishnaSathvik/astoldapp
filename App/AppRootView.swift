import SwiftUI

/// Routes first-run Welcome → Home. No tab bar (docs/03-design-system.md §3).
struct AppRootView: View {
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false

    var body: some View {
        Group {
            #if DEBUG
            if DebugLaunch.openSampleEditor {
                NavigationStack { EditorView(note: Note()) }
            } else {
                routed
            }
            #else
            routed
            #endif
        }
    }

    @ViewBuilder private var routed: some View {
        if hasCompletedWelcome {
            HomeView()
        } else {
            WelcomeView(onContinue: { hasCompletedWelcome = true })
        }
    }
}

#Preview { AppRootView() }
