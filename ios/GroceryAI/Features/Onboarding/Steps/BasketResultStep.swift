import SwiftUI

struct BasketResultStep: View {
    let model: OnboardingModel
    let onContinue: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var isShowingSpendOptions = false

    private var answers: OnboardingAnswers { model.answers }
    private var estimate: BasketEstimate? { model.basketEstimate }

    private var householdSentence: String {
        let household = (answers.householdSize ?? .threeFour).householdPhrase
        let cadence = (answers.shoppingFrequency ?? .weekly).cadencePhrase
        return "\(household) que compra \(cadence)"
    }

    private var title: String {
        if model.accessSkipped { return "Sin contraseña no vemos precios" }
        guard let estimate, !model.basketFailed else { return "No pudimos consultar los precios" }
        if let base = model.displayedFigures.base, let store = estimate.baseStore {
            return "Unos \(Self.pesos(base)) al mes en \(store.title)"
        }
        return "Tu canasta en \(StoreChoice.joinedTitles(estimate.comparisonStores))"
    }

    var body: some View {
        OnboardingScaffold(
            step: .basketResult,
            title: title,
            onBack: nil,
            footer: {
                if model.basketFailed && !model.accessSkipped {
                    VStack(spacing: AppSpacing.small) {
                        GlassProminentButton("Intentar de nuevo", action: model.retryBasketQuote)
                        Button("Seguir sin precios", action: onContinue)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget)
                    }
                } else {
                    GlassProminentButton("Continuar", action: onContinue)
                }
            },
            content: { content }
        )
        .confirmationDialog(
            "¿Cuánto gastas al mes en el súper?",
            isPresented: $isShowingSpendOptions,
            titleVisibility: .visible
        ) {
            ForEach(SpendRange.allCases.filter { $0 != .unsure }, id: \.self) { range in
                Button(range.title) { model.answers.spendAdjustment = range }
            }
            if answers.spendAdjustment != nil {
                Button("Usar la estimación de la canasta") { model.answers.spendAdjustment = nil }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .onAppear { OnboardingEvent.stepViewed(.basketResult).log() }
    }

    @ViewBuilder
    private var content: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(alignment: .leading, spacing: AppSpacing.large) {
            if model.accessSkipped {
                bodyText("Para cotizar tu canasta necesitas tu contraseña de acceso. Sin ella no te mostramos cifras: no inventamos precios. Puedes agregarla después en Ajustes.")
                bodyText("Te dejamos una lista sugerida para que pruebes Barasu.")
            } else if let estimate, !model.basketFailed {
                summary(estimate)
                if estimate.baseStore != nil, estimate.baseIsSupported {
                    Button {
                        isShowingSpendOptions = true
                    } label: {
                        Text(answers.spendAdjustment == nil ? "¿Gastas más o menos?" : "Ajustado a lo que gastas · Cambiar")
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.brandPrimary)
                    .frame(minHeight: AppControlSize.minimumTapTarget)
                }
                productDetail(estimate)
                footnote(estimate)
            } else {
                bodyText("Revisa tu conexión e intenta de nuevo. También puedes seguir y comparar más tarde desde el Agente.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func summary(_ estimate: BasketEstimate) -> some View {
        let colors = theme.colors(for: colorScheme)
        let figures = model.displayedFigures
        let chosen = StoreChoice.joinedTitles(estimate.comparisonStores)

        if let base = figures.base, let store = estimate.baseStore {
            let perTrip = Self.pesos(estimate.perTripCents(base))
            bodyText(answers.spendAdjustment == nil
                ? "\(householdSentence) gasta unos \(Self.pesos(base)) al mes en \(store.title) en estos \(estimate.rows.count) básicos, unos \(perTrip) por compra."
                : "Con lo que nos dijiste, gastas unos \(Self.pesos(base)) al mes en \(store.title), unos \(perTrip) por compra.")
        } else if let notice = estimate.baseStore?.unsupportedNotice {
            bodyText(notice)
        }

        VStack(spacing: 0) {
            if let base = figures.base, let store = estimate.baseStore {
                row("En \(store.title)", "\(Self.pesos(base))/mes")
                Divider()
            }
            if let value = figures.chosen {
                row(
                    estimate.comparisonStores.count > 1
                        ? "Comprando cada producto donde está más barato entre \(chosen)"
                        : "Comprando en \(chosen)",
                    "\(Self.pesos(value))/mes"
                )
            }
            if let savings = figures.savings {
                Divider()
                if savings > 0 {
                    row("Te ahorras", "\(Self.pesos(savings))/mes", highlight: true)
                } else {
                    row("Ahorro", "Ya compras en la opción más barata")
                }
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .background(colors.cellBackground, in: .rect(cornerRadius: AppRadius.large))

        if estimate.baseStore?.isSupportedByBarasu == false {
            VStack(spacing: 0) {
                ForEach(estimate.storeTotals) { total in
                    row("\(total.name) · \(total.pricedCount) productos", "\(Self.pesos(total.monthlyCents))/mes")
                    if total.id != estimate.storeTotals.last?.id { Divider() }
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .background(colors.cellBackground, in: .rect(cornerRadius: AppRadius.large))
        }
    }

    private func productDetail(_ estimate: BasketEstimate) -> some View {
        let colors = theme.colors(for: colorScheme)
        let stores = estimate.storeTotals

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ForEach(estimate.rows) { row in
                    VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                        Text(row.item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colors.textPrimary)
                        Text("\(Self.packages(row.monthlyPackages, perKilo: row.item.soldPerKilo)) al mes")
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                        ForEach(stores) { store in
                            let price = row.prices[store.retailerID] ?? nil
                            HStack(alignment: .firstTextBaseline) {
                                Text(store.name)
                                Spacer(minLength: AppSpacing.small)
                                Text(price.map { DisplayPriceFormatter.string(cents: $0) } ?? "No disponible en esta tienda")
                                    .foregroundStyle(price == nil ? colors.textSecondary : colors.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .font(.footnote)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, AppSpacing.medium)
        } label: {
            Text("Ver los \(estimate.rows.count) productos de la canasta")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline.weight(.semibold))
        .tint(colors.brandPrimary)
    }

    private func footnote(_ estimate: BasketEstimate) -> some View {
        let colors = theme.colors(for: colorScheme)
        var parts: [String] = []
        let kind = estimate.isDemo ? "Precios de demostración" : "Precios publicados en línea"
        if let date = estimate.pricesCheckedAt {
            parts.append("\(kind) del \(Self.dateFormatter.string(from: date)). Pueden variar en tu sucursal; confirma en tienda.")
        } else {
            parts.append("\(kind). Pueden variar en tu sucursal; confirma en tienda.")
        }
        if estimate.comparableItemCount < estimate.rows.count {
            parts.append("Solo sumamos los \(estimate.comparableItemCount) productos que encontramos en las tiendas comparadas; nunca estimamos un precio que no vimos.")
        }
        if answers.spendAdjustment != nil {
            parts.append("Cifras ajustadas a lo que nos dijiste que gastas, con la diferencia de precios de la canasta.")
        }
        parts.append("Profeco encontró que la misma canasta cambia de precio entre súpers de una misma ciudad.")
        return Text(parts.joined(separator: " "))
            .font(.footnote)
            .foregroundStyle(colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.body)
            .foregroundStyle(theme.colors(for: colorScheme).textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        let colors = theme.colors(for: colorScheme)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                Text(label).foregroundStyle(colors.textPrimary)
                Spacer(minLength: AppSpacing.small)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(highlight ? colors.statusSuccess : colors.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                Text(label).foregroundStyle(colors.textPrimary)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(highlight ? colors.statusSuccess : colors.textPrimary)
            }
        }
        .font(.callout)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.medium)
        .accessibilityElement(children: .combine)
    }

    static func pesos(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_MX")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: (Double(cents) / 100).rounded())) ?? "$\(cents / 100)"
    }

    static func packages(_ value: Double, perKilo: Bool = false) -> String {
        let rounded = (value * 2).rounded() / 2
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        if perKilo { return "\(text) kg" }
        return rounded == 1 ? "1 paquete" : "\(text) paquetes"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy"
        return formatter
    }()
}
