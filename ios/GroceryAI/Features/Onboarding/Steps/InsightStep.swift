import SwiftUI

struct InsightStep: View {
    let habit: CompareHabit?
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false

    private var headline: String {
        switch habit {
        case .never: "La misma canasta puede costar $186 más"
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
            VStack(spacing: AppSpacing.extraLarge) {
                HStack(alignment: .top, spacing: AppSpacing.medium) {
                    miniReceipt(
                        store: "Bodega Aurrera",
                        city: "Mérida",
                        total: "$734",
                        stamp: "Más barata",
                        colors: colors
                    )
                    miniReceipt(
                        store: "Walmart",
                        city: "Naucalpan",
                        total: "$920.50",
                        extraHeight: 44,
                        colors: colors
                    )
                    .padding(.top, AppSpacing.extraLarge)
                }
                .frame(maxWidth: .infinity)

                Text("$186.50 de diferencia")
                    .font(.title3.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(colors.textPrimary)

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

    private func miniReceipt(
        store: String,
        city: String,
        total: String,
        stamp: String? = nil,
        extraHeight: CGFloat = 0,
        colors: AppThemeColors
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store)
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(city)
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
            }
            .padding(.trailing, 0)

            Text("24 productos")
                .font(.footnote)
                .foregroundStyle(colors.textSecondary)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                Text("Total")
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
                Text(total)
                    .font(.title2.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(colors.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(height: 168 + extraHeight)
        .padding(AppSpacing.medium)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ReceiptPaperShape()
                .fill(
                    colorScheme == .dark
                        ? colors.surfaceElevated
                        : colors.surfacePrimary
                )
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.08),
                    radius: 10, y: 4
                )
        }
        .clipShape(ReceiptPaperShape())
        .overlay(alignment: .topTrailing) {
            if let stamp {
                Text(stamp)
                    .font(.caption2.bold())
                    .foregroundStyle(
                        colorScheme == .dark
                            ? colors.statusSuccess
                            : Color(red: 0.082, green: 0.478, blue: 0.22)
                    )
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.extraSmall)
                    .background(colors.statusSuccess.opacity(0.14), in: .capsule)
                    .overlay {
                        Capsule()
                            .stroke(colors.backgroundPrimary, lineWidth: 2)
                    }
                    .offset(x: AppSpacing.small, y: -AppSpacing.small)
            }
        }
    }
}
