import SwiftUI

struct VoiceStatusLabel: View {
    let state: VoiceConversationState
    let feedback: String

    var body: some View {
        Label(feedback, systemImage: state.systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .contentTransition(.symbolEffect(.replace))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feedback)
    }
}
