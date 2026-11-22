import SwiftUI

struct ComparisonStoresStep: View {
    let model: OnboardingModel
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        let base = model.answers.usualStore

        OnboardingScaffold(
            step: .comparisonStores,
            title: "¿En cuáles te gustaría comprar?",
            subtitle: "Elige las que te queden cómodas. Cotizamos la misma canasta en cada una.",
            onBack: onBack,
            footer: {
                GlassProminentButton("Continuar", action: model.continueFromComparisonStores)
                    .disabled(model.answers.comparisonStores.isEmpty)
            },
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    if let notice = base?.unsupportedNotice {
                        Label(notice, systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(colors.textPrimary)
                            .padding(AppSpacing.large)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colors.cellBackground, in: .rect(cornerRadius: AppRadius.large))
                    }

                    ForEach(StoreChoice.supported, id: \.self) { store in
                        OnboardingOptionRow(
                            title: store.title,
                            logoAssetName: store.logoAssetName,
                            detail: store == base ? "Donde compras normalmente" : nil,
                            isSelected: model.answers.comparisonStores.contains(store)
                        ) {
                            model.toggleComparisonStore(store)
                        }
                    }

                    Text("Próximamente")
                        .font(.headline)
                        .foregroundStyle(colors.textSecondary)
                        .padding(.top, AppSpacing.medium)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(StoreChoice.comingSoon, id: \.self) { store in
                        OnboardingOptionRow(
                            title: store.title,
                            logoAssetName: store.logoAssetName,
                            detail: "Aún no tenemos sus precios",
                            isEnabled: false,
                            isSelected: false
                        ) {}
                    }
                }
                .sensoryFeedback(.selection, trigger: model.answers.comparisonStores.count)
            }
        )
        .onAppear { OnboardingEvent.stepViewed(.comparisonStores).log() }
    }
}
