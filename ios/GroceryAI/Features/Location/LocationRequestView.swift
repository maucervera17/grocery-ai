import SwiftUI

struct LocationRequestView: View {
    let onContinue: (String) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var locator = PostalCodeLocator()
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
                        Button(locator.isLoading ? "Buscando código postal…" : "Usar mi ubicación", systemImage: "location.fill") {
                            locator.request()
                            isPostalCodeFocused = false
                        }
                        .disabled(locator.isLoading)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                        if let detail = locator.locationDescription {
                            Text(detail).font(.footnote).foregroundStyle(colors.textSecondary)
                        }
                        if let message = locator.errorMessage {
                            Text(message).font(.footnote).foregroundStyle(colors.textSecondary)
                        }
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
                .disabled(!isValidPostalCode || locator.isLoading)

                Text("Puedes usar tu ubicación actual o una dirección de entrega distinta. Solo enviamos el CP al servidor; la ubicación exacta no se guarda.")
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.extraLarge)
        }
        .background(colors.backgroundPrimary)
        .onReceive(locator.$postalCode) { code in if let code { postalCode = code } }
        .onDisappear { locator.cancel() }
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
