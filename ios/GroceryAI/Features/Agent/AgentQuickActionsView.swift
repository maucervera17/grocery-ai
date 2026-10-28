import SwiftUI

struct AgentQuickActionsView: View {
    let canRepeatLastOrder: Bool
    let onRepeatLastOrder: () -> Void
    let onAddFrequentProducts: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: AppSpacing.small) {
                SuggestionChip(
                    "Repetir última compra",
                    systemImage: "arrow.counterclockwise",
                    action: onRepeatLastOrder
                )
                .disabled(!canRepeatLastOrder)

                SuggestionChip(
                    "Agregar lo de siempre",
                    systemImage: "plus.circle",
                    action: onAddFrequentProducts
                )
            }
            .padding(.horizontal, AppSpacing.large)
        }
        .scrollIndicators(.hidden)
    }
}
