import SwiftUI

struct AgentComposerSuggestionsView: View {
    let hasDraft: Bool
    let hasOrders: Bool
    let onInsertText: (String) -> Void
    let onRepeatLastOrder: () -> Void
    let onShowOrders: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: AppSpacing.small) {
                if hasDraft {
                    SuggestionChip("Cambiar cantidad", systemImage: "slider.horizontal.3") {
                        onInsertText("Cambia ")
                    }
                    SuggestionChip("Quitar producto", systemImage: "minus.circle") {
                        onInsertText("Quita ")
                    }
                } else if hasOrders {
                    SuggestionChip(
                        "Repetir última compra",
                        systemImage: "arrow.counterclockwise",
                        action: onRepeatLastOrder
                    )
                    SuggestionChip("Elegir otra compra", systemImage: "clock", action: onShowOrders)
                } else {
                    SuggestionChip("2 L de leche y 12 huevos", systemImage: "sparkles") {
                        onInsertText("2 L de leche y 12 huevos")
                    }
                }
            }
            .padding(.horizontal, AppSpacing.large)
        }
        .scrollIndicators(.hidden)
    }
}
