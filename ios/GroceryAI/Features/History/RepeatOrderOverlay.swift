import SwiftUI

struct RepeatOrderOverlay: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Repetir compra", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.horizontal, AppSpacing.large)
        .padding(.bottom, AppSpacing.medium)
    }
}
