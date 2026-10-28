import SwiftUI

struct VoiceComposerButton: View {
    let state: VoiceConversationState
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        Button(state.isActive ? "Terminar conversación" : state.statusText, systemImage: buttonImage, action: action)
            .labelStyle(.iconOnly)
            .font(.body.bold())
            .foregroundStyle(state.isActive ? colors.brandOnPrimary : colors.brandPrimary)
            .frame(width: 44, height: 44)
            .background(state.isActive ? colors.brandPrimary : .clear, in: .circle)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: animates)
            .accessibilityInputLabels(["Voz", "Micrófono", state.statusText])
    }

    private var buttonImage: String {
        state.isActive ? "stop.fill" : state.systemImage
    }

    private var animates: Bool {
        !reduceMotion && (state == .connecting || state == .listening || state == .thinking || state == .speaking)
    }
}
