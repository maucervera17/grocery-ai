import SwiftUI

struct InsightStep: View {
    let habit: CompareHabit?
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false

    private static let cityGaps: [(city: String, percent: String, gap: String)] = [
        ("Ciudad de México", "4.3% más cara", "$34.80"),
        ("Villahermosa", "6.3% más cara", "$49.30"),
        ("Monterrey", "8.7% más cara", "$70.38")
    ]

    private var headline: String {
        switch habit {
        case .never: "En tu misma ciudad, la misma canasta puede costar hasta $70 más"
        case .always: "Comparar vale la pena, pero toma tiempo"
        default: "Las ofertas cambian cada semana"
        }
    }

    private var subtitle: String {
        switch habit {
        case .never: "Comprar siempre en la misma tienda puede salirte caro"
        case .always: "Barasu compara por ti en segundos"
        default: "Barasu las revisa por ti"
        }
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: .insight,
            title: headline,
            subtitle: subtitle,
            onBack: onBack,
            layout: .centered,
            footer: {
            GlassProminentButton("Continuar", action: onContinue)
            },
            content: {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ReceiptView(
                    title: "Misma canasta, misma ciudad",
                    lines: Self.cityGaps.map {
                        ReceiptView.Line(label: $0.city, secondary: $0.percent, price: $0.gap)
                    },
                    footerText: "Diferencia entre la tienda más barata y la más cara de cada ciudad, con la misma canasta de 24 productos."
                )

                Text("Profeco, Quién es Quién en los Precios, sept. 2026.")
                    .font(.caption)
                    .foregroundStyle(colors.textSecondary)
            }
            .opacity(shown ? 1 : 0)
            }
        )
        .onAppear {
            if reduceMotion {
                shown = true
            } else {
                withAnimation(.easeOut(duration: 0.35)) { shown = true }
            }
        }
    }
}
