import SwiftUI

@main
struct LexiApp: App {
    @State private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
    }
}
