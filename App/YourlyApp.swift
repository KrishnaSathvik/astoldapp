import SwiftUI
import SwiftData

@main
struct YourlyApp: App {
    var body: some Scene {
        WindowGroup { AppRootView() }
            .modelContainer(for: Note.self)
    }
}
