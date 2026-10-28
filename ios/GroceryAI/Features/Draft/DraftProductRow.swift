import SwiftUI

struct DraftProductRow: View {
    let product: ProductRequest
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        Button(action: onEdit) {
            HStack(spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                    Text(product.name)
                        .font(.body.weight(.medium))
                    Text(product.quantityDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget, alignment: .leading)
            .background(colors.backgroundSecondary, in: .rect(cornerRadius: AppRadius.medium))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("Eliminar", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .contextMenu {
            Button("Editar", systemImage: "pencil", action: onEdit)
            Button("Eliminar", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
