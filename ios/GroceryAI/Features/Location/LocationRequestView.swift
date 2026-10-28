import SwiftUI

struct LocationRequestView: View {
    let onContinue: (String) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var locator = PostalCodeLocator()
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
                    .font(.system(size: 52))
                    .foregroundStyle(colors.brandPrimary)
                    .accessibilityHidden(true)

                Text("Indica un código postal para buscar tiendas cercanas.")
                    .font(.body)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        Button(locator.isLoading ? "Buscando…" : "Usar ubicación actual", systemImage: "location.fill") {
                            locator.request()
                            isPostalCodeFocused = false
                        }
                        .disabled(locator.isLoading)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                        if let message = locator.errorMessage {
                            Text(message).font(.footnote).foregroundStyle(colors.textSecondary)
                        }
                        HStack {
                            Divider()
                            Text("o escribe el código postal")
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

                Label("Solo se usa en esta comparación", systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
            }
            .padding(AppSpacing.extraLarge)
        }
        .background(colors.backgroundPrimary)
        .onChange(of: locator.postalCode) {
            if let code = locator.postalCode {
                postalCode = code
            }
        }
        .onDisappear { locator.cancel() }
        .navigationTitle("Ubicación")
        .toolbarTitleDisplayMode(.inlineLarge)
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
