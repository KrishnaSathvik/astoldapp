import SwiftUI
import SwiftData

@main
struct YourlyApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
            #if DEBUG
                .modelContainerSeeding()
            #endif
        }
        .modelContainer(for: Note.self)
    }
}

#if DEBUG
private struct SeedOnAppear: ViewModifier {
    @Environment(\.modelContext) private var context
    func body(content: Content) -> some View {
        content.task { DebugLaunch.seedIfRequested(context) }
    }
}
private extension View {
    func modelContainerSeeding() -> some View { modifier(SeedOnAppear()) }
}
#endif
