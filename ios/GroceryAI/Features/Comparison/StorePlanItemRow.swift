import SwiftUI

struct StorePlanItemRow: View {
    let item: StorePlanItem
    let currencyCode: String

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                    Text(item.productName)
                        .font(.body.weight(.semibold))

                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(colors.textSecondary)
                    }
                }

                Spacer(minLength: AppSpacing.medium)

                Text(MoneyFormatter.string(cents: item.lineTotalCents, currencyCode: currencyCode))
                    .font(.body.weight(.semibold))
            }

            Text(packageDescription)
                .font(.subheadline)
                .foregroundStyle(colors.textSecondary)

            HStack(spacing: AppSpacing.small) {
                DataStatusBadge(status: item.dataStatus)

                if item.matchType.rawValue == "similar" {
                    Text("Sustituto")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.extraSmall)
                        .background(colors.statusWarning.opacity(0.16), in: .capsule)
                        .foregroundStyle(colors.statusWarning)
                }
            }

            DisclosureGroup("Detalles") {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Label(
                        "Solicitado: \(ProductQuantityFormatter.string(quantity: item.requestedQuantity, unit: item.requestedUnit))",
                        systemImage: "cart"
                    )

                    if let unitPriceDescription {
                        Label(unitPriceDescription, systemImage: "scalemass")
                    }

                    if let regularPrice = item.regularPriceCents, regularPrice > item.priceCents {
                        Label(
                            "Regular: \(MoneyFormatter.string(cents: regularPrice, currencyCode: currencyCode))",
                            systemImage: "tag"
                        )
                    }

                    HStack {
                        Label(
                            item.checkedAt.formatted(date: .abbreviated, time: .shortened),
                            systemImage: "clock"
                        )

                        Spacer()

                        Link("Fuente", destination: item.productURL)
                    }
                }
                .font(.caption)
                .foregroundStyle(colors.textSecondary)
                .padding(.top, AppSpacing.small)
            }
            .font(.caption.weight(.medium))
            .tint(colors.brandPrimary)
        }
        .accessibilityElement(children: .contain)
    }

    private var packageDescription: String {
        let packageSize = ProductQuantityFormatter.string(
            quantity: item.packageQuantity,
            unit: item.packageUnit
        )
        return "\(item.packageCount) × \(packageSize) · \(MoneyFormatter.string(cents: item.priceCents, currencyCode: currencyCode)) c/u"
    }

    private var unitPriceDescription: String? {
        guard let cents = item.unitPriceCentsPer100 else { return nil }

        let baseUnit: String
        switch item.packageUnit {
        case .gram, .kilogram:
            baseUnit = "g"
        case .milliliter, .liter:
            baseUnit = "ml"
        case .piece:
            baseUnit = "piezas"
        case .package, .dozen:
            baseUnit = "unidades"
        }

        return "\(MoneyFormatter.string(cents: cents, currencyCode: currencyCode)) por 100 \(baseUnit)"
    }
}
