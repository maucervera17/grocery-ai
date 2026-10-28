import SwiftUI

struct LocationRequestView: View {
    let onContinue: (String) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var postalCode: String
    @FocusState private var isPostalCodeFocused: Bool

    init(
        initialPostalCode: String = "",
        onContinue: @escaping (String) -> Void
    ) {
        _postalCode = State(initialValue: initialPostalCode)
        self.onContinue = onContinue
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        ScrollView {
            VStack(spacing: AppSpacing.extraLarge) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(colors.brandPrimary)
                    .accessibilityHidden(true)

                VStack(spacing: AppSpacing.small) {
                    Text("Busca precios cerca de ti")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text("Usaremos tu código postal para consultar tiendas cercanas. No guardaremos tu ubicación exacta.")
                        .font(.body)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        Button("Usar ubicación de demostración", systemImage: "location.fill") {
                            postalCode = "06700"
                            isPostalCodeFocused = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                        HStack {
                            Divider()
                            Text("o ingresa tu código postal")
                                .font(.caption)
                                .foregroundStyle(colors.textSecondary)
                                .fixedSize()
                            Divider()
                        }

                        TextField("Código postal", text: $postalCode)
                            .textContentType(.postalCode)
                            .keyboardType(.numberPad)
                            .focused($isPostalCodeFocused)
                            .onChange(of: postalCode) {
                                postalCode = String(postalCode.filter(\.isNumber).prefix(5))
                            }
                            .padding(AppSpacing.medium)
                            .background(colors.backgroundSecondary, in: .rect(cornerRadius: AppRadius.medium))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(colors.borderSubtle)
                            }
                            .accessibilityHint("Ingresa los cinco dígitos")
                    }
                }

                PrimaryButton("Continuar", systemImage: "arrow.right") {
                    onContinue(postalCode)
                }
                .disabled(!isValidPostalCode)

                Text("La ubicación solo se usa para esta comparación.")
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.extraLarge)
        }
        .background(colors.backgroundPrimary)
        .navigationTitle("Ubicación")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isValidPostalCode: Bool {
        postalCode.count == 5 && postalCode.allSatisfy(\.isNumber)
    }
}

#Preview {
    NavigationStack {
        LocationRequestView(onContinue: { _ in })
    }
}
