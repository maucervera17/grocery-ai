import SwiftUI

struct ChatMessageBubble: View {
    let message: ChatMessage

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            Text(message.text)
                .font(.body)
                .foregroundStyle(message.role == .user ? colors.brandOnPrimary : colors.textPrimary)
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.medium)
                .background(
                    message.role == .user ? colors.brandPrimary : colors.surfacePrimary,
                    in: .rect(cornerRadius: AppRadius.large)
                )

            if message.role == .agent { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(message.role == .agent ? "Asistente: \(message.text)" : "Tú: \(message.text)")
    }
}
