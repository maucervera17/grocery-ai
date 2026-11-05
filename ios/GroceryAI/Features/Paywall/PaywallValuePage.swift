import SwiftUI

struct PaywallValuePage: View {
    let context: PaywallContext
    let onContinue: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var receiptLines: [ReceiptView.Line] {
        var lines: [ReceiptView.Line] = []
        if let household = context.householdLabel {
            lines.append(.init(label: "Hogar", price: household))
        }
        if let frequency = context.frequencyLabel {
            lines.append(.init(label: "Súper", price: frequency))
        }
        if let postalCode = context.postalCode {
            lines.append(.init(label: "Cerca de", price: "CP \(postalCode)"))
        }
        if context.listItemCount > 0 {
            lines.append(.init(label: "Tu lista", price: "\(context.listItemCount) productos"))
        }
        if let demoSavings = context.demoSavingsCents, demoSavings > 0 {
            lines.append(.init(
                label: "Tu prueba",
                price: "−\(DisplayPriceFormatter.string(cents: demoSavings))",
                priceIsSuccess: true
            ))
        }
        return lines
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        PaywallPageScaffold {
            VStack(spacing: AppSpacing.extraLarge) {
                Spacer(minLength: 0)

                VStack(spacing: AppSpacing.large) {
                    Image(.brandLaunchLogo)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                        .accessibilityHidden(true)

                    Text("Tu plan Barasu está listo")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity)

                ReceiptView(
                    title: "Tu plan",
                    lines: receiptLines,
                    totalLabel: "Ahorro estimado",
                    totalPrice: savingsText
                )

                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    ForEach(context.orderedBenefits, id: \.self) { benefit in
                        PaywallBenefitRow(benefit: benefit)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
        } footer: {
            GlassProminentButton("Continuar", action: onContinue)
        }
    }

    private var savingsText: String {
        guard let cents = context.estimatedMonthlySavingsHighCents, cents > 0 else {
            return "—"
        }
        return "hasta \(DisplayPriceFormatter.string(cents: cents))/mes"
    }
}

#Preview("Valor") {
    PaywallValuePage(context: .preview, onContinue: {})
}
