import SwiftUI

struct VoiceStatusLabel: View {
    let state: VoiceConversationState

    var body: some View {
        Label(state.statusText, systemImage: state.systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel(state.statusText)
    }
}
