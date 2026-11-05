import SwiftUI

struct BenefitsStep: View {
    let answers: OnboardingAnswers
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visibleBeats = 0

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: .benefits,
            title: "Así funciona Barasu",
            onBack: onBack,
            layout: .centered,
            footer: {
            GlassProminentButton("Probar con mi lista", action: onContinue)
            },
            content: {
            VStack(alignment: .leading, spacing: 0) {
                beat(
                    index: 1,
                    title: "Escribe, dicta o pega tu lista",
                    subtitle: "Barasu reconoce cada producto",
                    colors: colors
                ) {
                    VStack(alignment: .trailing, spacing: AppSpacing.small) {
                        Text("Leche, huevos y arroz")
                            .font(.callout)
                            .foregroundStyle(colors.textPrimary)
                            .padding(.horizontal, AppSpacing.medium)
                            .padding(.vertical, AppSpacing.small)
                            .background(colors.brandSecondary, in: .rect(cornerRadius: AppRadius.large))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        HStack(alignment: .bottom, spacing: AppSpacing.small) {
                            AgentAvatarView()
                            Text("3 productos agregados")
                                .font(.callout)
                                .foregroundStyle(colors.textPrimary)
                                .padding(.horizontal, AppSpacing.medium)
                                .padding(.vertical, AppSpacing.small)
                                .background(colors.surfacePrimary, in: .rect(cornerRadius: AppRadius.large))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.large)
                                        .stroke(colors.borderSubtle)
                                }
                            Spacer()
                        }
                    }
                }
                if visibleBeats >= 1 { divider(colors: colors) }
                beat(
                    index: 2,
                    title: "Comparamos 3 súpers",
                    subtitle: "Cada producto donde está más barato",
                    colors: colors
                ) {
                    ReceiptView(
                        lines: [
                            .init(label: "Bodega Aurrera", price: "$199.90", logoAssetName: "RetailerBodegaAurrera"),
                            .init(label: "Chedraui", price: "$206.50", logoAssetName: "RetailerChedraui"),
                            .init(label: "Walmart", price: "$213", logoAssetName: "RetailerWalmart")
                        ],
                        stamp: "Más barata",
                        footerText: "Ejemplo con precios ilustrativos"
                    )
                }
                if visibleBeats >= 2 { divider(colors: colors) }
                beat(
                    index: 3,
                    title: "Repite tu compra",
                    subtitle: "Tu lista de la semana pasada, en un toque",
                    colors: colors
                ) {
                    HStack(spacing: AppSpacing.medium) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body)
                            .foregroundStyle(colors.brandPrimary)
                            .frame(width: 40, height: 40)
                            .background(colors.backgroundSecondary, in: .circle)
                            .accessibilityHidden(true)
                        Text("Compra semanal · 14 productos")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(colors.textPrimary)
                        Spacer()
                        Text("Repetir")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colors.brandPrimary)
                    }
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.medium)
                    .background(colors.cellBackground, in: .rect(cornerRadius: 22, style: .continuous))
                }
            }
            }
        )
        .task { appear() }
    }

    private func divider(colors: AppThemeColors) -> some View {
        Rectangle()
            .fill(colors.borderSubtle)
            .frame(height: 0.5)
            .padding(.vertical, AppSpacing.medium)
    }

    private func beat<Visual: View>(
        index: Int,
        title: String,
        subtitle: String,
        colors: AppThemeColors,
        @ViewBuilder visual: () -> Visual
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(colors.brandSecondary)
                        .frame(width: 28, height: 28)
                    Text("\(index)")
                        .font(.footnote.weight(.semibold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(colors.brandPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(colors.textPrimary)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(colors.textSecondary)
                }
            }
            visual()
        }
        .opacity(visibleBeats >= index ? 1 : 0)
        .accessibilityElement(children: .contain)
    }

    private func appear() {
        if reduceMotion {
            visibleBeats = 3
            return
        }
        Task { @MainActor in
            for beat in 1...3 {
                withAnimation(.easeOut(duration: 0.35)) { visibleBeats = beat }
                try? await Task.sleep(for: .milliseconds(450))
            }
        }
    }
}
