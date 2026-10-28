import SwiftUI

struct LocationFlowSheet: View {
    let appState: AppState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if appState.loadingState == .comparing {
                ComparisonLoadingView()
            } else {
                LocationRequestView(initialPostalCode: appState.postalCode) { postalCode in
                    Task { await appState.compare(postalCode: postalCode) }
                }
            }
        }
        .onChange(of: appState.comparisonPlan) {
            if appState.comparisonPlan != nil {
                dismiss()
            }
        }
    }
}
