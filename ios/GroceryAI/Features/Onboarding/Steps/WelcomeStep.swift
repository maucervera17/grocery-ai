import SwiftUI

struct WelcomeStep: View {
    let onStart: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visibleBeats = 0

    private static let loopStores: [StorePlan] = [
        StorePlan(
            retailerID: .chedraui,
            retailer: "Chedraui",
            subtotalCents: 20_650,
            items: [MockFixtures.milkLine, MockFixtures.eggsLine, MockFixtures.riceLine]
        ),
        StorePlan(
            retailerID: .bodegaAurrera,
            retailer: "Bodega Aurrera",
            subtotalCents: 19_990,
            items: [MockFixtures.milkLine, MockFixtures.eggsLine, MockFixtures.riceLine]
        ),
        StorePlan(
            retailerID: .walmart,
            retailer: "Walmart",
            subtotalCents: 21_300,
            items: [MockFixtures.milkLine, MockFixtures.eggsLine, MockFixtures.riceLine]
        )
    ]

    private var sortedStores: [StorePlan] {
        Self.loopStores.sorted { $0.subtotalCents < $1.subtotalCents }
    }

    private var winningStoreID: UUID? {
        sortedStores.first?.id
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                ScrollView {
                    conversation(width: proxy.size.width)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.horizontal, AppSpacing.extraLarge)
                        .padding(.bottom, AppSpacing.extraLarge)
                }
                .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(colors.backgroundPrimary)
        .safeAreaInset(edge: .bottom) {
            GlassProminentButton("Empezar", action: onStart)
                .padding(.horizontal, AppSpacing.extraLarge)
                .padding(.vertical, AppSpacing.medium)
        }
        .navigationBarBackButtonHidden(true)
        .task { playOnce() }
        .onAppear { OnboardingEvent.stepViewed(.welcome).log() }
    }

    private var header: some View {
        let colors = theme.colors(for: colorScheme)

        return VStack(spacing: AppSpacing.extraLarge) {
            Image(.brandLaunchLogo)
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .padding(.top, AppSpacing.medium)

            VStack(spacing: AppSpacing.small) {
                Text("Tu súper, al mejor precio.")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Escribe tu lista y Barasu compara Walmart, Bodega Aurrera y Chedraui por ti.")
                    .font(AppTypography.body)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, AppSpacing.extraLarge)
        .padding(.bottom, AppSpacing.medium)
    }

    @ViewBuilder
    private func conversation(width: CGFloat) -> some View {
        let colors = theme.colors(for: colorScheme)
        let replyWidth = width * 0.88

        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if visibleBeats >= 1 {
                Text("Leche, huevos, arroz y papel de baño")
                    .font(.body)
                    .foregroundStyle(colors.textPrimary)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.medium)
                    .background(colors.brandSecondary, in: .rect(cornerRadius: AppRadius.large))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            if visibleBeats >= 2 {
                agentReply(width: replyWidth) {
                    VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                        ForEach(MockFixtures.draft.items + [MockFixtures.toiletPaper]) { product in
                            HStack(spacing: AppSpacing.medium) {
                                ProductThumbnail(
                                    imageURL: nil,
                                    category: product.categoryID ?? .other,
                                    size: 36
                                )
                                Text(product.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(colors.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .layoutPriority(1)
                                Spacer()
                                Text(product.quantityDescription)
                                    .font(.caption)
                                    .foregroundStyle(colors.textSecondary)
                                    .fixedSize()
                            }
                        }
                    }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            if visibleBeats >= 3 {
                agentReply(width: replyWidth, showAvatar: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        ForEach(sortedStores) { store in
                            storeRow(store)
                        }
                        Text("Ejemplo con precios ilustrativos")
                            .font(.caption)
                            .foregroundStyle(colors.textSecondary)
                    }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .smooth, value: visibleBeats)
    }

    private func agentReply<Content: View>(
        width: CGFloat,
        showAvatar: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let colors = theme.colors(for: colorScheme)

        return HStack(alignment: .top, spacing: AppSpacing.small) {
            if showAvatar {
                AgentAvatarView()
            } else {
                Spacer()
                    .frame(width: AppControlSize.minimumTapTarget)
            }
            content()
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.large)
                .padding(.bottom, AppSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.surfacePrimary, in: .rect(cornerRadius: AppRadius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(colors.borderSubtle)
                }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func storeRow(_ store: StorePlan) -> some View {
        let colors = theme.colors(for: colorScheme)
        let isWinner = store.id == winningStoreID

        return HStack(spacing: AppSpacing.medium) {
            RetailerLogo(
                retailerID: store.retailerID ?? .unknown,
                retailerName: store.retailer
            )
            .scaleEffect(0.75)
            .frame(width: 36, height: 24)
            Text(store.retailer)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(colors.textPrimary)
                .fixedSize()
            Spacer(minLength: AppSpacing.small)
            Text(DisplayPriceFormatter.string(cents: store.subtotalCents))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(colors.textPrimary)
                .fixedSize()
        }
        .padding(AppSpacing.medium)
        .background(colors.cellBackground, in: .rect(cornerRadius: AppRadius.medium))
        .overlay(alignment: .topTrailing) {
            if isWinner {
                Label("Mejor opción", systemImage: "checkmark.seal.fill")
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
                            .stroke(colors.surfacePrimary, lineWidth: 2)
                    }
                    .offset(y: -AppSpacing.medium)
            }
        }
        .padding(.top, AppSpacing.small)
    }

    private func playOnce() {
        if reduceMotion {
            visibleBeats = 3
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            for beat in 1...3 {
                withAnimation(.smooth) { visibleBeats = beat }
                try? await Task.sleep(for: .milliseconds(750))
            }
        }
    }
}
