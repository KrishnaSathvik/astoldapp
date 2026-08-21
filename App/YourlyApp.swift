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
        // Seeding happens *before* the first render, not from a `.task` after it.
        //
        // It used to run after, and `-openSeededNote` opened whatever note was in the store at that
        // moment — which, in a test run that had already put notes there, was one `-resetStore` was
        // about to delete. `EditorView` builds its `EditorModel` once, from the note it first sees, so
        // the editor then went on displaying a note that no longer existed while the store held the
        // seeded one. Reliably, and only ever when some earlier test had left a note behind, which is
        // why it read as a flake (2026-08-21).
        #if DEBUG
        DebugLaunch.seedIfRequested(container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(container)
    }
}
