import MapKit
import SwiftUI

struct PostalCodeStep: View {
    @Binding var postalCode: String
    let onContinue: (String) -> Void
    let onSkip: () -> Void
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var locator = PostalCodeLocator()
    @State private var showsManualField = false
    @FocusState private var isFieldFocused: Bool

    private let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.415, longitude: -99.165),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )

    private let storePins: [(String, CLLocationCoordinate2D)] = [
        ("RetailerWalmart", CLLocationCoordinate2D(latitude: 19.4195, longitude: -99.1710)),
        ("RetailerBodegaAurrera", CLLocationCoordinate2D(latitude: 19.4105, longitude: -99.1590)),
        ("RetailerChedraui", CLLocationCoordinate2D(latitude: 19.4090, longitude: -99.1740))
    ]

    private var hasCode: Bool {
        Self.isValid(postalCode)
    }

    /// Mexican postal codes run from 01000 to 99999.
    static func isValid(_ code: String) -> Bool {
        guard code.count == 5, code.allSatisfy(\.isASCII), let value = Int(code) else { return false }
        return value >= 1000
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: .postalCode,
            title: "¿Dónde haces el súper?",
            subtitle: "Buscamos precios en tiendas cerca de ti. Solo guardamos tu código postal",
            onBack: onBack,
            layout: .centered,
            footer: {
            VStack(spacing: AppSpacing.small) {
                if hasCode {
                    GlassProminentButton("Continuar") {
                        onContinue(postalCode)
                    }
                } else {
                    GlassProminentButton(
                        locator.isLoading ? "Buscando…" : "Usar mi ubicación",
                        systemImage: "location.fill"
                    ) {
                        locator.request()
                        isFieldFocused = false
                    }
                    .disabled(locator.isLoading)
                }

                if !hasCode && !showsManualField {
                    Button("Escribir código postal") {
                        showsManualField = true
                        isFieldFocused = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.brandPrimary)
                    .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget)
                    .contentShape(.rect)
                }

                if !hasCode {
                    Button("Ahora no", action: onSkip)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget)
                        .contentShape(.rect)
                }
            }
            },
            content: {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                mapHero(colors: colors)

                if hasCode && !showsManualField {
                    HStack(spacing: AppSpacing.medium) {
                        Label("CP \(postalCode)", systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(colors.statusSuccess)
                        Spacer(minLength: 0)
                        Button("Cambiar") {
                            showsManualField = true
                            isFieldFocused = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.brandPrimary)
                        .frame(minWidth: AppControlSize.minimumTapTarget, minHeight: AppControlSize.minimumTapTarget)
                        .contentShape(.rect)
                        .accessibilityLabel("Cambiar código postal")
                    }
                } else {
                    if let message = locator.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                    }
                    if postalCode.count == 5 && !hasCode {
                        Label("Ese código postal no existe. Revisa los 5 dígitos.", systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(colors.statusError)
                    }
                    if showsManualField {
                        TextField("Código postal", text: $postalCode)
                            .textContentType(.postalCode)
                            .keyboardType(.numberPad)
                            .focused($isFieldFocused)
                            .onChange(of: postalCode) {
                                postalCode = String(postalCode.filter(\.isNumber).prefix(5))
                            }
                            .padding(.horizontal, AppSpacing.large)
                            .padding(.vertical, AppSpacing.large)
                            .background(colors.cellBackground, in: .rect(cornerRadius: 22, style: .continuous))
                            .accessibilityHint("Ingresa los cinco dígitos")
                    }
                }
            }
            }
        )
        #if DEBUG
        .onAppear {
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-postalCode"),
               ProcessInfo.processInfo.arguments.indices.contains(i + 1) {
                postalCode = ProcessInfo.processInfo.arguments[i + 1]
            }
        }
        #endif
        .onChange(of: locator.postalCode) {
            if let code = locator.postalCode {
                postalCode = code
                showsManualField = false
            }
        }
        .onDisappear { locator.cancel() }
    }

    @ViewBuilder
    private func mapHero(colors: AppThemeColors) -> some View {
        Map(initialPosition: .region(region)) {
            ForEach(Array(storePins.enumerated()), id: \.offset) { _, pin in
                Annotation("", coordinate: pin.1) {
                    Image(pin.0)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 24)
                        .frame(width: 40, height: 30)
                        .background(.white, in: .rect(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .frame(height: 240)
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .center) {
            Circle()
                .fill(colors.brandPrimary)
                .frame(width: 16, height: 16)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                }
                .accessibilityHidden(true)
        }
        .mask(alignment: .bottom) {
            LinearGradient(
                colors: [.black, .black.opacity(0)],
                startPoint: .init(x: 0.5, y: 0.82),
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }
}
