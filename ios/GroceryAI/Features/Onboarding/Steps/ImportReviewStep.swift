import SwiftUI

struct ImportReviewStep: View {
    let model: OnboardingModel
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var editedProduct: ProductRequest?

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        let count = model.answers.importedItems.count

        OnboardingScaffold(
            step: .importReview,
            title: "Revisa tu lista",
            subtitle: "\(count) productos · toca uno para editarlo",
            onBack: onBack,
            footer: {
            GlassProminentButton("Se ve bien") {
                model.advance(from: .importReview)
            }
            .disabled(model.answers.importedItems.isEmpty || model.isImportingList)
            },
            content: {
            if model.isImportingList {
                HStack(spacing: AppSpacing.medium) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Leyendo tu lista…")
                        .font(.subheadline)
                        .foregroundStyle(colors.textSecondary)
                    Spacer()
                }
            } else if let message = model.importErrorMessage,
                      model.answers.importedItems.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    SecondaryButton("Intentar de nuevo", systemImage: "arrow.counterclockwise") {
                        model.importErrorMessage = nil
                        model.goBack()
                    }
                    SecondaryButton("Usar una lista sugerida", systemImage: "basket") {
                        model.applySuggestedList()
                    }
                }
            } else {
                VStack(spacing: AppSpacing.small) {
                    ForEach(model.answers.importedItems) { product in
                        row(product, colors: colors)
                    }
                }
            }
            }
        )
        .sheet(item: $editedProduct) { product in
            ProductEditorView(product: product) { updated in
                model.updateImportedItem(updated)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func row(_ product: ProductRequest, colors: AppThemeColors) -> some View {
        Button {
            editedProduct = product
        } label: {
            HStack(spacing: AppSpacing.medium) {
                ProductThumbnail(
                    imageURL: nil,
                    category: product.categoryID ?? .inferred(from: product.name),
                    size: 44
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(ProductNameFormatter.display(product.name))
                        .font(.body.weight(.medium))
                        .foregroundStyle(colors.textPrimary)
                    Text(product.quantityDescription)
                        .font(.subheadline)
                        .foregroundStyle(colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSpacing.large)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(colors.cellBackground, in: .rect(cornerRadius: 22, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("Eliminar", systemImage: "trash", role: .destructive) {
                if let index = model.answers.importedItems
                    .firstIndex(where: { $0.id == product.id }) {
                    model.removeImportedItems(at: IndexSet(integer: index))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
