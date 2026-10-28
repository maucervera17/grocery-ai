import SwiftUI

struct AddProductsButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: "plus", action: action)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
    }
}
