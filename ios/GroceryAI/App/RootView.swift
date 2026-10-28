import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState()

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Agente", systemImage: "bubble.left.and.bubble.right", value: AppTab.agent) {
                NavigationStack {
                    AgentView(appState: appState)
                }
            }

            Tab("Historial", systemImage: "clock", value: AppTab.history) {
                NavigationStack {
                    HistoryView(
                        orders: appState.orders,
                        frequentProducts: appState.frequentProducts,
                        onRepeatOrder: appState.repeatOrder
                    )
                }
            }
        }
        .tint(AppTheme.grocery.lightColors.brandPrimary)
        .environment(\.appTheme, .grocery)
        .task {
            appState.configurePersistence(modelContext)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: LocalAppStateRecord.self, inMemory: true)
}
