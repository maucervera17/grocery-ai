import SwiftUI

struct ChatMessageBubble: View {
    let message: ChatMessage

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(alignment: .bottom, spacing: AppSpacing.small) {
            if message.role == .user { Spacer(minLength: 48) }

            if message.role == .agent {
                AgentAvatarView()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: AppSpacing.extraSmall) {
                Text(message.text)
                    .font(.body)

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(colors.textPrimary)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
            .background(
                message.role == .user ? colors.brandSecondary : colors.surfacePrimary,
                in: .rect(cornerRadius: AppRadius.large)
            )
            .overlay {
                if message.role == .agent {
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(colors.borderSubtle)
                }
            }

            if message.role == .agent { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message.role == .agent ? "Asistente: \(message.text)" : "Tú: \(message.text)")
    }
}
