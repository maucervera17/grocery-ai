import SwiftUI
import SwiftData

@main
struct GroceryAIApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: LocalAppStateRecord.self)
    }
}

