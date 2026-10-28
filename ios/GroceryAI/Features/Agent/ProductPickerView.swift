import SwiftUI

struct ProductPickerView: View {
    @Binding var items: [SelectableProduct]
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Frecuentes")
                .font(.title3.bold())

            if filteredIndices.isEmpty {
                Text(searchText.isEmpty ? "Guarda una comparación para ver productos frecuentes." : "No hay productos frecuentes que coincidan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.large)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: AppSpacing.medium) {
                        ForEach(filteredIndices, id: \.self) { index in
                            FrequentProductCard(item: $items[index])
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
        .id(AddContentSection.products)
    }

    private var filteredIndices: [Int] {
        items.indices.filter { index in
            searchText.isEmpty || items[index].product.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}
