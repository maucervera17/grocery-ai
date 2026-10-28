import SwiftUI

struct AgentComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let prompt: String
    let isLoading: Bool
    let onSend: () -> Void
    let onAddContent: () -> Void
    let voiceState: VoiceConversationState
    let voiceFeedback: String
    let onToggleVoice: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        GlassEffectContainer(spacing: AppSpacing.small) {
            HStack(alignment: .bottom, spacing: AppSpacing.small) {
                Button("Agregar a la conversación", systemImage: "plus", action: onAddContent)
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .frame(width: AppControlSize.composer, height: AppControlSize.composer)
                    .foregroundStyle(colors.brandPrimary)
                    .glassEffect(.regular.interactive(), in: .circle)

                HStack(spacing: AppSpacing.small) {
                    if voiceState.isActive {
                        VoiceStatusLabel(
                            state: voiceState,
                            feedback: voiceFeedback
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        TextField(voiceState.promptOverride ?? prompt, text: $text, axis: .vertical)
                            .lineLimit(1...4)
                            .focused(isFocused)
                            .submitLabel(.send)
                            .onSubmit(onSend)
                    }

                    VoiceComposerButton(state: voiceState, action: onToggleVoice)
                }
                .padding(.leading, AppSpacing.large)
                .padding(.trailing, AppSpacing.extraSmall)
                .frame(minHeight: AppControlSize.composer)
                .glassEffect(.regular.interactive(), in: .capsule)

                if !voiceState.isActive {
                    Button("Enviar lista", systemImage: "arrow.up", action: onSend)
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .frame(width: AppControlSize.composer, height: AppControlSize.composer)
                        .foregroundStyle(colors.brandOnPrimary)
                        .glassEffect(.regular.tint(colors.brandPrimary).interactive(), in: .circle)
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .tint(colors.brandOnPrimary)
                            }
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
        }
        .padding(AppSpacing.medium)
    }
}
