import SwiftUI

struct AgentComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let onSend: () -> Void
    let onAddFrequent: () -> Void
    let onAddPreviousOrder: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(alignment: .bottom, spacing: AppSpacing.small) {
            Menu {
                Button("Productos frecuentes", systemImage: "repeat") { onAddFrequent() }
                Button("Compra anterior", systemImage: "clock.arrow.circlepath") { onAddPreviousOrder() }
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Agregar desde historial")

            TextField("Ejemplo: 2 litros de leche", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .focused(isFocused)
                .submitLabel(.send)
                .onSubmit(onSend)
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, 11)
                .background(colors.backgroundSecondary, in: .rect(cornerRadius: AppRadius.large))

            Button(action: onSend) {
                if isLoading {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .accessibilityLabel("Enviar lista")
        }
        .padding(AppSpacing.medium)
        .background(.bar)
    }
}
