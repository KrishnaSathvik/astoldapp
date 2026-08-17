import SwiftUI
import SwiftData

@main
struct YourlyApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try NoteStoreContainer.make()
        } catch {
            fatalError("Failed to create the note store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
            #if DEBUG
                .modelContainerSeeding()
            #endif
        }
        .modelContainer(container)
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
