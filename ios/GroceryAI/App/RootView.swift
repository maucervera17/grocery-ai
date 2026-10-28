import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState()

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Lista", systemImage: "sparkles", value: AppTab.agent) {
                NavigationStack {
                    AgentView(appState: appState)
                }
            }

            Tab("Ahorro",systemImage:"chart.bar",value:AppTab.savings) {
                NavigationStack { SavingsStatisticsView(ledger:appState.savings,onDelete:appState.deletePurchase) }
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
