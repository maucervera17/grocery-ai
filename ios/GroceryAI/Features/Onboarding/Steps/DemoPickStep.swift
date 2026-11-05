import SwiftUI

struct DemoPickStep: View {
    let model: OnboardingModel
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedIDs: [UUID] = []

    private static let preferredNames = ["leche", "huevo", "arroz"]

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: .demoPick,
            title: "Probemos con 2 productos",
            subtitle: "Te mostramos dónde están más baratos ahora mismo.",
            onBack: onBack,
            footer: {
            GlassProminentButton(
                model.accessSkipped ? "Continuar" : "Comparar precios",
                systemImage: model.accessSkipped ? nil : "cart.badge.questionmark"
            ) {
                model.demoItems = model.answers.importedItems
                    .filter { selectedIDs.contains($0.id) }
                model.advance(from: .demoPick)
            }
            .disabled(selectedIDs.isEmpty)
            },
            content: {
            VStack(spacing: AppSpacing.small) {
                ForEach(model.answers.importedItems) { product in
                    row(for: product, colors: colors)
                }
            }
            }
        )
        .onAppear { preselect() }
    }

    private func row(for product: ProductRequest, colors: AppThemeColors) -> some View {
        let isSelected = selectedIDs.contains(product.id)

        return Button {
            toggle(product.id)
        } label: {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? colors.brandPrimary : colors.textSecondary)
                    .accessibilityHidden(true)

                ProductThumbnail(
                    imageURL: nil,
                    category: product.categoryID ?? .inferred(from: product.name),
                    size: 44
                )

                VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                    Text(ProductNameFormatter.display(product.name))
                        .font(.body.weight(.medium))
                        .foregroundStyle(colors.textPrimary)
                    Text(product.quantityDescription)
                        .font(.subheadline)
                        .foregroundStyle(colors.textSecondary)
                }
                Spacer()
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget, alignment: .leading)
            .background(
                isSelected ? colors.brandSecondary : colors.cellBackground,
                in: .rect(cornerRadius: AppRadius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(
                        isSelected ? colors.brandPrimary : colors.borderSubtle,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ProductNameFormatter.display(product.name)), \(product.quantityDescription)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private func toggle(_ id: UUID) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
            if selectedIDs.count > 2 {
                selectedIDs.removeFirst()
            }
        }
    }

    private func preselect() {
        guard selectedIDs.isEmpty else { return }
        let items = model.answers.importedItems
        let preferred = Self.preferredNames.compactMap { needle in
            items.first {
                $0.name.folding(
                    options: [.diacriticInsensitive, .caseInsensitive],
                    locale: Locale(identifier: "es_MX")
                ).contains(needle)
            }
        }
        var picked = preferred.map(\.id)
        for item in items where picked.count < 2 && !picked.contains(item.id) {
            picked.append(item.id)
        }
        selectedIDs = Array(picked.prefix(2))
    }
}
