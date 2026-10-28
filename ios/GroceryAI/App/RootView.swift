import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState()
    @State private var composerState = AgentComposerState()

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Agente", systemImage: "bubble.left.and.bubble.right", value: AppTab.agent) {
                NavigationStack {
                    AgentView(appState: appState, composerState: composerState)
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
        .scrollEdgeEffectStyle(.soft, for: .all)
        .tint(BarasuPalette.accent)
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
