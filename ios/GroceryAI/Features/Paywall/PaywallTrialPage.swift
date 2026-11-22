import SwiftUI
import UserNotifications

struct PaywallTrialPage: View {
    let annualPriceText: String
    var dates: PaywallDates = .init()
    let onBack: () -> Void
    let onContinue: () -> Void

    var notificationStatusProvider: @Sendable () async -> UNAuthorizationStatus = {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
    var notificationAuthorizationRequester: @Sendable () async -> Bool = {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visibleNodes = 0

    private struct Node {
        let icon: String
        let title: String
        let subtitle: String
        let filled: Bool
    }

    private var nodes: [Node] {
        [
            Node(icon: "lock.open.fill", title: "Hoy", subtitle: "Acceso completo a Barasu", filled: true),
            Node(
                icon: "bell.fill",
                title: dates.formatted(dates.reminderDate),
                subtitle: "Te enviamos un aviso",
                filled: true
            ),
            Node(
                icon: "creditcard.fill",
                title: dates.formatted(dates.chargeDate),
                subtitle: "Se cobra tu plan anual de \(annualPriceText). Cancela antes y no pagas nada",
                filled: false
            )
        ]
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        PaywallPageScaffold(onBack: onBack) {
            VStack(alignment: .leading, spacing: AppSpacing.extraLarge) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Prueba 7 días gratis")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Sin pago hoy. Te avisamos antes de cobrar")
                        .font(.body)
                        .foregroundStyle(colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                        if index < visibleNodes {
                            HStack(alignment: .top, spacing: AppSpacing.medium) {
                                ZStack {
                                    Circle()
                                        .fill(node.filled ? colors.brandPrimary : colors.backgroundSecondary)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: node.icon)
                                        .font(.subheadline)
                                        .foregroundStyle(node.filled ? colors.brandOnPrimary : colors.textSecondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(node.title)
                                        .font(.headline)
                                        .foregroundStyle(colors.textPrimary)
                                    Text(node.subtitle)
                                        .font(.callout)
                                        .foregroundStyle(colors.textSecondary)
                                }
                                Spacer()
                            }
                            .transition(.opacity.combined(with: .offset(y: 8)))
                        }
                        if index < nodes.count - 1 {
                            Rectangle()
                                .fill(colors.brandPrimary.opacity(0.4))
                                .frame(width: 2, height: 24)
                                .padding(.leading, 17)
                        }
                    }
                }

                Text("Te pediremos permiso para enviarte el aviso")
                    .font(.caption)
                    .foregroundStyle(colors.textSecondary)

                Spacer(minLength: 0)
            }
        } footer: {
            GlassProminentButton("Continuar") {
                Task { @MainActor in
                    _ = await requestAuthorizationIfNeeded()
                    onContinue()
                }
            }
        }
        .task { appear() }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        guard await notificationStatusProvider() == .notDetermined else { return false }
        return await notificationAuthorizationRequester()
    }

    private func appear() {
        if reduceMotion {
            visibleNodes = nodes.count
            return
        }
        Task { @MainActor in
            for index in 1...nodes.count {
                withAnimation(.easeOut(duration: 0.35)) { visibleNodes = index }
                try? await Task.sleep(for: .milliseconds(180))
            }
        }
    }
}
